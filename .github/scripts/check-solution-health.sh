#!/usr/bin/env bash
set -euo pipefail

# Runs the Power Platform Solution Checker against a packed solution and
# gates the build on the structured SARIF report it produces
# (https://learn.microsoft.com/power-platform/alm/checker-api/overview#report-format),
# instead of grepping the CLI's free-form text output. Text parsing was
# fragile: incidental words like "error" in unrelated output could fail a
# healthy solution, and a changed CLI message format could silently let
# real findings pass.
#
# Usage: check-solution-health.sh <solution-zip-path> <solution-name> [max-level]
#   max-level: SARIF "level" that fails the build if present: error|warning|note.
#              Defaults to "warning" (fails on both "error" and "warning"
#              findings, ignores "note"/informational).

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <solution-zip-path> <solution-name> [max-level]"
  exit 1
fi

SOLUTION_FILE="$1"
SOLUTION_NAME="$2"
MAX_LEVEL="${3:-warning}"

case "$MAX_LEVEL" in
  error|warning|note) ;;
  *)
    echo "ERROR: invalid max-level '$MAX_LEVEL' (expected: error, warning, or note)"
    exit 1
    ;;
esac

if [ ! -f "$SOLUTION_FILE" ]; then
  echo "ERROR: Solution file not found: $SOLUTION_FILE"
  exit 1
fi

PAC_CMD="${POWERPLATFORMTOOLS_PACPATH:-pac}"
if ! command -v "$PAC_CMD" >/dev/null 2>&1; then
  echo "ERROR: Power Platform CLI not found at '$PAC_CMD'"
  exit 1
fi

REPORT_DIR="out/${SOLUTION_NAME}_checker_results"
REPORT_ZIP="out/${SOLUTION_NAME}_checker_results.zip"
rm -rf "$REPORT_DIR"
mkdir -p "$REPORT_DIR"

echo "Running Solution Checker for '$SOLUTION_NAME' on '$SOLUTION_FILE'"
"$PAC_CMD" solution check --path "$SOLUTION_FILE" --outputDirectory "$REPORT_DIR"

if [ -z "$(ls -A "$REPORT_DIR" 2>/dev/null)" ]; then
  echo "ERROR: Solution Checker did not produce any report in $REPORT_DIR"
  exit 1
fi

# Keep a zip of the raw report alongside the unpacked directory so existing
# "upload solution checker report" steps in the calling workflows keep working.
(cd "$(dirname "$REPORT_DIR")" && zip -qr "$(basename "$REPORT_ZIP")" "$(basename "$REPORT_DIR")")

mapfile -t SARIF_FILES < <(find "$REPORT_DIR" -type f \( -name '*.sarif' -o -name '*.sarif.json' \))
if [ "${#SARIF_FILES[@]}" -eq 0 ]; then
  echo "ERROR: No SARIF report files found in $REPORT_DIR"
  exit 1
fi

# SARIF only defines four result levels: error, warning, note, none.
# Fail on any level at or above the requested threshold.
LEVELS_TO_FAIL=(error)
if [ "$MAX_LEVEL" = "warning" ] || [ "$MAX_LEVEL" = "note" ]; then
  LEVELS_TO_FAIL+=(warning)
fi
if [ "$MAX_LEVEL" = "note" ]; then
  LEVELS_TO_FAIL+=(note)
fi
LEVELS_JSON=$(printf '%s\n' "${LEVELS_TO_FAIL[@]}" | jq -R . | jq -s .)

TOTAL_FINDINGS=0
for SARIF_FILE in "${SARIF_FILES[@]}"; do
  COUNT=$(jq --argjson levels "$LEVELS_JSON" \
    '[.runs[]?.results[]? | select(.level as $l | $levels | index($l))] | length' \
    "$SARIF_FILE")

  if [ "$COUNT" -gt 0 ]; then
    echo "Findings in $(basename "$SARIF_FILE"):"
    jq --argjson levels "$LEVELS_JSON" \
      '.runs[]?.results[]? | select(.level as $l | $levels | index($l)) | {level, ruleId, message: .message.text}' \
      "$SARIF_FILE"
  fi

  TOTAL_FINDINGS=$((TOTAL_FINDINGS + COUNT))
done

if [ "$TOTAL_FINDINGS" -gt 0 ]; then
  echo "Solution health check failed for '$SOLUTION_NAME': $TOTAL_FINDINGS finding(s) at or above level '$MAX_LEVEL'."
  exit 1
fi

echo "Solution health check passed for '$SOLUTION_NAME': no findings at or above level '$MAX_LEVEL'."
exit 0

#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <solution-zip-path> <solution-name>"
  exit 1
fi

SOLUTION_FILE="$1"
SOLUTION_NAME="$2"

if [ ! -f "$SOLUTION_FILE" ]; then
  echo "ERROR: Solution file not found: $SOLUTION_FILE"
  exit 1
fi

PAC_CMD="${POWERPLATFORMTOOLS_PACPATH:-pac}"
if ! command -v "$PAC_CMD" >/dev/null 2>&1; then
  echo "ERROR: Power Platform CLI not found at '$PAC_CMD'"
  exit 1
fi

echo "Running Solution Checker for '$SOLUTION_NAME' on '$SOLUTION_FILE'"

auth_output="$($PAC_CMD auth list 2>&1 || true)"
echo "$auth_output"
echo ""

commands=(
  "solution check --path $SOLUTION_FILE"
  "solution check --solutionUrl $SOLUTION_FILE"
)

for syntax in "${commands[@]}"; do
  read -r -a args <<< "$syntax"
  echo "+ $PAC_CMD ${args[*]}"
  if output="$($PAC_CMD "${args[@]}" 2>&1)"; then
    echo "$output"

    # If the tool returned a Results URL, try to download the zip and inspect its contents.
    result_url=$(echo "$output" | grep -i 'Results' | sed -E 's/.*Results[^:]*: *//I' | tr -d '\r' | grep -oE 'https?://[^[:space:]]+' || true)
    if [ -n "$result_url" ]; then
      mkdir -p out
      report_zip="out/${SOLUTION_NAME}_checker_results.zip"
      echo "Downloading solution checker results to $report_zip"
      if curl -fsSL -o "$report_zip" "$result_url"; then
        echo "Downloaded checker results to $report_zip"
        report_dir="out/${SOLUTION_NAME}_checker_results"
        mkdir -p "$report_dir"
        if unzip -o "$report_zip" -d "$report_dir" >/dev/null 2>&1; then
          echo "Unzipped checker results to $report_dir"
        else
          echo "Warning: failed to unzip $report_zip — continuing with raw zip"
        fi
      else
        echo "Warning: failed to download checker results from $result_url"
      fi
    fi

    # If the tool explicitly reports no issues or zero findings, consider this a pass.
    if echo "$output" | grep -qiE 'no (issues|problems|findings)|0 (issues|problems|findings)|0 (critical|high|medium|low)'; then
      echo "Solution health check passed via: $PAC_CMD ${args[*]}"
      exit 0
    fi

    # Inspect the downloaded report files for severity counts (Critical/High/Medium/Low).
    if [ -d "out/${SOLUTION_NAME}_checker_results" ]; then
      # Look for a header line containing 'Critical' and read the next line as counts.
      header_file=$(grep -Rni --binary-files=without-match -m1 'Critical' "out/${SOLUTION_NAME}_checker_results" | cut -d: -f1 || true)
      if [ -n "$header_file" ]; then
        counts_line=$(awk 'tolower($0) ~ /critical/ {getline; print; exit}' "$header_file" 2>/dev/null || true)
        if [ -n "$counts_line" ]; then
          for n in $counts_line; do
            if printf '%s' "$n" | grep -qE '^[0-9]+$'; then
              if [ "$n" -gt 0 ]; then
                echo "Solution health check detected severity counts for '$SOLUTION_NAME': $counts_line"
                echo "$output"
                exit 1
              fi
            fi
          done
        fi
      fi

      # Search within report files for severity words followed by numbers (e.g., 'Medium: 4').
      if grep -RoiE '(critical|high|medium|low).{0,40}[0-9]+' "out/${SOLUTION_NAME}_checker_results" >/dev/null 2>&1; then
        echo "Findings detected in checker report files for '$SOLUTION_NAME':"
        grep -RniE '(critical|high|medium|low).{0,40}[0-9]+' "out/${SOLUTION_NAME}_checker_results" || true
        exit 1
      fi
    fi

    # Detect any reported findings such as "4 medium found" or "Found 4 issues" in CLI output.
    if echo "$output" | grep -qiE '[0-9]+\s+(critical|high|medium|low)\s+found|found\s+[0-9]+.*(issue|issues|problem|problems)|[0-9]+\s+(critical|high|medium|low)'; then
      echo "Solution health check detected findings for '$SOLUTION_NAME':"
      echo "$output"
      exit 1
    fi

    # If output contains obvious error/failure text, fail.
    if echo "$output" | grep -qiE 'error|failed|exception'; then
      echo "Solution health check failed for '$SOLUTION_NAME' with command: $PAC_CMD ${args[*]}"
      exit 1
    fi

    # No indicators of findings or errors detected; treat as pass.
    echo "Solution health check passed via: $PAC_CMD ${args[*]}"
    exit 0
  fi

  if echo "$output" | grep -qiE 'unknown command|unrecognized command|command not found|not a valid command|not recognized as an internal or external command|unknown argument|unrecognized argument|unknown option|unrecognized option'; then
    echo "Command syntax not supported, trying next: $PAC_CMD ${args[*]}"
    continue
  fi

  echo "$output"
  echo "Solution health check failed for '$SOLUTION_NAME' with command: $PAC_CMD ${args[*]}"
  exit 1
done

echo "ERROR: No supported Power Platform Solution Checker command syntax was found."
exit 1

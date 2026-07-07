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

commands=(
  "solution check --path $SOLUTION_FILE"
  "solution check --solutionUrl $SOLUTION_FILE"
)

for syntax in "${commands[@]}"; do
  read -r -a args <<< "$syntax"
  echo "+ $PAC_CMD ${args[*]}"

  if output="$($PAC_CMD "${args[@]}" 2>&1)"; then
    echo "$output"
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

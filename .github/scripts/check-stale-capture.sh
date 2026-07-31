#!/usr/bin/env bash
set -euo pipefail

# Blocks a stale capture: fails if `main` changed a solution's source path
# after the feature branch diverged from it, which would otherwise let a
# Power Apps export silently overwrite changes already merged to main.

if [ "$#" -lt 4 ]; then
  echo "Usage: $0 <branch-name> <dev-environment> <solution-name> <solution-path>"
  exit 1
fi

BRANCH_NAME="$1"
DEV_ENVIRONMENT="$2"
SOLUTION_NAME="$3"
SOLUTION_PATH="$4"

BASE_SHA=$(git merge-base HEAD origin/main)

if [ -z "$BASE_SHA" ]; then
  echo "::error::Unable to determine merge-base between '$BRANCH_NAME' and origin/main."
  exit 1
fi

if git diff --quiet "$BASE_SHA" origin/main -- "$SOLUTION_PATH"; then
  echo "No newer main changes detected for $SOLUTION_PATH since $BASE_SHA"
  exit 0
fi

echo "::error::Capture blocked for '$SOLUTION_NAME': main changed after branch '$BRANCH_NAME' diverged. Refresh the dev environment from the latest branch baseline before exporting."
{
  echo "## ❌ Capture blocked"
  echo ""
  echo "Solution **$SOLUTION_NAME** changed on **main** after branch **$BRANCH_NAME** diverged from commit **$BASE_SHA**."
  echo "Exporting from this environment could overwrite changes already merged to main."
  echo ""
  echo "Required action:"
  echo "1. If the environment contains maker work that is not captured elsewhere, run **backup-dev-changes** first for **$DEV_ENVIRONMENT** and **$SOLUTION_NAME**."
  echo "2. Rebase or merge the branch with the latest **main** locally."
  echo "3. Run **prepare-dev-environment** again for **$DEV_ENVIRONMENT**."
  echo "4. Re-apply or re-validate maker changes in the refreshed environment."
  echo "5. Run **capture-dev-changes** again."
} >> "$GITHUB_STEP_SUMMARY"
exit 1

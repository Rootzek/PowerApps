#!/usr/bin/env bash
set -euo pipefail

# Checks out an existing remote branch, or creates a new local branch from
# the current HEAD, resetting the working tree first for a clean start.
#
# If require-existing is "true" and the branch does not exist remotely, the
# script fails with a ::error:: annotation and a $GITHUB_STEP_SUMMARY block
# instead of silently creating it.

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <branch-name> <require-existing: true|false>"
  exit 1
fi

BRANCH_NAME="$1"
REQUIRE_EXISTING="$2"

git config user.name "github-actions"
git config user.email "github-actions@github.com"

# Clean any uncommitted changes to ensure clean working directory.
git reset --hard HEAD
git clean -fd

git fetch --prune origin

if git ls-remote --heads origin "$BRANCH_NAME" | grep -q .; then
  echo "Branch '$BRANCH_NAME' already exists. Checking out and updating."
  git checkout -B "$BRANCH_NAME" "origin/$BRANCH_NAME"
elif [ "$REQUIRE_EXISTING" = "true" ]; then
  echo "::error::Branch '$BRANCH_NAME' does not exist. Prepare the environment from main before capturing changes."
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      echo "## ❌ Capture blocked"
      echo ""
      echo "Branch **$BRANCH_NAME** does not exist yet."
      echo "Run **prepare-dev-environment** first so the environment and branch share the same Git baseline before any maker changes are captured."
    } >> "$GITHUB_STEP_SUMMARY"
  fi
  exit 1
else
  echo "Creating new branch '$BRANCH_NAME'."
  git checkout -B "$BRANCH_NAME"
fi

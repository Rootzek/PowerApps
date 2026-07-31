#!/usr/bin/env bash
set -euo pipefail

# Rebases the current branch onto origin/main. On conflict, aborts the
# rebase and fails with a $GITHUB_STEP_SUMMARY block explaining how to
# resolve it manually, instead of leaving the working tree mid-rebase.
#
# The working tree is expected to already be clean (reset --hard + clean -fd
# earlier in the job), so the rebase can proceed without the "you have
# uncommitted changes" error.

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <branch-name>"
  exit 1
fi

BRANCH_NAME="$1"

if git ls-remote --heads origin main | grep -q .; then
  if ! git rebase origin/main; then
    git rebase --abort

    echo "::error::Rebase of '$BRANCH_NAME' onto origin/main hit conflicts and was aborted. Resolve locally and push manually."
    {
      echo "## ❌ Rebase conflict"
      echo ""
      echo "Branch **$BRANCH_NAME** could not be automatically rebased onto **main**."
      echo "Resolve it locally, then push the result so this workflow can pick it up on the next run:"
      echo ""
      echo '```bash'
      echo "git fetch origin"
      echo "git checkout $BRANCH_NAME"
      echo "git rebase origin/main"
      echo "# fix conflicts in the affected files, then:"
      echo "git add ."
      echo "git rebase --continue"
      echo "git push --force-with-lease origin $BRANCH_NAME"
      echo '```'
    } >> "$GITHUB_STEP_SUMMARY"

    exit 1
  fi
fi

echo "✅ Rebase successful"

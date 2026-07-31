#!/usr/bin/env bash
set -euo pipefail

# Creates and pushes an annotated Git tag for a release version if it does
# not already exist locally or on origin. Writes tag_name=<tag> to
# $GITHUB_OUTPUT.

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

TAG="$1"

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists locally."
else
  git config user.name "github-actions"
  git config user.email "actions@github.com"
  git tag -a "$TAG" -m "Release $TAG"
fi

if git ls-remote --tags origin "refs/tags/$TAG" | grep "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists on origin."
else
  git push origin "$TAG"
fi

echo "tag_name=$TAG" >> "$GITHUB_OUTPUT"

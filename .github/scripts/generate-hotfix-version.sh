#!/usr/bin/env bash
set -euo pipefail

# Computes the next hotfix version for a given base production release.
# Base release format: YEAR.DAYOFYEAR.RELEASE.HOTFIX (e.g. 2026.211.1.0),
# matching the tag names actually created by create-release-tag.sh (no "v"
# prefix - see that script; the "v" prefix only appears on the GitHub
# Release name, not on the underlying git tag).
#
# Keeps YEAR.DAYOFYEAR.RELEASE from the release being patched (not today's
# date) and increments only the HOTFIX segment, so the version stays
# clearly scoped to the release it fixes. If several hotfixes are made
# against the same release, each one bumps HOTFIX by 1 more.
#
# Writes version=<version> to $GITHUB_OUTPUT.

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <base-release-version>"
  exit 1
fi

BASE="$1"
BASE="${BASE#v}"

if ! [[ "$BASE" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "::error::Base release '$1' does not match expected format YEAR.DAYOFYEAR.RELEASE.HOTFIX (e.g. 2026.211.1.0)"
  exit 1
fi

YEAR="${BASH_REMATCH[1]}"
DAY="${BASH_REMATCH[2]}"
RELEASE="${BASH_REMATCH[3]}"

TAGS=$(git tag | grep -E "^${YEAR}\.${DAY}\.${RELEASE}\.[0-9]+$" || true)

if [ -z "$TAGS" ]; then
  MAX_HOTFIX=0
else
  MAX_HOTFIX=$(echo "$TAGS" | sed -E "s/^${YEAR}\.${DAY}\.${RELEASE}\.([0-9]+)$/\1/" | sort -n | tail -n 1)
fi

NEXT_HOTFIX=$((MAX_HOTFIX + 1))
VERSION="$YEAR.$DAY.$RELEASE.$NEXT_HOTFIX"

echo "Patching release $YEAR.$DAY.$RELEASE - next hotfix segment: $NEXT_HOTFIX"
echo "Generated hotfix version: $VERSION"
echo "version=$VERSION" >> "$GITHUB_OUTPUT"

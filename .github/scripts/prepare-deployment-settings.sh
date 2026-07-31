#!/usr/bin/env bash
set -euo pipefail

# Injects GitHub secrets/variables into a Power Platform deployment settings
# file via envsubst, in place. Add one `export PLACEHOLDER="..."` line in the
# calling workflow step per ${PLACEHOLDER} used in the file, e.g.:
#   export MY_API_KEY="${{ secrets.MY_API_KEY }}"
#   export MY_SERVICE_URL="${{ vars.MY_SERVICE_URL }}"
#
# Writes has_settings=true|false and settings_file=<path> to $GITHUB_OUTPUT.

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <deployment-settings-file>"
  exit 1
fi

FILE="$1"

if [ -f "$FILE" ]; then
  envsubst < "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
  echo "has_settings=true" >> "$GITHUB_OUTPUT"
  echo "settings_file=$FILE" >> "$GITHUB_OUTPUT"
else
  echo "has_settings=false" >> "$GITHUB_OUTPUT"
fi

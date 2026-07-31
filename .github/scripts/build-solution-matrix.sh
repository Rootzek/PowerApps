#!/usr/bin/env bash
set -euo pipefail

# Builds a GitHub Actions matrix JSON ({"include": [{"name": "..."}, ...]})
# from a comma-separated list of solution names. Trims whitespace around
# each name and drops empty entries (e.g. from trailing commas).

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <comma-separated-solution-names>"
  exit 1
fi

SOLUTIONS_CSV="$1"

jq -n --arg solutions "$SOLUTIONS_CSV" -c \
  '{include: ($solutions | split(",") | map(gsub("^\\s+|\\s+$";"") | select(length > 0) | {name: .}))}'

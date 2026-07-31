#!/usr/bin/env bash
set -euo pipefail

# Stamps a prepared dev environment with Dataverse environment variables
# recording the Git branch and source commit it was seeded from.
#
# Required environment variables:
#   ENV_URL      - Dataverse environment URL
#   BRANCH_NAME  - Branch used to seed the environment
#   SOURCE_SHA   - Git commit SHA used to seed the environment
#   TENANT_ID    - Azure AD tenant id
#   CLIENT_ID    - Azure AD app registration client id
#
# Also relies on ACTIONS_ID_TOKEN_REQUEST_TOKEN / ACTIONS_ID_TOKEN_REQUEST_URL,
# which GitHub Actions injects automatically for jobs granted `id-token: write`.

: "${ENV_URL:?ENV_URL is required}"
: "${BRANCH_NAME:?BRANCH_NAME is required}"
: "${SOURCE_SHA:?SOURCE_SHA is required}"
: "${TENANT_ID:?TENANT_ID is required}"
: "${CLIENT_ID:?CLIENT_ID is required}"
: "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:?ACTIONS_ID_TOKEN_REQUEST_TOKEN is required (grant id-token: write to this job)}"
: "${ACTIONS_ID_TOKEN_REQUEST_URL:?ACTIONS_ID_TOKEN_REQUEST_URL is required (grant id-token: write to this job)}"

get_json_value() {
  local key="$1"
  local payload="$2"
  python3 -c "import json, sys; data = json.loads(sys.argv[2]); value = data.get(sys.argv[1], ''); print('' if value is None else value)" "$key" "$payload"
}

url_encode() {
  python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

first_value_field() {
  local payload="$1"
  local field_name="$2"
  python3 -c "import json, sys; data = json.loads(sys.argv[1]); rows = data.get('value', []); print(rows[0].get(sys.argv[2], '') if rows else '')" "$payload" "$field_name"
}

build_definition_payload() {
  local schema_name="$1"
  local display_name="$2"
  local description="$3"
  python3 -c "import json, sys; print(json.dumps({'schemaname': sys.argv[1], 'displayname': sys.argv[2], 'description': sys.argv[3], 'type': 100000000, 'defaultvalue': ''}))" "$schema_name" "$display_name" "$description"
}

build_value_create_payload() {
  local schema_name="$1"
  local current_value="$2"
  local definition_id="$3"
  python3 -c "import json, sys; print(json.dumps({'schemaname': sys.argv[1], 'value': sys.argv[2], 'EnvironmentVariableDefinitionId@odata.bind': '/environmentvariabledefinitions(' + sys.argv[3] + ')'}))" "$schema_name" "$current_value" "$definition_id"
}

build_value_update_payload() {
  local current_value="$1"
  python3 -c "import json, sys; print(json.dumps({'value': sys.argv[1]}))" "$current_value"
}

request_oidc_token() {
  local response
  response=$(curl -fsSL \
    -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
    "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange")
  get_json_value value "$response"
}

request_dataverse_token() {
  local oidc_token="$1"
  local response
  response=$(curl -fsSL -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "client_id=$CLIENT_ID" \
    --data-urlencode "scope=${ENV_URL%/}/.default" \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
    --data-urlencode "client_assertion=$oidc_token")
  get_json_value access_token "$response"
}

upsert_environment_variable() {
  local schema_name="$1"
  local display_name="$2"
  local description="$3"
  local current_value="$4"
  local definition_filter
  local definition_response
  local definition_id
  local value_filter
  local value_response
  local value_id
  local payload

  definition_filter=$(url_encode "schemaname eq '$schema_name'")
  definition_response=$(curl -fsSL \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Accept: application/json" \
    "$API_URL/environmentvariabledefinitions?\$select=environmentvariabledefinitionid&\$filter=$definition_filter")

  definition_id=$(first_value_field "$definition_response" "environmentvariabledefinitionid")

  if [ -z "$definition_id" ]; then
    payload=$(build_definition_payload "$schema_name" "$display_name" "$description")

    definition_response=$(curl -fsSL -X POST \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d "$payload" \
      "$API_URL/environmentvariabledefinitions")

    definition_id=$(get_json_value environmentvariabledefinitionid "$definition_response")
  fi

  value_filter=$(url_encode "schemaname eq '$schema_name'")
  value_response=$(curl -fsSL \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Accept: application/json" \
    "$API_URL/environmentvariablevalues?\$select=environmentvariablevalueid&\$filter=$value_filter")

  value_id=$(first_value_field "$value_response" "environmentvariablevalueid")

  if [ -z "$value_id" ]; then
    payload=$(build_value_create_payload "$schema_name" "$current_value" "$definition_id")
    curl -fsSL -X POST \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "$API_URL/environmentvariablevalues" >/dev/null
  else
    payload=$(build_value_update_payload "$current_value")
    curl -fsSL -X PATCH \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "$API_URL/environmentvariablevalues($value_id)" >/dev/null
  fi

  echo "Stamped $schema_name"
}

OIDC_TOKEN=$(request_oidc_token)
ACCESS_TOKEN=$(request_dataverse_token "$OIDC_TOKEN")

if [ -z "$ACCESS_TOKEN" ]; then
  echo "Failed to obtain Dataverse access token"
  exit 1
fi

API_URL="${ENV_URL%/}/api/data/v9.2"

upsert_environment_variable \
  "mp_PreparedBranch" \
  "Prepared Branch" \
  "Operational marker storing the branch used to seed this dev environment." \
  "$BRANCH_NAME"

upsert_environment_variable \
  "mp_PreparedSourceSha" \
  "Prepared Source SHA" \
  "Operational marker storing the Git commit used to seed this dev environment." \
  "$SOURCE_SHA"

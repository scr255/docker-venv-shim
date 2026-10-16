#!/bin/bash
set -euo pipefail

error() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() { grep '^# Usage' "$0" | sed 's/^# //'; }
[ "$#" -ge 1 ] || error "Usage: $0 <env-folder> [--version N] [--show]"
case "$1" in -h|--help) usage; exit 0 ;; esac
ENV_NAME="$1"
[[ "$ENV_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || error "Environment must be a single folder name (letters, digits, underscores, hyphens)."
shift
ENV_VERSION=1
SHOW_ONLY=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --show|--dry-run) SHOW_ONLY=true; shift ;;
    --version)
      [ "$#" -ge 2 ] || error "--version requires a positive integer."
      ENV_VERSION="$2"
      shift 2 ;;
    --version=*) ENV_VERSION="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) error "Unknown option: $1" ;;
  esac
done
[[ "$ENV_VERSION" =~ ^[1-9][0-9]*$ ]] || error "Version must be a positive integer."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$SCRIPT_DIR/$ENV_NAME"
CONFIG_JSON="$PROJECT_ROOT/config.json"
[ -d "$ENV_DIR" ] || error "Environment folder not found: $ENV_DIR"
[ -f "$ENV_DIR/Dockerfile" ] || error "Environment needs a Dockerfile: $ENV_DIR"
[ -f "$ENV_DIR/requirements.txt" ] || error "Environment needs requirements.txt: $ENV_DIR"
[ -f "$CONFIG_JSON" ] || error "No config.json at project root. Copy $SCRIPT_DIR/config_azure_example.json to $CONFIG_JSON and fill in its values."
command -v az >/dev/null 2>&1 || error "Azure CLI not found. Activate the local Azure environment (source .venv/bin/activate) or install the Azure CLI."
command -v python3 >/dev/null 2>&1 || error "python3 not found. Activate the local Azure environment (source .venv/bin/activate) or install python3."

read_cfg() {
  local value
  value="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2]) or "")' "$CONFIG_JSON" "$1" 2>/dev/null)" || error "Could not read '$1' from $CONFIG_JSON."
  printf '%s' "$value"
}
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-$(read_cfg subscription_id)}"
RESOURCE_GROUP="${RESOURCE_GROUP:-$(read_cfg resource_group)}"
WORKSPACE_NAME="${WORKSPACE_NAME:-$(read_cfg workspace_name)}"
[ -n "$SUBSCRIPTION_ID" ] || error "config.json is missing 'subscription_id'."
[ -n "$RESOURCE_GROUP" ] || error "config.json is missing 'resource_group'."
[ -n "$WORKSPACE_NAME" ] || error "config.json is missing 'workspace_name'."

TEMP_ENV_YML="$(mktemp "$ENV_DIR/.azure-environment.XXXXXX")"
ENV_YML="${TEMP_ENV_YML}.yml"
mv -- "$TEMP_ENV_YML" "$ENV_YML"
trap 'rm -f -- "$ENV_YML"' EXIT
{
  printf '%s\n' '$schema: https://azuremlschemas.azureedge.net/latest/environment.schema.json'
  printf 'name: %s\nversion: %s\nbuild:\n  path: .\n  dockerfile_path: Dockerfile\n' "$ENV_NAME" "$ENV_VERSION"
} > "$ENV_YML"

AZ_ARGS=(ml environment create
  --subscription "$SUBSCRIPTION_ID"
  --resource-group "$RESOURCE_GROUP"
  --workspace-name "$WORKSPACE_NAME"
  --file "$ENV_YML")
if $SHOW_ONLY; then
  printf 'Would publish %s version %s from %s/Dockerfile to workspace %s.\n' "$ENV_NAME" "$ENV_VERSION" "$ENV_DIR" "$WORKSPACE_NAME"
  printf 'The Azure ML environment YAML is generated temporarily when publishing.\n'
  exit 0
fi

if ! az extension list --query "[?name=='ml'].name" -o tsv 2>/dev/null | tr -d '\r' | grep -qx 'ml'; then
  printf 'Installing Azure ML CLI extension...\n'
  az extension add --name ml --yes
fi
az account show >/dev/null 2>&1 || error "Not logged in to Azure CLI. Run 'az login' first."
az ml workspace show --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WORKSPACE_NAME" -o tsv --query name >/dev/null 2>&1 || error "Azure ML workspace is not reachable. Check config.json, 'az login', and your access."
printf 'Publishing %s version %s to Azure ML workspace %s...\n' "$ENV_NAME" "$ENV_VERSION" "$WORKSPACE_NAME"
(cd "$ENV_DIR" && az "${AZ_ARGS[@]}")
printf 'Ready: %s version %s is available in workspace %s for compute clusters.\n' "$ENV_NAME" "$ENV_VERSION" "$WORKSPACE_NAME"

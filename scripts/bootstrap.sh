#!/bin/bash
set -e

ENV="${1:?Usage: $0 <staging|prod>}"
ENV_FILE="$(dirname "$0")/env/${ENV}.env"
GRP_NAME="storage-blob-contributors-group"

if [ ! -f "$ENV_FILE" ]; then
    echo "env file not found" >&2; exit 1
fi

source "$ENV_FILE"
source "$(dirname "$0")/lib/azure.sh"

SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

create_resource_group "$TF_RG_NAME" "$LOCATION"
create_storage_account "$STRG_ACCT_NAME" "$TF_RG_NAME"
create_container "$CONTAINER_NAME" "$STRG_ACCT_NAME"

APP_ID=$(create_app_with_federated_creds \
    "$APP_DISPLAY_NAME" "$GITHUB_REPO" "$GITHUB_ENV_NAME" \
    "$SUB_ID" "$TF_RG_NAME" "$STRG_ACCT_NAME")

SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv | tr -d '[:space:]')

STORAGE_GROUP_ID=$(create_storage_group_with_role "$GRP_NAME" "$SUB_ID" "$SP_OBJECT_ID")

echo "AZURE_TENANT_ID       = $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID = $SUB_ID"
echo "AZURE_CLIENT_ID       = $APP_ID"
echo "ENVIRONMENT           = $ENV_NAME"
echo "AD GROUP ID           = $STORAGE_GROUP_ID"
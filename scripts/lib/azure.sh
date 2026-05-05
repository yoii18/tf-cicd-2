#!/bin/bash

create_resource_group() {
    local rg_group="$1" location="$2"
    if [ "$(az group exists --name "$rg_group")" = "false" ]; then 
        az group create --name "$rg_group" --location "$location"
    fi
}

create_storage_account() {
    local acct="$1" rg_group="$2"
    if ! az storage account show --name "$acct" --resource-group "$rg_group" &>/dev/null; then 
        az storage account create \
            --name "$acct" \
            --resource-group "$rg_group" \
            --sku "Standard_LRS" \
            --min-tls-version "TLS1_2" \
            --hns true
    fi
}

create_container() {
    local cont_name="$1" strg_acct_name="$2"
    if [ "$(az storage container exists --name "$cont_name" --account-name "$strg_acct_name" --auth-mode login --query exists -o tsv)" = "false" ]; then
        az storage container create \
            --name "$cont_name" \
            --account-name "$strg_acct_name" \
            --auth-mode login
    fi
}

create_app_with_federated_creds() {
    local display_name="$1" repo="$2" env_name="$3" sub_id="$4" rg="$5" acct="$6"
    local app_id sp_obj_id

    app_id=$(az ad app create --display-name "$display_name" --query appId -o tsv)
    az ad sp create --id "$app_id" >/dev/null

    sp_obj_id=$(az ad sp show --id "$app_id" --query id -o tsv | tr -d '[:space:]')

    az role assignment create \
        --assignee "$sp_obj_id" \
        --role "Contributor" \
        --scope "/subscriptions/$sub_id"

    az role assignment create \
        --assignee "$sp_obj_id" \
        --role "Storage Blob Data Contributor" \
        --scope "/subscriptions/$sub_id/resourceGroups/$rg/providers/Microsoft.Storage/storageAccounts/$acct" >/dev/null

    az ad app federated-credential create --id "$app_id" --parameters "{
        \"name\": \"github-${env_name}-env\",
        \"issuer\": \"https://token.actions.githubusercontent.com\",
        \"subject\": \"repo:${repo}:environment:${env_name}\",
        \"audiences\": [\"api://AzureADTokenExchange\"]
    }" >/dev/null

    echo "$app_id"
}

create_storage_group_with_role() {
    local grp_name="$1" sub_id="$2"
    local group_id

    group_id=$(az ad group show --group "$grp_name" --query id -o tsv 2>/dev/null) || true

    if [ -z "$group_id" ]; then
        group_id=$(az ad group create \
            --display-name "$grp_name" \
            --mail-nickname "$grp_name" \
            --query id -o tsv)
    fi

    az role assignment create \
        --assignee "$group_id" \
        --role "Storage Blob Data Contributor" \
        --scope "/subscriptions/$sub_id"

    echo "$group_id"
}

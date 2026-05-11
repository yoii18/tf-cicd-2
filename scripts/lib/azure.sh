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
        --assignee-object-id "$sp_obj_id" \
        --assignee-principal-type "ServicePrincipal" \
        --role "Contributor" \
        --scope "/subscriptions/$sub_id" >/dev/null

    az role assignment create \
        --assignee-object-id "$sp_obj_id" \
        --assignee-principal-type "ServicePrincipal" \
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
    local grp_name="$1" sub_id="$2" sp_obj_id="$3"
    local group_id

    group_id=$(az ad group show --group "$grp_name" --query id -o tsv 2>/dev/null) || true

    if [ -z "$group_id" ]; then
        group_id=$(az ad group create \
            --display-name "$grp_name" \
            --mail-nickname "$grp_name" \
            --query id -o tsv)
    fi

    az role assignment create \
        --assignee-object-id "$group_id" \
        --assignee-principal-type "Group" \
        --role "Storage Blob Data Contributor" \
        --scope "/subscriptions/$sub_id" >/dev/null

    # Assign Groups Administrator Entra ID role to the SP
    # fdd7a751-b60b-444a-984c-02652fe8fa1c is the well-known Microsoft constant for Groups Administrator
    az rest \
        --method POST \
        --uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" \
        --headers "Content-Type=application/json" \
        --body "{
            \"@odata.type\": \"#microsoft.graph.unifiedRoleAssignment\",
            \"principalId\": \"${sp_obj_id}\",
            \"roleDefinitionId\": \"fdd7a751-b60b-444a-984c-02652fe8fa1c\",
            \"directoryScopeId\": \"/\"
        }" >/dev/null

    echo "$group_id"
}
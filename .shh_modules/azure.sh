#!/bin/bash
# --- AZURE MODULE ---
# Usage: load_secret_azure <vault_name> <secret_name>
load_secret_azure() {
    local vault_name="$1"
    local secret_name="$2"
    
    # Check if az CLI is available
    if ! command -v az &> /dev/null; then
        echo "Error: Azure CLI not installed" >&2
        return 1
    fi
    
    # Get secret
    local secret_json
    secret_json=$(az keyvault secret show --vault-name "$vault_name" --name "$secret_name" --query 'value' --output tsv 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "Error: Failed to get secret '$secret_name' in vault '$vault_name': $secret_json" >&2
        return 1
    fi
    
    echo "${secret_name}=$secret_json"
}

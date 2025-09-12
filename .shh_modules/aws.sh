#!/bin/bash
# --- AWS MODULE ---
# Usage: load_secret_aws <profile> <secret_name>
load_secret_aws() {
    local profile="$1"
    local secret_name="$2"
    
    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        echo "Error: AWS CLI not installed" >&2
        return 1
    fi
    
    # Get secret
    local secret_json
    secret_json=$(aws --profile "$profile" secretsmanager get-secret-value --secret-id "$secret_name" --query 'SecretString' --output text 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "Error: Failed to get secret '$secret_name' in profile '$profile': $secret_json" >&2
        return 1
    fi
    
    # AWS secrets can be JSON, so we'll extract the whole thing
    # Use the secret name as the key
    echo "${secret_name}=$secret_json"
}

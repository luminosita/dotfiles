#!/bin/bash
# --- GCP MODULE ---
# Usage: load_secret_gcp <project_id> <secret_name>
load_secret_gcp() {
    local project="$1"
    local secret_name="$2"
    
    # Check if gcloud is available
    if ! command -v gcloud &> /dev/null; then
        echo "Error: gcloud CLI not installed" >&2
        return 1
    fi
    
    # Get secret version (latest)
    local secret_value
    secret_value=$(gcloud secrets versions access latest --secret="$secret_name" --project="$project" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "Error: Failed to get secret '$secret_name' in project '$project': $secret_value" >&2
        return 1
    fi
    
    # Clean up any trailing newlines
    secret_value=$(echo "$secret_value" | tr -d '\r\n')
    
    echo "${secret_name}=$secret_value"
}

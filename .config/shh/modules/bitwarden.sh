#!/bin/bash
# --- BITWARDEN MODULE ---
# Usage: load_secret_bitwarden <item_name> [field]
load_secret_bitwarden() {
    local item_name="$1"
    local field="${2:-password}"
    
    # Check if bw CLI is available
    if ! command -v bw &> /dev/null; then
        echo "Error: Bitwarden CLI (bw) not installed" >&2
        return 1
    fi
    
    # Check if logged in
    if ! bw status &> /dev/null; then
        echo "Error: Not logged into Bitwarden. Run 'bw login' first." >&2
        return 1
    fi
    
    # Get item
    local item_json
    item_json=$(bw get item "$item_name" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "Error: Failed to get item '$item_name': $item_json" >&2
        return 1
    fi
    
    # Extract field value using jq
    local value
    value=$(echo "$item_json" | jq -r ".fields[] | select(.name==\"$field\") | .value" 2>/dev/null)
    
    # If not found in fields, try notes or password
    if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
        if [[ "$field" == "password" ]]; then
            value=$(echo "$item_json" | jq -r ".password" 2>/dev/null)
        elif [[ "$field" == "notes" ]]; then
            value=$(echo "$item_json" | jq -r ".notes" 2>/dev/null)
        else
            # Look for custom field
            value=$(echo "$item_json" | jq -r ".fields[] | select(.name==\"$field\") | .value" 2>/dev/null)
        fi
    fi
    
    if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
        echo "Error: Field '$field' not found in item '$item_name'" >&2
        return 1
    fi
    
    # Return as KEY=VALUE where KEY is item_name.field
    echo "${item_name}_${field}=$value"
}


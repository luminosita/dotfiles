#!/bin/bash

# load_secret_bitwarden() - Fetch secret from Bitwarden using pre-authenticated session token
# Usage: load_secret_bitwarden <item_name> [field] [target_env_var]
# Example: load_secret_bitwarden "MyApp" "API_Key" "MY_APP_API_KEY"
#
# Requires: BW_TOKEN environment variable set to a valid Bitwarden session token
# Get token via: bw unlock --raw   (run this manually or via secure secret store)

load_secret_bitwarden() {
    local item_name="$1"
    local field="${2:-password}"
    local target_env="${3:-}"  # Optional: final env var name (used by shh.sh)

    # Required: Bitwarden session token (obtained via 'bw unlock --raw')
    local BW_TOKEN="${BW_TOKEN:-}"

    if [[ -z "$BW_TOKEN" ]]; then
        echo "Error: BW_TOKEN environment variable not set" >&2
        echo "Get a session token by running:" >&2
        echo "  bw unlock --raw" >&2
        echo "Then export it: export BW_TOKEN='your-session-token-here'" >&2
        return 1
    fi

    # Bitwarden API endpoints
    local BASE_URL="https://api.bitwarden.com"
    local ITEMS_URL="${BASE_URL}/vault/items"

    # --- STEP 1: Fetch user's items using session token ---
    info "Fetching items from Bitwarden vault using session token..." >&2

    local items_response
    items_response=$(curl -s -X GET "$ITEMS_URL" \
        -H "Authorization: Bearer $BW_TOKEN" \
        -H "Accept: application/json")

    local status=$?
    if [[ $status -ne 0 ]]; then
        echo "Error: Network failure while contacting Bitwarden API" >&2
        return 1
    fi

    # Check for API error response
    if echo "$items_response" | jq -e '.errorCode' >/dev/null 2>&1; then
        local error_msg
        error_msg=$(echo "$items_response" | jq -r '.message // "Unknown error"')
        echo "Error: Bitwarden API returned error: $error_msg" >&2
        return 1
    fi

    # --- STEP 2: Find item by name ---
    local full_item
    full_item=$(echo "$items_response" | jq --arg name "$item_name" '.data[] | select(.name == $name)')

    if [[ "$(echo "$full_item" | jq -r '.')" == "null" ]]; then
        echo "Error: Item '$item_name' not found in vault" >&2
        return 1
    fi

    # --- STEP 3: Extract field value ---
    local value

    # Priority 1: Custom fields
    value=$(echo "$full_item" | jq -r --arg f "$field" '.fields[] | select(.name == $f) | .value')

    # Priority 2: Built-in password
    if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
        if [[ "$field" == "password" ]]; then
            value=$(echo "$full_item" | jq -r '.password // empty')
        elif [[ "$field" == "notes" ]]; then
            value=$(echo "$full_item" | jq -r '.notes // empty')
        fi
    fi

    # Priority 3: URI (if field is "uri")
    if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
        if [[ "$field" == "uri" ]]; then
            value=$(echo "$full_item" | jq -r '.uris[0].uri // empty')
        fi
    fi

    # Final validation
    if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
        echo "Error: Field '$field' not found in item '$item_name'" >&2
        return 1
    fi

    # --- STEP 4: Output as dummy_key=value (shh.sh will map to target_env) ---
    echo "dummy_key=$value"
}
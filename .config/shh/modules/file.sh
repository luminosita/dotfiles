#!/bin/bash
# --- FILE MODULE ---
# Usage: load_secret_file <file_path>
load_secret_file() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        echo "Error: File '$file_path' does not exist" >&2
        return 1
    fi
    
    # Read entire file content
    local content
    content=$(cat "$file_path" | tr -d '\r\n')  # Remove newlines
    
    # Use filename without extension as key
    local key
    key=$(basename "$file_path" | sed 's/\.[^.]*$//')
    
    echo "$key=$content"
}

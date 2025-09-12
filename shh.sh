#!/opt/homebrew/bin/bash

# shh.sh - Modular secret retrieval environment loader
# Supports: .env files, Bitwarden, AWS, GCP, HashiCorp Vault, Azure Key Vault, and more

# Check for Bash 4.0+ (required for associative arrays)
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
  echo -e "${RED}ERROR:${NC} This script requires Bash 4.0+"
  echo "Your current Bash version: ${BASH_VERSION}"
  echo "On macOS, install newer Bash with:"
  echo "  brew install bash"
  echo "Then run with: /usr/local/bin/bash $0 $@"
  exit 1
fi

# Configuration
DEFAULT_ENV_FILE=".env"
MODULES_DIR="${HOME}/.shh_modules"  # Directory for external modules
LOG_FILE="/tmp/shh.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

info() {
    echo -e "${BLUE}INFO:${NC} $1"
    log "INFO: $1"
}

warn() {
    echo -e "${YELLOW}WARN:${NC} $1"
    log "WARN: $1"
}

error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
    log "ERROR: $1"
}

success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
    log "SUCCESS: $1"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] -- COMMAND [ARGS...]

Load environment variables from multiple sources and execute a command.

Options:
  -f FILE          Load environment variables from FILE (default: .env)
  -e KEY=VALUE     Set environment variable (can be used multiple times)
  -s SOURCE[:KEY]  Secret source (see below for supported sources)
  -l               List available secret sources
  -v               Verbose mode
  -h               Show this help message

Supported Secret Sources:
  bitwarden:<item_name>[:field]      - Bitwarden CLI item field
  aws:<profile>:<secret_name>        - AWS Secrets Manager (uses AWS CLI)
  gcp:<project>:<secret_name>        - Google Cloud Secret Manager
  vault:<path>:<key>                 - HashiCorp Vault (KV v2)
  azure:<vault_name>:<secret_name>   - Azure Key Vault
  file:<path>                        - Read entire file as value
  env:<var_name>                     - Use existing environment variable

Examples:
  $0 -f .env -s bitwarden:myapp:db_password -s aws:prod:api_key -- python app.py
  $0 -s gcp:my-project:database-creds -s vault:secret/data/myapp:token -e DEBUG=true -- ./server
  $0 -l                              # List all available modules
EOF
    exit 1
}

# Initialize logging
mkdir -p "$(dirname "$LOG_FILE")"
> "$LOG_FILE"  # Clear log file

# Global variables
declare -A ENV_VARS
VERBOSE=false
SECRET_SOURCES=()
ENV_FILE="$DEFAULT_ENV_FILE"

# Create modules directory if it doesn't exist
create_modules_dir() {
    mkdir -p "$MODULES_DIR"
    
    # Create default module templates if they don't exist
    local modules=(
        "bitwarden.sh"
        "aws.sh"
        "gcp.sh"
        "vault.sh"
        "azure.sh"
        "file.sh"
        "env.sh"
    )
    
    for mod in "${modules[@]}"; do
        if [[ ! -f "$MODULES_DIR/$mod" ]]; then
            cat > "$MODULES_DIR/$mod" << EOF
#!/bin/bash
# Module: ${mod%.sh}
# Usage: load_secret_<${mod%.sh}> <args...>

load_secret_${mod%.sh}() {
    local args=("\$@")
    case \${#args[@]} in
        0)
            echo "Error: No arguments provided for ${mod%.sh}" >&2
            return 1
            ;;
    esac
    
    # Your implementation here
    echo "Module \$0 not implemented yet" >&2
    return 1
}
EOF
            chmod +x "$MODULES_DIR/$mod"
            info "Created template module: $MODULES_DIR/$mod"
        fi
    done
}

# Load all modules from MODULES_DIR
load_modules() {
    info "Loading modules from $MODULES_DIR"
    
    if [[ ! -d "$MODULES_DIR" ]]; then
        create_modules_dir
    fi
    
    # Source all .sh files in modules directory
    for module in "$MODULES_DIR"/*.sh; do
        if [[ -f "$module" ]]; then
            source "$module"
            info "Loaded module: $(basename "$module")"
        fi
    done
}

# Check if required CLI tools are installed
check_dependencies() {
    local deps=("jq" "awk" "grep")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "Required dependency '$dep' is not installed"
            return 1
        fi
    done
    
    return 0
}

# Parse secret source string (format: source:key1:key2:...)
parse_secret_source() {
    local source_str="$1"
    local source_type=""
    local key_parts=()
    
    # Split by first colon
    if [[ "$source_str" == *:* ]]; then
        source_type="${source_str%%:*}"
        # Extract remaining parts after first colon
        key_parts=($(echo "${source_str#*:}" | tr ':' '\n'))
    else
        source_type="$source_str"
    fi
    
    echo "$source_type"
    printf '%s\n' "${key_parts[@]}"
}

# Load secret from a specific source
load_secret_from_source() {
    local source_spec="$1"
    local source_type
    local key_parts=()
    
    # Parse the source specification
    readarray -t parsed < <(parse_secret_source "$source_spec")
    source_type="${parsed[0]}"
    unset 'parsed[0]'
    key_parts=("${parsed[@]}")
    
    # Check if module exists
    local module_file="$MODULES_DIR/${source_type}.sh"
    if [[ ! -f "$module_file" ]]; then
        error "Unknown secret source: $source_type"
        return 1
    fi
    
    # Try to call the appropriate function
    local func_name="load_secret_$source_type"
    if declare -f "$func_name" > /dev/null; then
        info "Loading secret from $source_type: $source_spec"
        local result
        result=$("$func_name" "${key_parts[@]}" 2>&1)
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            # Extract key-value pair from result (expecting "KEY=VALUE")
            if [[ "$result" == *"="* ]]; then
                local key="${result%%=*}"
                local value="${result#*=}"
                ENV_VARS["$key"]="$value"
                success "Loaded: $key = [REDACTED]"
                return 0
            else
                # If result is just a value, use source spec as key
                ENV_VARS["$source_spec"]="$result"
                success "Loaded: $source_spec = [REDACTED]"
                return 0
            fi
        else
            error "Failed to load secret from $source_type: $result"
            return 1
        fi
    else
        error "Module function '$func_name' not found in $module_file"
        return 1
    fi
}

# Load environment variables from file
load_env_file() {
    if [[ -f "$ENV_FILE" ]]; then
        info "Loading environment variables from: $ENV_FILE"
        set -a
        source "$ENV_FILE"
        set +a
    else
        warn "Environment file '$ENV_FILE' not found"
    fi
}

# Process all secret sources
process_secret_sources() {
    for source in "${SECRET_SOURCES[@]}"; do
        load_secret_from_source "$source"
    done
}

# Export all collected environment variables
export_env_vars() {
    info "Exporting ${#ENV_VARS[@]} environment variables"
    
    for key in "${!ENV_VARS[@]}"; do
        export "$key=${ENV_VARS[$key]}"
        if [[ "$VERBOSE" == true ]]; then
            info "Exported: $key=[REDACTED]"  # Don't log actual secrets
        fi
    done
}

# Main execution
main() {
    # Check dependencies
    if ! check_dependencies; then
        error "Missing required dependencies. Aborting."
        exit 1
    fi
    
    # Create and load modules
    load_modules
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                ENV_FILE="$2"
                shift 2
                ;;
            -e|--env)
                # Directly add to ENV_VARS
                if [[ "$2" == *"="* ]]; then
                    local key="${2%%=*}"
                    local value="${2#*=}"
                    ENV_VARS["$key"]="$value"
                    info "Set environment variable: $key=[REDACTED]"
                else
                    error "Invalid -e argument format: $2 (should be KEY=VALUE)"
                    exit 1
                fi
                shift 2
                ;;
            -s|--secret)
                SECRET_SOURCES+=("$2")
                shift 2
                ;;
            -l|--list)
                info "Available secret sources:"
                ls -1 "$MODULES_DIR"/*.sh 2>/dev/null | while read -r mod; do
                    echo "  $(basename "$mod" .sh)"
                done
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            --)
                shift
                break
                ;;
            *)
                error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Check if command is provided
    if [[ $# -eq 0 ]]; then
        error "No command specified. Use '--' followed by your command."
        usage
    fi
    
    # Load environment file
    load_env_file
    
    # Process secret sources
    process_secret_sources
    
    # Export all variables
    export_env_vars
    
    # Display final environment state if verbose
    if [[ "$VERBOSE" == true ]]; then
        echo -e "\n${PURPLE}Final Environment Variables:${NC}"
        env | grep -E "^(${!ENV_VARS[*]// /|})="
        echo ""
    fi
    
    # Execute the command
    info "Executing: $*"
    exec "$@"
}

# Start main execution
main "$@"
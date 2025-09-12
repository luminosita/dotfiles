#!/opt/homebrew/bin/bash

# shh.sh - Modular secret retrieval environment loader
# Supports: .env files, Bitwarden, AWS, GCP, HashiCorp Vault, Azure Key Vault, and more
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

# Check for Bash 4.0+ (required for associative arrays)
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
  echo -e "${RED}ERROR:${NC} This script requires Bash 4.0+"
  echo "Your current Bash version: ${BASH_VERSION}"
  echo "On macOS, install newer Bash with:"
  echo "  brew install bash"
  echo "Then run with: /usr/local/bin/bash $0 $@"
  exit 1
fi

# Usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] -- COMMAND [ARGS...]

Load secrets from multiple sources and set custom environment variables.

Options:
  -f FILE          Load .env file (default: .env)
  -e KEY=VALUE     Set environment variable directly
  -s SOURCE=ENV_VAR_NAME  Secret source with explicit env var mapping
  -l               List available secret sources
  -v               Verbose mode (show loaded vars)
  -h               Show this help

Supported Sources:
  bitwarden:<item>[:field]=ENV_VAR
  aws:<profile>:<secret>=ENV_VAR
  gcp:<project>:<secret>=ENV_VAR
  vault:<path>:<key>=ENV_VAR
  azure:<vault>:<secret>=ENV_VAR
  file:<path>=ENV_VAR
  env:<var_name>=ENV_VAR

Examples:
  $0 -s bitwarden:Qwen_API:API_Key=QWEN_API_KEY -s aws:prod:db_pass=DB_PASS -- python app.py
  $0 -s file:/secrets/cert.pem=SSL_CERT -e DEBUG=true -- node server.js
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

# Parse secret source string: "source:args=ENV_VAR"
parse_secret_source() {
    local spec="$1"
    local source_part=""
    local env_var_name=""

    # Split on last '=' (in case value contains =)
    if [[ "$spec" == *"="* ]]; then
        # Extract everything after last =
        env_var_name="${spec##*=}"
        source_part="${spec%=*}"
    else
        source_part="$spec"
        # Fallback: auto-generate env var name from source_part
        # Replace : with _ and remove non-alphanumeric
        env_var_name="$(echo "$source_part" | tr ':' '_' | sed 's/[^a-zA-Z0-9_]/_/g' | tr '[:lower:]' '[:upper:]')"
    fi

    # Validate env_var_name
    if [[ ! "$env_var_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        error "Invalid environment variable name: '$env_var_name'"
        error "Must start with letter/underscore, only letters, numbers, underscores allowed."
        return 1
    fi

    echo "$source_part"
    echo "$env_var_name"
}

# Load secret from source
load_secret_from_source() {
    local source_spec="$1"
    local source_part
    local target_env

    # Parse into source part and target env var name
    readarray -t parsed < <(parse_secret_source "$source_spec")
    source_part="${parsed[0]}"
    target_env="${parsed[1]}"

    # Skip if parsing failed
    [[ $? -ne 0 ]] && return 1

    local module_file="$MODULES_DIR/${source_part%%:*}.sh"
    if [[ ! -f "$module_file" ]]; then
        error "Unknown secret source: ${source_part%%:*}"
        return 1
    fi

    local func_name="load_secret_${source_part%%:*}"
    if ! declare -f "$func_name" > /dev/null; then
        error "Module function '$func_name' not defined in $module_file"
        return 1
    fi

    # Extract source-specific args (everything after first colon)
    local source_type="${source_part%%:*}"
    local source_args_str="${source_part#*:}"

    # Split args by colon into array
    IFS=':' read -r -a source_args <<< "$source_args_str"

    # Append target_env as last argument to module
    source_args+=("$target_env")

    info "Loading secret from $source_type → $target_env"

    local result
    result=$("$func_name" "${source_args[@]}" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        # Module should output: KEY=VALUE (but we're overriding KEY with target_env)
        # So we extract VALUE and assign to target_env
        if [[ "$result" == *"="* ]]; then
            # Extract value from key=value
            local value="${result#*=}"
            ENV_VARS["$target_env"]="$value"
            success "Loaded: $target_env = [REDACTED]"
        else
            # If module returns just value, use as-is
            ENV_VARS["$target_env"]="$result"
            success "Loaded: $target_env = [REDACTED]"
        fi
    else
        error "Failed to load secret: $result"
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
                    # Validate key
                    if [[ ! "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                        error "Invalid variable name: $key"
                        exit 1
                    fi
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
        for key in "${!ENV_VARS[@]}"; do
            printf "  %-30s = [REDACTED]\n" "$key"
        done
        echo ""
    fi
    
    # Execute the command
    info "Executing: $*"
    exec "$@"
}

# Start main execution
main "$@"
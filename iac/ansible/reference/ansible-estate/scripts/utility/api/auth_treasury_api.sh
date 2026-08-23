#!/bin/bash

# Generic script for automatic Treasury API authorization via Keycloak
# Usage: ./auth_treasury_api.sh [ENV] [USERNAME] [PASSWORD] [CLIENT_ID] [CLIENT_SECRET]
#
# Environment variables (optional):
#   KEYCLOAK_DOMAIN_PROD - Keycloak domain for PROD (default: keycloak.example.com)
#   KEYCLOAK_DOMAIN_PREPROD - Keycloak domain for PREPROD (default: keycloak.preprod.example.com)
#   KEYCLOAK_DOMAIN_DEMO - Keycloak domain for DEMO (default: keycloak.demo.example.com)
#   K8S_NAMESPACE - Kubernetes namespace for PROD (default: your-namespace)
#   KEYCLOAK_USERNAME - username (can be passed as an argument)
#   KEYCLOAK_PASSWORD - user password (can be passed as an argument)
#   KEYCLOAK_CLIENT_ID - client ID (can be passed as an argument)
#   KEYCLOAK_CLIENT_SECRET - client secret (can be passed as an argument)
# Examples:
#   export KEYCLOAK_USERNAME=username
#   export KEYCLOAK_PASSWORD=password
#   ./auth_treasury_api.sh prod                               # ENV=prod, parameters from environment variables
#   ./auth_treasury_api.sh prod username password client_id client_secret  # All parameters are set
# Parameters:
#   - ENV: prod/preprod/demo (if omitted, an interactive prompt is used)
#   - USERNAME: can be passed as an argument or an environment variable KEYCLOAK_USERNAME
#   - PASSWORD: can be passed as an argument or an environment variable KEYCLOAK_PASSWORD
#   - CLIENT_ID: can be passed as an argument or an environment variable KEYCLOAK_CLIENT_ID
#   - CLIENT_SECRET: can be passed as an argument or an environment variable KEYCLOAK_CLIENT_SECRET

set -e  # Exit on error

# Colors for readable output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Help printer
show_help() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}                    Treasury API - Keycloak authorization${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}DESCRIPTION:${NC}"
    echo "  Script for automatic Treasury API authorization via Keycloak."
    echo "  Obtains a Bearer JWT token from the Keycloak realm 'treasure' for further API work."
    echo ""
    echo -e "${BLUE}SYNOPSIS:${NC}"
    echo "  ./auth_treasury_api.sh [ENV] [USERNAME] [PASSWORD] [CLIENT_ID] [CLIENT_SECRET]"
    echo "  ./auth_treasury_api.sh [--help|-h]"
    echo ""
    echo -e "${BLUE}PARAMETERS:${NC}"
    echo -e "  ${GREEN}ENV${NC}            Environment: prod, preprod or demo"
    echo "                 If omitted, an interactive prompt is used"
    echo ""
    echo -e "  ${GREEN}USERNAME${NC}       Username for Keycloak authorization"
    echo "                 Can be passed as an argument or an environment variable KEYCLOAK_USERNAME"
    echo ""
    echo -e "  ${GREEN}PASSWORD${NC}       User password"
    echo "                 Can be passed as an argument or an environment variable KEYCLOAK_PASSWORD"
    echo ""
    echo -e "  ${GREEN}CLIENT_ID${NC}      Keycloak client identifier"
    echo "                 Can be passed as an argument or an environment variable KEYCLOAK_CLIENT_ID"
    echo ""
    echo -e "  ${GREEN}CLIENT_SECRET${NC}  Keycloak client secret"
    echo "                 Can be passed as an argument or an environment variable KEYCLOAK_CLIENT_SECRET"
    echo ""
    echo -e "  ${GREEN}--help, -h${NC}     Show this help"
    echo ""
    echo -e "${BLUE}USAGE EXAMPLES:${NC}"
    echo ""
    echo "  # Interactive environment choice, all parameters default"
    echo -e "  ${YELLOW}./auth_treasury_api.sh${NC}"
    echo ""
    echo "  # PROD environment set, parameters from environment variables"
    echo -e "  ${YELLOW}export KEYCLOAK_USERNAME=username${NC}"
    echo -e "  ${YELLOW}export KEYCLOAK_PASSWORD=password${NC}"
    echo -e "  ${YELLOW}./auth_treasury_api.sh prod${NC}"
    echo ""
    echo "  # Environment, username and password are set"
    echo -e "  ${YELLOW}./auth_treasury_api.sh prod username password${NC}"
    echo ""
    echo "  # All parameters are set"
    echo -e "  ${YELLOW}./auth_treasury_api.sh prod username password client_id client_secret${NC}"
    echo ""
    echo "  # Using environment variables"
    echo -e "  ${YELLOW}export KEYCLOAK_USERNAME=username${NC}"
    echo -e "  ${YELLOW}export KEYCLOAK_PASSWORD=password${NC}"
    echo -e "  ${YELLOW}./auth_treasury_api.sh prod${NC}"
    echo ""
    echo "  # Show help"
    echo -e "  ${YELLOW}./auth_treasury_api.sh --help${NC}"
    echo ""
    echo -e "${BLUE}ENVIRONMENTS:${NC}"
    echo -e "  ${GREEN}prod${NC}     Production environment"
    echo "          • Uses port-forward to bypass the WAF"
    echo "          • Automatically sets up kubectl port-forward to the keycloak-http service"
    echo "          • URL: localhost:8081"
    echo ""
    echo -e "  ${GREEN}preprod${NC}  Pre-production environment"
    echo "          • Direct connection via an external URL"
    echo "          • URL: configured via the KEYCLOAK_DOMAIN_PREPROD"
    echo ""
    echo -e "  ${GREEN}demo${NC}     Demo environment"
    echo "          • Direct connection via an external URL"
    echo "          • URL: configured via the KEYCLOAK_DOMAIN_DEMO"
    echo ""
    echo -e "${BLUE}FEATURES:${NC}"
    echo "  • Simple Keycloak authorization (one request)"
    echo "  • For PROD: automatic port-forward setup (WAF bypass)"
    echo "  • Colorized formatted output"
    echo "  • Automatic cleanup of the port-forward process on exit"
    echo ""
    echo -e "${BLUE}DEPENDENCIES:${NC}"
    echo "  • curl - for HTTP requests"
    echo "  • jq - for JSON parsing (recommended, not required)"
    echo "  • kubectl - only for the PROD environment with port-forward"
    echo ""
    echo -e "${BLUE}KEYCLOAK:${NC}"
    echo "  • Realm: treasure"
    echo "  • Endpoint: /realms/treasure/protocol/openid-connect/token"
    echo "  • Grant type: password"
    echo ""
    echo -e "${BLUE}IN-SCRIPT SETTINGS:${NC}"
    echo "  The script can be configured in its source:"
    echo ""
    echo -e "  ${YELLOW}• Port-forward:${NC}"
    echo "    Change USE_PORT_FORWARD for any environment:"
    echo "    - Lines 160, 166, 171 (prod, preprod, demo)"
    echo ""
    echo -e "  ${YELLOW}• URL domains:${NC}"
    echo "    Change KEYCLOAK_DOMAIN for environments:"
    echo "    - Lines 159, 165, 170 (prod, preprod, demo)"
    echo ""
    echo -e "  ${YELLOW}• URL paths:${NC}"
    echo "    Change TOKEN_URL construction in setup_urls():"
    echo "    - Lines 346, 349 (port-forward and regular connection)"
    echo ""
    echo -e "  ${YELLOW}• Default parameters:${NC}"
    echo "    Default values can be changed in the script source"
    echo ""
    echo -e "${BLUE}RETURNS:${NC}"
    echo "  Bearer JWT Access Token, that can be used to authorize against Treasury API"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Check help arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

# Environment picker
select_environment() {
    local env_arg="$1"
    
    if [ -n "$env_arg" ]; then
        ENV=$(echo "$env_arg" | tr '[:upper:]' '[:lower:]')
    else
        # Interactive choice
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}Environment selection${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  1) PROD    (production)"
        echo "  2) PREPROD (pre-production)"
        echo "  3) DEMO    (demo)"
        echo ""
        read -p "Select environment (1-3) [default: 1]: " choice
        
        case "${choice:-1}" in
            1)
                ENV="prod"
                ;;
            2)
                ENV="preprod"
                ;;
            3)
                ENV="demo"
                ;;
            *)
                echo -e "${YELLOW}Invalid choice, PROD is used${NC}"
                ENV="prod"
                ;;
        esac
    fi
    
    # Validate environment
    case "$ENV" in
        prod|PROD|production)
            ENV="prod"
            KEYCLOAK_DOMAIN="${KEYCLOAK_DOMAIN_PROD:-keycloak.example.com}"
            USE_PORT_FORWARD=true  # PROD uses port-forward
            K8S_NAMESPACE="${K8S_NAMESPACE:-your-namespace}"
            ;;
        preprod|PREPROD|pre-production)
            ENV="preprod"
            KEYCLOAK_DOMAIN="${KEYCLOAK_DOMAIN_PREPROD:-keycloak.preprod.example.com}"
            USE_PORT_FORWARD=false
            ;;
        demo|DEMO)
            ENV="demo"
            KEYCLOAK_DOMAIN="${KEYCLOAK_DOMAIN_DEMO:-keycloak.demo.example.com}"
            USE_PORT_FORWARD=false
            ;;
        *)
            echo -e "${RED}Error: Invalid environment '$ENV'. Use: prod, preprod or demo${NC}"
            exit 1
            ;;
    esac
}

# Pretty header printer
print_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Info printer
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Success printer
print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

# Error printer
print_error() {
    echo -e "${RED}❌${NC} $1"
}

# Warning printer
print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# Variables that store the port-forward process PID
KEYCLOAK_PORT_FORWARD_PID=""
KEYCLOAK_LOCAL_PORT=""

# Clean up the port-forward process on exit
cleanup_port_forward() {
    if [ -n "$KEYCLOAK_PORT_FORWARD_PID" ] && [[ "$KEYCLOAK_PORT_FORWARD_PID" =~ ^[0-9]+$ ]]; then
        kill $KEYCLOAK_PORT_FORWARD_PID 2>/dev/null && print_info "Stopped port-forward for keycloak (PID: $KEYCLOAK_PORT_FORWARD_PID)"
        KEYCLOAK_PORT_FORWARD_PID=""
    fi
}

# Register a trap for cleanup on exit
trap cleanup_port_forward EXIT INT TERM

# Find a service in Kubernetes
find_k8s_service() {
    local namespace="$1"
    local service_pattern="$2"
    
    kubectl -n "$namespace" get svc 2>/dev/null | grep "$service_pattern" | head -1 | awk '{print $1}'
}

# Get the service port from Kubernetes
get_k8s_service_port() {
    local namespace="$1"
    local service_name="$2"
    local port_name="${3:-http}"
    
    # Try to get the port by name
    local port=$(kubectl -n "$namespace" get svc "$service_name" -o jsonpath="{.spec.ports[?(@.name==\"$port_name\")].port}" 2>/dev/null)
    
    # If not found by name, take the first port
    if [ -z "$port" ]; then
        port=$(kubectl -n "$namespace" get svc "$service_name" -o jsonpath="{.spec.ports[0].port}" 2>/dev/null)
    fi
    
    echo "$port"
}

# Create a port-forward for the service
# Returns the process PID or an empty string on error
setup_port_forward() {
    local namespace="$1"
    local service_name="$2"
    local local_port="$3"
    local service_port="$4"
    
    if [ -z "$service_name" ]; then
        return 1
    fi
    
    # Start port-forward in the background
    kubectl -n "$namespace" port-forward "svc/$service_name" "$local_port:$service_port" > /dev/null 2>&1 &
    local pid=$!
    
    # Wait briefly to confirm the process started
    sleep 1
    if ps -p $pid > /dev/null 2>&1; then
        echo "$pid"
        return 0
    else
        return 1
    fi
}

# Set up port-forward for the PROD environment
setup_prod_port_forward() {
    if [ "$USE_PORT_FORWARD" != "true" ]; then
        return 0
    fi
    
    # Check that kubectl is present
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Install kubectl to use port-forward in the PROD environment."
        exit 1
    fi
    
    # Check cluster availability
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to the Kubernetes cluster. Check the kubectl context."
        exit 1
    fi
    
    print_header "Set up port-forward for the PROD environment"
    print_info "Setting up port-forward for keycloak on port 8081"
    echo ""
    
    # Search for the keycloak-http service (as in the example)
    print_info "Looking up the keycloak-http service in namespace $K8S_NAMESPACE..."
    KEYCLOAK_SERVICE=$(find_k8s_service "$K8S_NAMESPACE" "keycloak-http")
    
    if [ -z "$KEYCLOAK_SERVICE" ]; then
        # Try any keycloak service
        KEYCLOAK_SERVICE=$(find_k8s_service "$K8S_NAMESPACE" "keycloak")
    fi
    
    if [ -z "$KEYCLOAK_SERVICE" ]; then
        print_error "keycloak-http/keycloak service not found in namespace $K8S_NAMESPACE"
        print_info "Available services:"
        kubectl -n "$K8S_NAMESPACE" get svc | grep -E "NAME|keycloak" || echo "  (no services with 'keycloak' in the name)"
        exit 1
    fi
    
    print_success "Found service: $KEYCLOAK_SERVICE"
    
    # Get the service port (default 80 for http)
    KEYCLOAK_SERVICE_PORT=$(get_k8s_service_port "$K8S_NAMESPACE" "$KEYCLOAK_SERVICE" "http")
    KEYCLOAK_SERVICE_PORT="${KEYCLOAK_SERVICE_PORT:-80}"
    KEYCLOAK_LOCAL_PORT="8081"
    
    print_info "Service port $KEYCLOAK_SERVICE: $KEYCLOAK_SERVICE_PORT"
    
    # Create port-forward for keycloak
    print_info "Creating port-forward for $KEYCLOAK_SERVICE: localhost:$KEYCLOAK_LOCAL_PORT -> $K8S_NAMESPACE/$KEYCLOAK_SERVICE:$KEYCLOAK_SERVICE_PORT"
    KEYCLOAK_PORT_FORWARD_PID=$(setup_port_forward "$K8S_NAMESPACE" "$KEYCLOAK_SERVICE" "$KEYCLOAK_LOCAL_PORT" "$KEYCLOAK_SERVICE_PORT" 2>/dev/null)
    if [ -z "$KEYCLOAK_PORT_FORWARD_PID" ]; then
        print_error "Failed to create port-forward for $KEYCLOAK_SERVICE"
        exit 1
    fi
    # Confirm the PID is a number
    if ! [[ "$KEYCLOAK_PORT_FORWARD_PID" =~ ^[0-9]+$ ]]; then
        print_error "Invalid PID for port-forward: $KEYCLOAK_PORT_FORWARD_PID"
        exit 1
    fi
    print_success "Port-forward for keycloak created (PID: $KEYCLOAK_PORT_FORWARD_PID)"
    
    echo ""
    print_info "Waiting 2 seconds for the port-forward connection to settle..."
    sleep 2
}

# URL setup (called after port-forward is set up for PROD)
setup_urls() {
    if [ "$USE_PORT_FORWARD" = "true" ] && [ -n "$KEYCLOAK_LOCAL_PORT" ]; then
        # For PROD with port-forward use localhost
        # IMPORTANT: port-forward bypasses ingress, so the direct path is used
        TOKEN_URL="http://localhost:${KEYCLOAK_LOCAL_PORT}/realms/treasure/protocol/openid-connect/token"
    else
        # Other environments use a regular URL through ingress
        TOKEN_URL="https://${KEYCLOAK_DOMAIN}/realms/treasure/protocol/openid-connect/token"
    fi
}

# Check that jq is available
if ! command -v jq &> /dev/null; then
    print_warning "jq is not installed. Install for correct operation: apt-get install jq"
    HAS_JQ=false
else
    HAS_JQ=true
fi

# Environment selection (may be passed as the first argument)
if [ -n "$1" ] && [[ "$1" =~ ^(prod|preprod|demo|PROD|PREPROD|DEMO|production|pre-production)$ ]]; then
    # ENV passed as the first argument
    select_environment "$1"
    # Arguments are shifted — use environment variables or arguments
    USERNAME="${2:-${KEYCLOAK_USERNAME:-}}"
    PASSWORD="${3:-${KEYCLOAK_PASSWORD:-}}"
    CLIENT_ID="${4:-${KEYCLOAK_CLIENT_ID:-}}"
    CLIENT_SECRET="${5:-${KEYCLOAK_CLIENT_SECRET:-}}"
else
    # ENV not passed; pick interactively, arguments are not shifted
    select_environment ""
    USERNAME="${1:-${KEYCLOAK_USERNAME:-}}"
    PASSWORD="${2:-${KEYCLOAK_PASSWORD:-}}"
    CLIENT_ID="${3:-${KEYCLOAK_CLIENT_ID:-}}"
    CLIENT_SECRET="${4:-${KEYCLOAK_CLIENT_SECRET:-}}"
fi

# Check required parameters
if [ -z "$USERNAME" ] || [ "$USERNAME" = "YOUR_USERNAME_HERE" ]; then
    print_error "USERNAME is not set. Pass it as an argument or an environment variable KEYCLOAK_USERNAME"
    exit 1
fi

if [ -z "$PASSWORD" ] || [ "$PASSWORD" = "YOUR_PASSWORD_HERE" ]; then
    print_error "PASSWORD is not set. Pass it as an argument or an environment variable KEYCLOAK_PASSWORD"
    exit 1
fi

if [ -z "$CLIENT_ID" ] || [ "$CLIENT_ID" = "YOUR_CLIENT_ID_HERE" ]; then
    print_error "CLIENT_ID is not set. Pass it as an argument or an environment variable KEYCLOAK_CLIENT_ID"
    exit 1
fi

if [ -z "$CLIENT_SECRET" ] || [ "$CLIENT_SECRET" = "YOUR_CLIENT_SECRET_HERE" ]; then
    print_error "CLIENT_SECRET is not set. Pass it as an argument or an environment variable KEYCLOAK_CLIENT_SECRET"
    exit 1
fi

# Set up port-forward for PROD (when needed)
if [ "$USE_PORT_FORWARD" = "true" ]; then
    setup_prod_port_forward
fi

# Set URLs after port-forward
setup_urls

# Start
clear
print_header "Treasury API Keycloak authorization"
echo -e "${BLUE}Environment:${NC} ${ENV^^}"
if [ "$USE_PORT_FORWARD" = "true" ]; then
    echo -e "${BLUE}Mode:${NC} Port-forward (localhost)"
    echo -e "${BLUE}Username:${NC} $USERNAME"
    echo -e "${BLUE}Client ID:${NC} $CLIENT_ID"
    echo ""
    echo -e "${CYAN}URL via port-forward:${NC}"
    echo -e "  • Keycloak: http://localhost:${KEYCLOAK_LOCAL_PORT}"
else
    echo -e "${BLUE}Username:${NC} $USERNAME"
    echo -e "${BLUE}Client ID:${NC} $CLIENT_ID"
    echo ""
    echo -e "${CYAN}URL in use:${NC}"
    echo -e "  • Keycloak: https://${KEYCLOAK_DOMAIN}"
fi
echo ""

# Check that the URL is set
if [ -z "$TOKEN_URL" ]; then
    print_error "URL was not configured. Check the configuration."
    exit 1
fi

# Debug info before the request
print_info "URL for the token request: $TOKEN_URL"

if [ "$USE_PORT_FORWARD" = "true" ]; then
    echo ""
    print_info "Checking the port-forward process status..."
    
    # Check keycloak port-forward
    if [ -n "$KEYCLOAK_PORT_FORWARD_PID" ] && [[ "$KEYCLOAK_PORT_FORWARD_PID" =~ ^[0-9]+$ ]]; then
        if ps -p $KEYCLOAK_PORT_FORWARD_PID > /dev/null 2>&1; then
            print_success "Port-forward for keycloak is active (PID: $KEYCLOAK_PORT_FORWARD_PID, port: $KEYCLOAK_LOCAL_PORT)"
        else
            print_error "Port-forward for keycloak is NOT working (PID: $KEYCLOAK_PORT_FORWARD_PID not found)"
        fi
    elif [ -n "$KEYCLOAK_PORT_FORWARD_PID" ]; then
        print_warning "Port-forward for keycloak: invalid PID (must be a number, got: $KEYCLOAK_PORT_FORWARD_PID)"
    fi
    
    # Port availability test
    print_info "Checking port availability..."
    if command -v nc &> /dev/null || command -v netcat &> /dev/null; then
        if nc -z localhost ${KEYCLOAK_LOCAL_PORT:-8081} 2>/dev/null; then
            print_success "Port ${KEYCLOAK_LOCAL_PORT:-8081} is available"
        else
            print_error "Port ${KEYCLOAK_LOCAL_PORT:-8081} is NOT available"
        fi
    fi
    echo ""
fi

# Step 1: Obtain a token from Keycloak
print_header "Obtain a token from Keycloak"
print_info "Sending a token request..."

TOKEN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TOKEN_URL" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "client_id=$CLIENT_ID" \
    --data-urlencode "client_secret=$CLIENT_SECRET" \
    --data-urlencode "grant_type=password" \
    --data-urlencode "username=$USERNAME" \
    --data-urlencode "password=$PASSWORD")

# Extract the HTTP status and response body
HTTP_CODE=$(echo "$TOKEN_RESPONSE" | tail -n 1)
TOKEN_RESPONSE=$(echo "$TOKEN_RESPONSE" | sed '$d')

print_info "HTTP status code: $HTTP_CODE"

if [ -z "$TOKEN_RESPONSE" ]; then
    print_error "Empty response from Keycloak"
    print_info "HTTP status: $HTTP_CODE"
    print_info "URL: $TOKEN_URL"
    if [ "$USE_PORT_FORWARD" = "true" ]; then
        print_info "Check the port-forward process:"
        print_info "  ps aux | grep 'port-forward'"
        print_info "  kubectl -n $K8S_NAMESPACE get svc | grep keycloak"
    fi
    exit 1
fi

# Error check
if echo "$TOKEN_RESPONSE" | grep -q '"error"'; then
    print_error "Error obtaining the token:"
    if [ "$HAS_JQ" = true ]; then
        ERROR_DESC=$(echo "$TOKEN_RESPONSE" | jq -r '.error_description // .error')
        ERROR_CODE=$(echo "$TOKEN_RESPONSE" | jq -r '.error')
        echo -e "  ${RED}Error code:${NC} $ERROR_CODE"
        echo -e "  ${RED}Description:${NC} $ERROR_DESC"
        echo ""
        echo "Full response:"
        echo "$TOKEN_RESPONSE" | jq .
    else
        echo "$TOKEN_RESPONSE"
    fi
    echo ""
    print_warning "Possible causes:"
    echo "  • Invalid username or password"
    echo "  • Invalid client_id or client_secret"
    echo "  • The user has no access to the realm 'treasure'"
    exit 1
fi

# Check that a token is present
if ! echo "$TOKEN_RESPONSE" | grep -q '"access_token"'; then
    print_error "The response has no access_token"
    print_info "Full response:"
    if [ "$HAS_JQ" = true ]; then
        echo "$TOKEN_RESPONSE" | jq .
    else
        echo "$TOKEN_RESPONSE"
    fi
    exit 1
fi

# Extract the token
if [ "$HAS_JQ" = true ]; then
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
    TOKEN_TYPE=$(echo "$TOKEN_RESPONSE" | jq -r '.token_type // "Bearer"')
    EXPIRES_IN=$(echo "$TOKEN_RESPONSE" | jq -r '.expires_in // "N/A"')
    REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.refresh_token // ""')
else
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    TOKEN_TYPE="Bearer"
    EXPIRES_IN="N/A"
fi

print_success "Authorization succeeded!"

# Final token output
print_header "Authorization result"

if [ "$HAS_JQ" = true ]; then
    echo -e "${BLUE}Token type:${NC} $TOKEN_TYPE"
    if [ "$EXPIRES_IN" != "N/A" ] && [ "$EXPIRES_IN" != "null" ]; then
        echo -e "${BLUE}Expires in:${NC} $EXPIRES_IN seconds"
    fi
    echo ""
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Bearer JWT Access Token:${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}$ACCESS_TOKEN${NC}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Additional information
if [ "$HAS_JQ" = true ] && [ -n "$REFRESH_TOKEN" ] && [ "$REFRESH_TOKEN" != "null" ]; then
    echo -e "${BLUE}Refresh Token:${NC}"
    echo -e "${CYAN}$REFRESH_TOKEN${NC}"
    echo ""
fi

# Example token usage
echo -e "${BLUE}Example token usage with curl:${NC}"
echo -e "${YELLOW}curl -H \"Authorization: Bearer $ACCESS_TOKEN\" ...${NC}"
echo ""

print_success "Done! The token is copied above."


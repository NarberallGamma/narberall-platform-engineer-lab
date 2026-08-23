#!/bin/bash

# Generic script for automatic OTP authorization in treasury Box API
# Usage: ./auth_treasury_box_api.sh [ENV] [LOGIN] [COMPANY_ID] [PASSWORD]
#
# Environment variables (optional):
#   AUTH_DOMAIN_PROD - auth service domain for PROD (default: auth.example.com)
#   WEB_DOMAIN_PROD - web service domain for PROD (default: web.example.com)
#   AUTH_DOMAIN_PREPROD - auth service domain for PREPROD (default: auth.preprod.example.com)
#   WEB_DOMAIN_PREPROD - web service domain for PREPROD (default: web.preprod.example.com)
#   AUTH_DOMAIN_DEMO - auth service domain for DEMO (default: auth.demo.example.com)
#   WEB_DOMAIN_DEMO - web service domain for DEMO (default: web.demo.example.com)
#   K8S_NAMESPACE - Kubernetes namespace for PROD (default: your-namespace)
#   treasury_BOX_LOGIN - login/phone (can be passed as an argument)
#   treasury_BOX_COMPANY_ID - company UUID (can be passed as an argument)
#   treasury_BOX_PASSWORD - password to request a new OTP (can be passed as an argument, optional)
# Examples:
#   export treasury_BOX_LOGIN=+79991234567
#   export treasury_BOX_COMPANY_ID=company-uuid
#   ./auth_treasury_box_api.sh prod                               # ENV=prod, parameters from environment variables
#   ./auth_treasury_box_api.sh prod +79991234567 company-uuid     # All parameters are set
# Parameters:
#   - ENV: prod/preprod/demo (if omitted, an interactive prompt is used)
#   - LOGIN: can be passed as an argument or an environment variable treasury_BOX_LOGIN
#   - COMPANY_ID: can be passed as an argument or an environment variable treasury_BOX_COMPANY_ID
#   - PASSWORD: can be passed as an argument or an environment variable treasury_BOX_PASSWORD (optional)

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
    echo -e "${CYAN}                      treasury Box API - OTP authorization${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}DESCRIPTION:${NC}"
    echo "  Script for automatic OTP authorization in treasury Box API."
    echo "  Fetches the OTP code list, finds the newest valid code or requests a new one,"
    echo "  then signs in and returns a Bearer JWT token."
    echo ""
    echo -e "${BLUE}SYNOPSIS:${NC}"
    echo "  ./auth_treasury_box_api.sh [ENV] [LOGIN] [COMPANY_ID] [PASSWORD]"
    echo "  ./auth_treasury_box_api.sh [--help|-h]"
    echo ""
    echo -e "${BLUE}PARAMETERS:${NC}"
    echo -e "  ${GREEN}ENV${NC}           Environment: prod, preprod or demo"
    echo "                If omitted, an interactive prompt is used"
    echo ""
    echo -e "  ${GREEN}LOGIN${NC}         Phone number for authorization"
    echo "                Can be passed as an argument or an environment variable treasury_BOX_LOGIN"
    echo ""
    echo -e "  ${GREEN}COMPANY_ID${NC}    Company UUID"
    echo "                Can be passed as an argument or an environment variable treasury_BOX_COMPANY_ID"
    echo ""
    echo -e "  ${GREEN}PASSWORD${NC}      Password for automatic new-OTP request"
    echo "                Can be passed as an argument or an environment variable treasury_BOX_PASSWORD"
    echo "                Used only when all existing OTP codes are spent (optional)"
    echo ""
    echo -e "  ${GREEN}--help, -h${NC}    Show this help"
    echo ""
    echo -e "${BLUE}USAGE EXAMPLES:${NC}"
    echo ""
    echo "  # Interactive environment choice, all parameters default"
    echo -e "  ${YELLOW}./auth_treasury_box_api.sh${NC}"
    echo ""
    echo "  # PROD environment set, parameters from environment variables"
    echo -e "  ${YELLOW}export treasury_BOX_LOGIN=+79991234567${NC}"
    echo -e "  ${YELLOW}export treasury_BOX_COMPANY_ID=company-uuid${NC}"
    echo -e "  ${YELLOW}./auth_treasury_box_api.sh prod${NC}"
    echo ""
    echo "  # Environment and login are set"
    echo -e "  ${YELLOW}./auth_treasury_box_api.sh prod +79991234567${NC}"
    echo ""
    echo "  # All parameters are set"
    echo -e "  ${YELLOW}./auth_treasury_box_api.sh prod +79991234567 company-uuid password${NC}"
    echo ""
    echo "  # Using environment variables"
    echo -e "  ${YELLOW}export treasury_BOX_LOGIN=+79991234567${NC}"
    echo -e "  ${YELLOW}export treasury_BOX_COMPANY_ID=company-uuid${NC}"
    echo -e "  ${YELLOW}./auth_treasury_box_api.sh prod${NC}"
    echo ""
    echo "  # Show help"
    echo -e "  ${YELLOW}./auth_treasury_box_api.sh --help${NC}"
    echo ""
    echo -e "${BLUE}ENVIRONMENTS:${NC}"
    echo -e "  ${GREEN}prod${NC}     Production environment"
    echo "          • Uses port-forward to bypass the WAF"
    echo "          • Automatically sets up kubectl port-forward to the pods"
    echo "          • URL: localhost:8081 (auth), localhost:8082 (web)"
    echo ""
    echo -e "  ${GREEN}preprod${NC}  Pre-production environment"
    echo "          • Direct connection via an external URL"
    echo "          • URL: configured via AUTH_DOMAIN_PREPROD and WEB_DOMAIN_PREPROD"
    echo ""
    echo -e "  ${GREEN}demo${NC}     Demo environment"
    echo "          • Direct connection via an external URL"
    echo "          • URL: configured via AUTH_DOMAIN_DEMO and WEB_DOMAIN_DEMO"
    echo ""
    echo -e "${BLUE}FEATURES:${NC}"
    echo "  • Automatic search for the newest valid OTP code"
    echo "  • Automatic request of a new OTP when all codes are used"
    echo "  • For PROD: automatic port-forward setup (WAF bypass)"
    echo "  • Colorized formatted output"
    echo "  • Automatic cleanup of port-forward processes on exit"
    echo ""
    echo -e "${BLUE}DEPENDENCIES:${NC}"
    echo "  • curl - for HTTP requests"
    echo "  • jq - for JSON parsing (recommended, not required)"
    echo "  • kubectl - only for the PROD environment with port-forward"
    echo ""
    echo -e "${BLUE}IN-SCRIPT SETTINGS:${NC}"
    echo "  The script can be configured in its source:"
    echo ""
    echo -e "  ${YELLOW}• Port-forward:${NC}"
    echo "    Change USE_PORT_FORWARD for any environment:"
    echo "    - Lines 156, 163, 169 (prod, preprod, demo)"
    echo ""
    echo -e "  ${YELLOW}• URL domains:${NC}"
    echo "    Change domains for environments:"
    echo "    - Lines 154-155, 161-162, 167-168 (AUTH_DOMAIN, WEB_DOMAIN)"
    echo ""
    echo -e "  ${YELLOW}• URL paths:${NC}"
    echo "    Change URL construction in setup_urls():"
    echo "    - Lines 406-413 (OTP_API_URL, AUTH_URL, REQUEST_OTP_URL)"
    echo ""
    echo -e "  ${YELLOW}• Default parameters:${NC}"
    echo "    Default values can be changed in the script source"
    echo ""
    echo -e "${BLUE}RETURNS:${NC}"
    echo "  Bearer JWT Access Token, that can be used to authorize against the API"
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
            AUTH_DOMAIN="${AUTH_DOMAIN_PROD:-auth.example.com}"
            WEB_DOMAIN="${WEB_DOMAIN_PROD:-web.example.com}"
            USE_PORT_FORWARD=true  # PROD uses port-forward
            K8S_NAMESPACE="${K8S_NAMESPACE:-your-namespace}"
            ;;
        preprod|PREPROD|pre-production)
            ENV="preprod"
            AUTH_DOMAIN="${AUTH_DOMAIN_PREPROD:-auth.preprod.example.com}"
            WEB_DOMAIN="${WEB_DOMAIN_PREPROD:-web.preprod.example.com}"
            USE_PORT_FORWARD=false
            ;;
        demo|DEMO)
            ENV="demo"
            AUTH_DOMAIN="${AUTH_DOMAIN_DEMO:-auth.demo.example.com}"
            WEB_DOMAIN="${WEB_DOMAIN_DEMO:-web.demo.example.com}"
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

# Variables that store port-forward process PIDs
AUTH_PORT_FORWARD_PID=""
WEB_PORT_FORWARD_PID=""
AUTH_LOCAL_PORT=""
WEB_LOCAL_PORT=""

# Clean up port-forward processes on exit
cleanup_port_forwards() {
    if [ -n "$AUTH_PORT_FORWARD_PID" ]; then
        kill $AUTH_PORT_FORWARD_PID 2>/dev/null && print_info "Stopped port-forward for the auth service (PID: $AUTH_PORT_FORWARD_PID)"
        AUTH_PORT_FORWARD_PID=""
    fi
    if [ -n "$WEB_PORT_FORWARD_PID" ]; then
        kill $WEB_PORT_FORWARD_PID 2>/dev/null && print_info "Stopped port-forward for the web service (PID: $WEB_PORT_FORWARD_PID)"
        WEB_PORT_FORWARD_PID=""
    fi
}

# Register a trap for cleanup on exit
trap cleanup_port_forwards EXIT INT TERM

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
    local port_name="${3:-http}"  # By default look up a port named http
    
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
setup_prod_port_forwards() {
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
    print_info "Setting up two port-forwards on different ports: auth (8081) and web/otp (8082)"
    echo ""
    
    # Looking up the auth service
    print_info "Looking up the treasury-auth service in namespace $K8S_NAMESPACE..."
    AUTH_SERVICE=$(find_k8s_service "$K8S_NAMESPACE" "treasury-auth")
    
    if [ -z "$AUTH_SERVICE" ]; then
        print_error "treasury-auth service not found in namespace $K8S_NAMESPACE"
        print_info "Available services:"
        kubectl -n "$K8S_NAMESPACE" get svc | grep -E "NAME|auth" || echo "  (no services with 'auth' in the name)"
        exit 1
    fi
    
    print_success "Found service: $AUTH_SERVICE"
    
    # Read the service port (default 8080 for actuator)
    AUTH_SERVICE_PORT=$(get_k8s_service_port "$K8S_NAMESPACE" "$AUTH_SERVICE" "http")
    AUTH_SERVICE_PORT="${AUTH_SERVICE_PORT:-8080}"
    AUTH_LOCAL_PORT="8081"
    
    print_info "Service port $AUTH_SERVICE: $AUTH_SERVICE_PORT"
    
    # Create port-forward for auth
    print_info "Creating port-forward for $AUTH_SERVICE: localhost:$AUTH_LOCAL_PORT -> $K8S_NAMESPACE/$AUTH_SERVICE:$AUTH_SERVICE_PORT"
    AUTH_PORT_FORWARD_PID=$(setup_port_forward "$K8S_NAMESPACE" "$AUTH_SERVICE" "$AUTH_LOCAL_PORT" "$AUTH_SERVICE_PORT" 2>/dev/null)
    if [ -z "$AUTH_PORT_FORWARD_PID" ]; then
        print_error "Failed to create port-forward for $AUTH_SERVICE"
        exit 1
    fi
    # Confirm the PID is a number
    if ! [[ "$AUTH_PORT_FORWARD_PID" =~ ^[0-9]+$ ]]; then
        print_error "Invalid PID for port-forward: $AUTH_PORT_FORWARD_PID"
        exit 1
    fi
    print_success "Port-forward for auth created (PID: $AUTH_PORT_FORWARD_PID)"
    
    # Looking up the web/otp service
    print_info "Looking up the treasury-otp/web service in namespace $K8S_NAMESPACE..."
    WEB_SERVICE=$(find_k8s_service "$K8S_NAMESPACE" "treasury-otp")
    
    if [ -z "$WEB_SERVICE" ]; then
        # Try a web service
        WEB_SERVICE=$(find_k8s_service "$K8S_NAMESPACE" "web")
    fi
    
    if [ -z "$WEB_SERVICE" ]; then
        # If treasury-otp/web is not found, reuse the auth service
        print_warning "No separate treasury-otp/web service found, using $AUTH_SERVICE"
        WEB_SERVICE="$AUTH_SERVICE"
        WEB_SERVICE_PORT="$AUTH_SERVICE_PORT"
        WEB_LOCAL_PORT="$AUTH_LOCAL_PORT"
        WEB_PORT_FORWARD_PID=""
    else
        print_success "Found service: $WEB_SERVICE"
        WEB_SERVICE_PORT=$(get_k8s_service_port "$K8S_NAMESPACE" "$WEB_SERVICE" "http")
        WEB_SERVICE_PORT="${WEB_SERVICE_PORT:-8080}"
        WEB_LOCAL_PORT="8082"
        
        # Create port-forward for web
        print_info "Creating port-forward for $WEB_SERVICE: localhost:$WEB_LOCAL_PORT -> $K8S_NAMESPACE/$WEB_SERVICE:$WEB_SERVICE_PORT"
        WEB_PORT_FORWARD_PID=$(setup_port_forward "$K8S_NAMESPACE" "$WEB_SERVICE" "$WEB_LOCAL_PORT" "$WEB_SERVICE_PORT" 2>/dev/null)
        if [ -z "$WEB_PORT_FORWARD_PID" ]; then
            print_warning "Failed to create port-forward for $WEB_SERVICE, use $AUTH_SERVICE"
            WEB_LOCAL_PORT="$AUTH_LOCAL_PORT"
            WEB_PORT_FORWARD_PID=""
        else
            # Confirm the PID is a number
            if [[ "$WEB_PORT_FORWARD_PID" =~ ^[0-9]+$ ]]; then
                print_success "Port-forward for web created (PID: $WEB_PORT_FORWARD_PID)"
            else
                print_warning "Invalid PID for web port-forward, using $AUTH_SERVICE"
                WEB_LOCAL_PORT="$AUTH_LOCAL_PORT"
                WEB_PORT_FORWARD_PID=""
            fi
        fi
    fi
    
    echo ""
    print_info "Waiting 2 seconds for port-forward connections to settle..."
    sleep 2
}

# Environment selection (may be passed as the first argument)
if [ -n "$1" ] && [[ "$1" =~ ^(prod|preprod|demo|PROD|PREPROD|DEMO|production|pre-production)$ ]]; then
    # ENV passed as the first argument
    select_environment "$1"
    # Arguments are shifted — use environment variables or arguments
    LOGIN="${2:-${treasury_BOX_LOGIN:-}}"
    COMPANY_ID="${3:-${treasury_BOX_COMPANY_ID:-}}"
    PASSWORD="${4:-${treasury_BOX_PASSWORD:-}}"
else
    # ENV not passed; pick interactively, arguments are not shifted
    select_environment ""
    LOGIN="${1:-${treasury_BOX_LOGIN:-}}"
    COMPANY_ID="${2:-${treasury_BOX_COMPANY_ID:-}}"
    PASSWORD="${3:-${treasury_BOX_PASSWORD:-}}"
fi

# Check required parameters
if [ -z "$LOGIN" ] || [ "$LOGIN" = "YOUR_LOGIN_HERE" ]; then
    print_error "LOGIN is not set. Pass it as an argument or an environment variable treasury_BOX_LOGIN"
    exit 1
fi

if [ -z "$COMPANY_ID" ] || [ "$COMPANY_ID" = "YOUR_COMPANY_ID_HERE" ]; then
    print_error "COMPANY_ID is not set. Pass it as an argument or an environment variable treasury_BOX_COMPANY_ID"
    exit 1
fi

# PASSWORD is optional (used only to request a new OTP automatically)

# URL setup (called after port-forward is set up for PROD)
setup_urls() {
    if [ "$USE_PORT_FORWARD" = "true" ] && [ -n "$AUTH_LOCAL_PORT" ]; then
        # For PROD with port-forward use localhost
        # IMPORTANT: port-forward bypasses ingress, so ingress prefixes are stripped from paths
        WEB_PORT="${WEB_LOCAL_PORT:-$AUTH_LOCAL_PORT}"
        AUTH_PORT="$AUTH_LOCAL_PORT"
        
        # Paths without ingress prefixes (straight to the pod)
        OTP_API_URL="http://localhost:${WEB_PORT}/otp/login/${LOGIN}?page=0&size=20"
        AUTH_URL="http://localhost:${AUTH_PORT}/oauth2/token"
        REQUEST_OTP_URL="http://localhost:${AUTH_PORT}/login/otp"
    else
        # Other environments use regular URLs through ingress
        OTP_API_URL="https://${WEB_DOMAIN}/api/v0/treasury-otp/otp/login/${LOGIN}?page=0&size=20"
        AUTH_URL="https://${AUTH_DOMAIN}/api/v0/treasury-auth-provider/oauth2/token"
        REQUEST_OTP_URL="https://${AUTH_DOMAIN}/api/v0/treasury-auth-provider/login/otp"
    fi
}

# Initialize URLs (overridden after port-forward for PROD)
OTP_API_URL=""
AUTH_URL=""
REQUEST_OTP_URL=""

# Request a new OTP code
request_new_otp() {
    local login="$1"
    local password="$2"
    
    if [ -z "$password" ]; then
        return 1
    fi
    
    print_header "Request a new OTP code"
    print_info "Sending a request to generate a new OTP code..."
    
    REQUEST_RESPONSE=$(curl -s -X POST "$REQUEST_OTP_URL" \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        -d "{\"login\":\"$login\",\"password\":\"$password\"}")
    
    if [ -z "$REQUEST_RESPONSE" ]; then
        print_error "Empty response from the server when requesting OTP"
        return 1
    fi
    
    # Error check
    if echo "$REQUEST_RESPONSE" | grep -q '"error"'; then
        print_error "Error requesting a new OTP:"
        if [ "$HAS_JQ" = true ]; then
            ERROR_DESC=$(echo "$REQUEST_RESPONSE" | jq -r '.error_description // .error // .message')
            echo -e "  ${RED}Description:${NC} $ERROR_DESC"
            echo "$REQUEST_RESPONSE" | jq .
        else
            echo "$REQUEST_RESPONSE"
        fi
        return 1
    fi
    
    # Check success
    if [ "$HAS_JQ" = true ]; then
        # Confirm the response is an object (not an array) and try to extract message
        if echo "$REQUEST_RESPONSE" | jq -e 'type == "object"' > /dev/null 2>&1; then
            SUCCESS_MESSAGE=$(echo "$REQUEST_RESPONSE" | jq -r 'if .message then .message else "OK" end' 2>/dev/null)
            if [ -n "$SUCCESS_MESSAGE" ] && [ "$SUCCESS_MESSAGE" != "null" ] && [ "$SUCCESS_MESSAGE" != "OK" ]; then
                print_success "New OTP code requested: $SUCCESS_MESSAGE"
            else
                print_success "New OTP code requested successfully"
            fi
        else
            print_success "New OTP code requested successfully"
        fi
    else
        print_success "New OTP code requested"
    fi
    
    # Short delay so the OTP code can appear in the database
    print_info "Waiting for the code to appear in the system (3 seconds)..."
    sleep 3
    
    return 0
}

# Check that jq is available
if ! command -v jq &> /dev/null; then
    print_warning "jq is not installed. Install for correct operation: apt-get install jq"
    HAS_JQ=false
else
    HAS_JQ=true
fi

# Set up port-forward for PROD (when needed)
if [ "$USE_PORT_FORWARD" = "true" ]; then
    setup_prod_port_forwards
fi

# Set URLs after port-forward
setup_urls

# Start
clear
print_header "OTP authorization"
echo -e "${BLUE}Environment:${NC} ${ENV^^}"
if [ "$USE_PORT_FORWARD" = "true" ]; then
    echo -e "${BLUE}Mode:${NC} Port-forward (localhost)"
    echo -e "${BLUE}Login:${NC} $LOGIN"
    echo -e "${BLUE}Company ID:${NC} $COMPANY_ID"
    echo -e "${BLUE}Password:${NC} ******** (will be used to request a new OTP automatically when needed)"
    echo ""
    echo -e "${CYAN}URLs via port-forward:${NC}"
    echo -e "  • Auth: http://localhost:${AUTH_LOCAL_PORT}"
    if [ -n "$WEB_LOCAL_PORT" ] && [ "$WEB_LOCAL_PORT" != "$AUTH_LOCAL_PORT" ]; then
        echo -e "  • Web:  http://localhost:${WEB_LOCAL_PORT}"
    else
        echo -e "  • Web:  http://localhost:${AUTH_LOCAL_PORT} (uses the auth service)"
    fi
else
    echo -e "${BLUE}Login:${NC} $LOGIN"
    echo -e "${BLUE}Company ID:${NC} $COMPANY_ID"
    echo -e "${BLUE}Password:${NC} ******** (will be used to request a new OTP automatically when needed)"
    echo ""
    echo -e "${CYAN}URLs in use:${NC}"
    echo -e "  • Auth: https://${AUTH_DOMAIN}"
    echo -e "  • Web:  https://${WEB_DOMAIN}"
fi
echo ""

# Check that URLs are set
if [ -z "$OTP_API_URL" ] || [ -z "$AUTH_URL" ] || [ -z "$REQUEST_OTP_URL" ]; then
    print_error "URLs were not configured. Check the configuration."
    exit 1
fi

# Step 1: Fetch the OTP code list
print_header "Step 1: Fetch the OTP code list"
print_info "Fetching the OTP code list..."

# Debug info before the request
print_info "URL for the request: $OTP_API_URL"

if [ "$USE_PORT_FORWARD" = "true" ]; then
    echo ""
    print_info "Checking port-forward process status..."
    
    # Check auth port-forward
    if [ -n "$AUTH_PORT_FORWARD_PID" ] && [[ "$AUTH_PORT_FORWARD_PID" =~ ^[0-9]+$ ]]; then
        if ps -p $AUTH_PORT_FORWARD_PID > /dev/null 2>&1; then
            print_success "Port-forward for auth is active (PID: $AUTH_PORT_FORWARD_PID, port: $AUTH_LOCAL_PORT)"
        else
            print_error "Port-forward for auth is NOT working (PID: $AUTH_PORT_FORWARD_PID not found)"
        fi
    elif [ -n "$AUTH_PORT_FORWARD_PID" ]; then
        print_warning "Port-forward for auth: invalid PID (must be a number, got: $AUTH_PORT_FORWARD_PID)"
    fi
    
    # Check web port-forward
    if [ -n "$WEB_PORT_FORWARD_PID" ] && [[ "$WEB_PORT_FORWARD_PID" =~ ^[0-9]+$ ]]; then
        if ps -p $WEB_PORT_FORWARD_PID > /dev/null 2>&1; then
            print_success "Port-forward for web is active (PID: $WEB_PORT_FORWARD_PID, port: $WEB_LOCAL_PORT)"
        else
            print_warning "Port-forward for web is NOT working (PID: $WEB_PORT_FORWARD_PID not found)"
        fi
    elif [ -n "$WEB_PORT_FORWARD_PID" ]; then
        print_warning "Port-forward for web: invalid PID (must be a number, got: $WEB_PORT_FORWARD_PID)"
    fi
    
    # Port availability test
    print_info "Checking port availability..."
    if command -v nc &> /dev/null || command -v netcat &> /dev/null; then
        if nc -z localhost ${WEB_LOCAL_PORT:-8082} 2>/dev/null; then
            print_success "Port ${WEB_LOCAL_PORT:-8082} is available"
        else
            print_error "Port ${WEB_LOCAL_PORT:-8082} is NOT available"
        fi
    fi
    echo ""
fi

print_info "Sending the request..."
OTP_LIST_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$OTP_API_URL" -H 'accept: */*')

# Extract the HTTP status and response body
HTTP_CODE=$(echo "$OTP_LIST_RESPONSE" | tail -n 1)
OTP_LIST_RESPONSE=$(echo "$OTP_LIST_RESPONSE" | sed '$d')

print_info "HTTP status code: $HTTP_CODE"

if [ -z "$OTP_LIST_RESPONSE" ]; then
    print_error "Empty response from the OTP API"
    print_info "HTTP status: $HTTP_CODE"
    print_info "URL: $OTP_API_URL"
    if [ "$USE_PORT_FORWARD" = "true" ]; then
        print_info "Check port-forward processes:"
        print_info "  ps aux | grep 'port-forward'"
        print_info "  kubectl -n $K8S_NAMESPACE get svc | grep otp"
    fi
    exit 1
fi

# Print the first response lines for debugging
print_info "=== Start of the API response ==="
echo "$OTP_LIST_RESPONSE" | head -5
echo "..."
echo ""

# Check the response for an error
if echo "$OTP_LIST_RESPONSE" | grep -q '"error"'; then
    print_error "Error fetching the OTP code list:"
    if [ "$HAS_JQ" = true ]; then
        echo "$OTP_LIST_RESPONSE" | jq .
    else
        echo "$OTP_LIST_RESPONSE"
    fi
    exit 1
fi

print_success "OTP code list received"

# Step 2: Extract the newest valid OTP code
print_header "Step 2: Determine the newest valid OTP code"

if [ "$HAS_JQ" = true ]; then
    TOTAL_CODES=$(echo "$OTP_LIST_RESPONSE" | jq -r '.totalElements // 0' 2>/dev/null || echo "0")
    print_info "OTP codes found: $TOTAL_CODES"
    echo ""
    
    # Get current time in ISO 8601 format
    CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
    
    # Look up the newest non-VERIFIED code that has not expired
    # Filter: status != "VERIFIED" and expireAt > current time
    LATEST_VALID=$(echo "$OTP_LIST_RESPONSE" | jq -r --arg now "$CURRENT_TIME" '
        [.content[] | 
        select(.status != "VERIFIED") |
        select(.expireAt > $now)] |
        sort_by(.expireAt) | reverse | .[0]' 2>/dev/null || echo "null")
    
    if [ "$LATEST_VALID" != "null" ] && [ -n "$LATEST_VALID" ]; then
        LATEST_CODE=$(echo "$LATEST_VALID" | jq -r '.code | split(": ")[1]')
        LATEST_EXPIRE=$(echo "$LATEST_VALID" | jq -r '.expireAt')
        LATEST_STATUS=$(echo "$LATEST_VALID" | jq -r '.status')
        
        print_success "Valid OTP code found"
        echo -e "  ${BLUE}Code:${NC} $LATEST_CODE"
        echo -e "  ${BLUE}Expires:${NC} $LATEST_EXPIRE"
        echo -e "  ${BLUE}Status:${NC} $LATEST_STATUS"
    else
        # If no unused code is found
        print_warning "No valid unused codes found."
        echo ""
        
        # Show all codes for debugging
        print_info "All available OTP codes:"
        echo "$OTP_LIST_RESPONSE" | jq -r '.content[] | "  • Code: \(.code | split(": ")[1]) | Status: \(.status) | Expires: \(.expireAt)"' 2>/dev/null || print_warning "Failed to parse the code list"
        echo ""
        
        # If a password is provided, request a new OTP
        if [ -n "$PASSWORD" ]; then
            print_info "Password provided. Requesting a new OTP code..."
            echo ""
            
            if request_new_otp "$LOGIN" "$PASSWORD"; then
                # Fetch the OTP code list again
                print_info "Fetching the updated OTP code list..."
                OTP_LIST_RESPONSE=$(curl -s -X GET "$OTP_API_URL" -H 'accept: */*')
                
                # Try to find the new code
                LATEST_VALID=$(echo "$OTP_LIST_RESPONSE" | jq -r --arg now "$CURRENT_TIME" '
                    [.content[] | 
                    select(.status != "VERIFIED") |
                    select(.expireAt > $now)] |
                    sort_by(.expireAt) | reverse | .[0]'
                )
                
                if [ "$LATEST_VALID" != "null" ] && [ -n "$LATEST_VALID" ]; then
                    LATEST_CODE=$(echo "$LATEST_VALID" | jq -r '.code | split(": ")[1]')
                    LATEST_EXPIRE=$(echo "$LATEST_VALID" | jq -r '.expireAt')
                    LATEST_STATUS=$(echo "$LATEST_VALID" | jq -r '.status')
                    
                    print_success "New valid OTP code found!"
                    echo -e "  ${BLUE}Code:${NC} $LATEST_CODE"
                    echo -e "  ${BLUE}Expires:${NC} $LATEST_EXPIRE"
                    echo -e "  ${BLUE}Status:${NC} $LATEST_STATUS"
                else
                    # If still not found, take the newest
                    print_warning "The new code is not in the list yet. Using the newest by time..."
                    LATEST_CODE=$(echo "$OTP_LIST_RESPONSE" | jq -r '[.content[]] | sort_by(.expireAt) | reverse | .[0] | .code | split(": ")[1]')
                    LATEST_EXPIRE=$(echo "$OTP_LIST_RESPONSE" | jq -r '[.content[]] | sort_by(.expireAt) | reverse | .[0] | .expireAt')
                    LATEST_STATUS=$(echo "$OTP_LIST_RESPONSE" | jq -r '[.content[]] | sort_by(.expireAt) | reverse | .[0] | .status')
                    
                    if [ "$LATEST_CODE" != "null" ] && [ -n "$LATEST_CODE" ]; then
                        echo -e "  ${BLUE}Code:${NC} $LATEST_CODE"
                        echo -e "  ${BLUE}Expires:${NC} $LATEST_EXPIRE"
                        echo -e "  ${BLUE}Status:${NC} $LATEST_STATUS"
                    fi
                fi
            else
                print_error "Failed to request a new OTP code"
                echo ""
                print_info "Try:"
                echo "  1. Check that the password is correct"
                echo "  2. Request a new OTP code via the UI"
                exit 1
            fi
        else
            # If no password is provided, use the newest code (even if VERIFIED)
            print_warning "No password provided. Trying the newest code by time..."
            echo ""
            
            LATEST_CODE=$(echo "$OTP_LIST_RESPONSE" | jq -r '[.content[]] | sort_by(.expireAt) | reverse | .[0] | .code | split(": ")[1]')
            LATEST_EXPIRE=$(echo "$OTP_LIST_RESPONSE" | jq -r '[.content[]] | sort_by(.expireAt) | reverse | .[0] | .expireAt')
            LATEST_STATUS=$(echo "$OTP_LIST_RESPONSE" | jq -r '[.content[]] | sort_by(.expireAt) | reverse | .[0] | .status')
            
            if [ "$LATEST_CODE" != "null" ] && [ -n "$LATEST_CODE" ]; then
                print_warning "Using the newest code (it may already have been used):"
                echo -e "  ${BLUE}Code:${NC} $LATEST_CODE"
                echo -e "  ${BLUE}Expires:${NC} $LATEST_EXPIRE"
                echo -e "  ${YELLOW}Status:${NC} $LATEST_STATUS"
                echo ""
                print_info "💡 To request a new OTP automatically, pass the password as the third argument:"
                echo "   ./auth_treasury_box_api.sh $LOGIN $COMPANY_ID PASSWORD"
            else
                print_error "Failed to determine the OTP code from the response"
                echo "$OTP_LIST_RESPONSE" | jq .
                exit 1
            fi
        fi
    fi
else
    # Fallback without jq
    print_warning "Using simplified parsing (installing jq is recommended)"
    LATEST_CODE=$(echo "$OTP_LIST_RESPONSE" | grep -o '"code":"[^"]*"' | tail -1 | sed 's/.*: //; s/"$//')
    
    if [ -z "$LATEST_CODE" ]; then
        print_error "Failed to extract the OTP code"
        exit 1
    fi
    
    print_success "OTP code extracted: $LATEST_CODE"
    print_warning "Without jq the code status cannot be checked. Install jq for an exact check."
fi

# Step 3: Authorize with the OTP code
print_header "Step 3: Authorize with the OTP code"
print_info "Sending a token request..."

TOKEN_RESPONSE=$(curl -s -X POST "$AUTH_URL" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H 'Accept: application/json' \
  --data-urlencode "login=$LOGIN" \
  --data-urlencode "otp=$LATEST_CODE" \
  --data-urlencode "companyId=$COMPANY_ID" \
  --data-urlencode "grant_type=otp")

# Check the response
if [ -z "$TOKEN_RESPONSE" ]; then
    print_error "Empty response from the auth server"
    exit 1
fi

# Error check
if echo "$TOKEN_RESPONSE" | grep -q '"error"'; then
    print_error "Authorization error:"
    if [ "$HAS_JQ" = true ]; then
        ERROR_DESC=$(echo "$TOKEN_RESPONSE" | jq -r '.error_description // .error')
        ERROR_CODE=$(echo "$TOKEN_RESPONSE" | jq -r '.error')
        echo -e "  ${RED}Error code:${NC} $ERROR_CODE"
        echo -e "  ${RED}Description:${NC} $ERROR_DESC"
        echo ""
        
        # Additional information about the used code
        if [ "$LATEST_STATUS" = "VERIFIED" ]; then
            print_warning "The OTP code status is VERIFIED (already used)"
        fi
        
        # Check expiry time
        if [ -n "$LATEST_EXPIRE" ]; then
            CURRENT_TIME_EPOCH=$(date -u +%s)
            EXPIRE_TIME_EPOCH=$(date -u -d "$LATEST_EXPIRE" +%s 2>/dev/null || echo "0")
            if [ "$EXPIRE_TIME_EPOCH" -lt "$CURRENT_TIME_EPOCH" ]; then
                print_warning "OTP code expiry time: $LATEST_EXPIRE (may have expired)"
            fi
        fi
    else
        echo "$TOKEN_RESPONSE"
    fi
    echo ""
    print_warning "Possible causes:"
    echo "  • OTP code already used (status VERIFIED)"
    echo "  • OTP code expired (expireAt is in the past)"
    echo "  • Invalid login or companyId"
    echo ""
    print_info "💡 Fix: request a new OTP code via the UI/API"
    print_info "   Then run the script again to obtain a fresh code"
    exit 1
fi

# Check that a token is present
if ! echo "$TOKEN_RESPONSE" | grep -q '"access_token"'; then
    print_error "The response has no access_token"
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


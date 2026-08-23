#!/bin/bash

# Fetch logs from Kubernetes pods
# Usage:
#   ./kube-logs.sh                    # Interactive mode
#   ./kube-logs.sh -n <namespace>     # Specify namespace
#
# Environment variables (optional):
#   K8S_DEFAULT_NAMESPACE - default namespace (default: default)

set -e

# Colors for readable output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default namespace (override via environment variable)
DEFAULT_NAMESPACE="${K8S_DEFAULT_NAMESPACE:-default}"
NAMESPACE="${DEFAULT_NAMESPACE}"

# Print help
show_help() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Kubernetes Logs Extractor${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Usage:"
    echo "  $0                    # Interactive mode"
    echo "  $0 -n <namespace>     # Specify namespace"
    echo "  $0 help               # Show this help"
    echo ""
    echo "The script can:"
    echo "  - Select a namespace (default: ${DEFAULT_NAMESPACE})"
    echo "  - Select a service from deployments and statefulsets"
    echo "  - Select a time range for logs"
    echo "  - Detect the date format from logs automatically"
    echo "  - Save logs to a .log file"
    echo ""
}

# Check that kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl not found in PATH${NC}"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Error: Could not connect to the cluster${NC}"
        exit 1
    fi
}

# Check whether kubectl supports --until-time
check_until_time_support() {
    # Check whether kubectl supports the --until-time flag
    if kubectl logs --help 2>&1 | grep -q "\-\-until-time"; then
        return 0  # Supported
    else
        return 1  # Not supported
    fi
}

# Check that the namespace exists
check_namespace() {
    local ns="$1"
    if ! kubectl get namespace "$ns" &> /dev/null; then
        echo -e "${RED}Error: Namespace '${ns}' not found${NC}"
        return 1
    fi
    return 0
}

# List services (deployments and statefulsets)
get_services() {
    local ns="$1"
    local services=()
    
    # Collect deployments
    local deployments=$(kubectl -n "$ns" get deployments -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    for deploy in $deployments; do
        services+=("deployment:$deploy")
    done
    
    # Collect statefulsets
    local statefulsets=$(kubectl -n "$ns" get statefulsets -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    for sts in $statefulsets; do
        services+=("statefulset:$sts")
    done
    
    # Emit the array
    printf '%s\n' "${services[@]}"
}

# Get pods for a service
get_pods_for_service() {
    local ns="$1"
    local service_type="$2"
    local service_name="$3"
    
    if [ "$service_type" = "deployment" ]; then
        # Try to get pods via the deployment selector
        local pods=""
        
        # Use jsonpath to get all key=value pairs
        local selector_pairs=$(kubectl -n "$ns" get deployment "$service_name" -o jsonpath='{.spec.selector.matchLabels}' 2>/dev/null)
        
        if [ -n "$selector_pairs" ] && [ "$selector_pairs" != "{}" ]; then
            # Convert JSON to selector form (key1=value1,key2=value2)
            local selector=$(echo "$selector_pairs" | grep -o '"[^"]*":"[^"]*"' | \
                sed 's/"\([^"]*\)":"\([^"]*\)"/\1=\2/' | tr '\n' ',' | sed 's/,$//')
            
            if [ -n "$selector" ]; then
                pods=$(kubectl -n "$ns" get pods --selector="$selector" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
            fi
        fi
        
        # If the selector path failed, try fallback methods
        if [ -z "$pods" ] || [ -z "$(echo "$pods" | tr -d ' ')" ]; then
            pods=$(kubectl -n "$ns" get pods -l app="$service_name" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || \
                   kubectl -n "$ns" get pods -l app.kubernetes.io/name="$service_name" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || \
                   kubectl -n "$ns" get pods | grep "$service_name" | awk '{print $1}' || echo "")
        fi
        
        echo "$pods"
    elif [ "$service_type" = "statefulset" ]; then
        # StatefulSet pods are named <statefulset-name>-<ordinal>
        local pods=""
        
        # Try to get the selector
        local selector_pairs=$(kubectl -n "$ns" get statefulset "$service_name" -o jsonpath='{.spec.selector.matchLabels}' 2>/dev/null)
        
        if [ -n "$selector_pairs" ] && [ "$selector_pairs" != "{}" ]; then
            local selector=$(echo "$selector_pairs" | grep -o '"[^"]*":"[^"]*"' | \
                sed 's/"\([^"]*\)":"\([^"]*\)"/\1=\2/' | tr '\n' ',' | sed 's/,$//')
            
            if [ -n "$selector" ]; then
                pods=$(kubectl -n "$ns" get pods --selector="$selector" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
            fi
        fi
        
        # If the selector path failed, try fallback methods
        if [ -z "$pods" ] || [ -z "$(echo "$pods" | tr -d ' ')" ]; then
            # StatefulSet pods usually start with the statefulset name
            pods=$(kubectl -n "$ns" get pods | grep "^${service_name}-" | awk '{print $1}' || \
                   kubectl -n "$ns" get pods -l app.kubernetes.io/name="$service_name" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || \
                   kubectl -n "$ns" get pods | grep "$service_name" | awk '{print $1}' || echo "")
        fi
        
        echo "$pods"
    else
        echo ""
    fi
}

# Get containers in a pod (excluding sidecars)
get_application_containers() {
    local ns="$1"
    local pod="$2"
    
    # Collect all containers
    local containers=$(kubectl -n "$ns" get pod "$pod" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || echo "")
    
    # Filter sidecar containers
    local app_containers=()
    for container in $containers; do
        # Exclude known sidecar containers
        if [[ ! "$container" =~ ^(istio-proxy|sidecar|envoy|linkerd-proxy|vault-agent)$ ]]; then
            app_containers+=("$container")
        fi
    done
    
    # If none found, take the first container or "application"
    if [ ${#app_containers[@]} -eq 0 ]; then
        # Try to find a container named "application"
        if echo "$containers" | grep -q "application"; then
            echo "application"
        else
            # Take the first container
            echo "$containers" | awk '{print $1}'
        fi
    else
        # When several match, prefer "application"
        if printf '%s\n' "${app_containers[@]}" | grep -q "^application$"; then
            echo "application"
        else
            printf '%s\n' "${app_containers[@]}" | head -1
        fi
    fi
}

# Detect the date format from logs
detect_date_format() {
    local ns="$1"
    local pod="$2"
    local container="$3"
    
    # Fetch the last 50 log lines
    local sample_logs=$(kubectl -n "$ns" logs "$pod" -c "$container" --tail=50 2>/dev/null || echo "")
    
    if [ -z "$sample_logs" ]; then
        echo ""
        return
    fi
    
    # Look for various date formats in the logs
    # RFC3339: 2025-12-18T13:41:05.741+03:00 or 2025-12-18T13:41:05Z
    if echo "$sample_logs" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}'; then
        echo "rfc3339"
        return
    fi
    
    # ISO 8601: 2025-12-18 13:41:05
    if echo "$sample_logs" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}'; then
        echo "iso8601"
        return
    fi
    
    # Unix timestamp
    if echo "$sample_logs" | grep -qE '^[0-9]{10}\.[0-9]+'; then
        echo "unix"
        return
    fi
    
    echo "unknown"
}

# Detect the timezone from logs
detect_timezone() {
    local ns="$1"
    local pod="$2"
    local container="$3"
    
    # Fetch the last 50 log lines (more lines to find a date with a timezone)
    local sample_logs=$(kubectl -n "$ns" logs "$pod" -c "$container" --tail=50 2>/dev/null || echo "")
    
    if [ -z "$sample_logs" ]; then
        echo ""
        return
    fi
    
    # Look for a timezone in various formats:
    # 1. With milliseconds: 2025-12-18T13:41:05.741+03:00
    local timezone=$(echo "$sample_logs" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?[+\-][0-9]{2}:[0-9]{2}' | head -1 | grep -oE '[+\-][0-9]{2}:[0-9]{2}$' | head -1)
    
    if [ -n "$timezone" ]; then
        echo "$timezone"
        return
    fi
    
    # 2. Without milliseconds: 2025-12-18T13:41:05+03:00
    timezone=$(echo "$sample_logs" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+\-][0-9]{2}:[0-9]{2}' | head -1 | grep -oE '[+\-][0-9]{2}:[0-9]{2}$' | head -1)
    
    if [ -n "$timezone" ]; then
        echo "$timezone"
        return
    fi
    
    # 3. If not found, check for Z (UTC)
    if echo "$sample_logs" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?Z[^a-zA-Z]'; then
        echo "Z"
        return
    fi
    
    # 4. If still not found, try any date and inspect the format
    local first_date=$(echo "$sample_logs" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
    if [ -n "$first_date" ]; then
        # Check whether anything follows the date (milliseconds or timezone)
        local date_with_tz=$(echo "$sample_logs" | grep -oE "${first_date}[\.\+\-Z].*" | head -1)
        if [[ "$date_with_tz" =~ [+\-][0-9]{2}:[0-9]{2} ]]; then
            timezone=$(echo "$date_with_tz" | grep -oE '[+\-][0-9]{2}:[0-9]{2}' | head -1)
            if [ -n "$timezone" ]; then
                echo "$timezone"
                return
            fi
        fi
    fi
    
    echo ""
}

# Get a sample date from logs
get_date_example() {
    local ns="$1"
    local pod="$2"
    local container="$3"
    
    # Fetch the last 10 log lines
    local sample_logs=$(kubectl -n "$ns" logs "$pod" -c "$container" --tail=10 2>/dev/null || echo "")
    
    if [ -z "$sample_logs" ]; then
        echo ""
        return
    fi
    
    # Find the first RFC3339 date (with or without timezone)
    local date_example=$(echo "$sample_logs" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?([\+\-][0-9]{2}:[0-9]{2}|Z)?' | head -1)
    
    if [ -n "$date_example" ]; then
        echo "$date_example"
        return
    fi
    
    # If RFC3339 is not found, try ISO8601
    date_example=$(echo "$sample_logs" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
    
    if [ -n "$date_example" ]; then
        echo "$date_example"
        return
    fi
    
    echo ""
}

# Parse a date in the log format
parse_log_date() {
    local date_str="$1"
    local format="$2"
    
    case "$format" in
        "rfc3339")
            # Try different RFC3339 variants
            if [[ "$date_str" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}) ]]; then
                echo "${BASH_REMATCH[1]}"
            else
                echo "$date_str"
            fi
            ;;
        "iso8601")
            echo "$date_str" | sed 's/ .*//'
            ;;
        *)
            echo "$date_str"
            ;;
    esac
}

# Fetch logs
get_logs() {
    local ns="$1"
    local container="$2"
    local time_filter="$3"
    local output_file="$4"
    shift 4
    local pods=("$@")
    
    # Require an output file path
    if [ -z "$output_file" ]; then
        echo -e "${RED}Error: Output file path is not set${NC}" >&2
        return 1
    fi
    
    local temp_file=$(mktemp)
    
    echo -e "${CYAN}Collecting logs...${NC}"
    
    # Detect timezone from the first pod when time is given without a timezone
    local detected_timezone=""
    if [ ${#pods[@]} -gt 0 ] && [ -n "${pods[0]}" ]; then
        local first_pod="${pods[0]}"
        # Check whether time_filter has a time without a timezone
        if [[ "$time_filter" == *"--since-time="* ]] && [[ ! "$time_filter" =~ [\+\-][0-9]{2}:[0-9]{2} ]] && [[ ! "$time_filter" =~ Z[^a-zA-Z] ]] && [[ ! "$time_filter" =~ Z$ ]]; then
            detected_timezone=$(detect_timezone "$ns" "$first_pod" "$container")
            echo "  [DEBUG] Timezone detected from logs: '${detected_timezone}'" >&2
            if [ -z "$detected_timezone" ]; then
                # If detection failed, check whether the pod has any logs
                local test_logs=$(kubectl -n "$ns" logs "$first_pod" -c "$container" --tail=5 2>/dev/null || echo "")
                if [ -z "$test_logs" ]; then
                    echo "  [DEBUG] Pod logs are empty, defaulting to UTC" >&2
                    detected_timezone="Z"
                else
                    echo "  [DEBUG] Logs exist but timezone is unknown. Trying a manual search..." >&2
                    # Try to find any date in the logs
                    local sample_date=$(echo "$test_logs" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
                    if [ -n "$sample_date" ]; then
                        echo "  [DEBUG] Date found in logs: $sample_date" >&2
                        # Try to find the full line that contains the date
                        local full_date_line=$(echo "$test_logs" | grep -m1 "$sample_date")
                        echo "  [DEBUG] Line with date: ${full_date_line:0:100}..." >&2
                    fi
                    # Fall back to UTC and warn
                    detected_timezone="Z"
                fi
            fi
        fi
    fi
    
    local pod_count=0
    for pod in "${pods[@]}"; do
        if [ -z "$pod" ]; then
            continue
        fi
        
        echo -e "${BLUE}Processing pod: ${pod}${NC}"
        
        # Build the kubectl logs command
        local log_cmd="kubectl -n $ns logs $pod -c $container --prefix=true"
        
        # Check whether to filter by end_time (when --until-time is unsupported)
        local end_time=""
        local actual_time_filter="$time_filter"
        
        if [[ "$time_filter" == *"|END_TIME:"* ]]; then
            # Extract end_time and actual_time_filter
            end_time=$(echo "$time_filter" | sed 's/.*|END_TIME://')
            actual_time_filter=$(echo "$time_filter" | sed 's/|END_TIME:.*//')
        fi
        
        # When time has no timezone and one was detected, append it
        if [ -n "$detected_timezone" ] && [[ "$actual_time_filter" == *"--since-time="* ]]; then
            # Extract the time value from --since-time=...
            local time_value=$(echo "$actual_time_filter" | sed 's/.*--since-time=//' | sed 's/|.*//')
            # Check whether the time already has a timezone (Z or +/-HH:MM)
            if [[ ! "$time_value" =~ [\+\-][0-9]{2}:[0-9]{2}$ ]] && [[ ! "$time_value" =~ Z$ ]]; then
                # Append the timezone to the time
                actual_time_filter=$(echo "$actual_time_filter" | sed "s/--since-time=${time_value}/--since-time=${time_value}${detected_timezone}/")
                echo "  [DEBUG] Timezone from logs appended: ${detected_timezone}" >&2
            fi
        fi
        
        # Add the time filter
        if [ -n "$actual_time_filter" ] && [ "$actual_time_filter" != "" ]; then
            log_cmd="$log_cmd $actual_time_filter"
        fi
        
        # Fetch logs and prepend a header
        {
            echo "=== Pod: $pod ==="
            local log_output
            log_output=$(eval "$log_cmd" 2>&1)
            local log_exit_code=$?
            
            # Debug information (temporary)
            if [ -n "$end_time" ]; then
                echo "  [DEBUG] Command: $log_cmd" >&2
                echo "  [DEBUG] Exit code: $log_exit_code" >&2
                echo "  [DEBUG] Output size: ${#log_output} bytes" >&2
                if [ ${#log_output} -lt 200 ]; then
                    echo "  [DEBUG] Content: $log_output" >&2
                fi
            fi
            
            if [ $log_exit_code -eq 0 ]; then
                if [ -n "$log_output" ]; then
                    # Filter by end_time when needed
                    if [ -n "$end_time" ]; then
                        # Detect the date format in the logs automatically
                        local date_format=$(detect_date_format "$ns" "$pod" "$container")
                        
                        # Convert end_time for comparison (drop Z and timezone, keep date and time)
                        local end_time_compare=$(echo "$end_time" | sed 's/Z$//' | sed 's/[+-][0-9][0-9]:[0-9][0-9]$//' | sed 's/\.[0-9]*$//')
                        
                        # Create a temp file for filtered logs
                        local filtered_output=""
                        local has_data=0
                        
                        # Keep log lines whose date is less than or equal to end_time
                        while IFS= read -r line; do
                            # Always keep headers and empty lines
                            if [[ "$line" == "=== Pod:"* ]] || [[ -z "$line" ]]; then
                                filtered_output="${filtered_output}${line}"$'\n'
                                has_data=1
                                continue
                            fi
                            
                            # Extract the date from the line based on the detected format
                            local line_date=""
                            local line_date_compare=""
                            
                            case "$date_format" in
                                "rfc3339")
                                    # RFC3339: 2025-12-18T13:41:05.741+03:00 or 2025-12-18T13:41:05Z
                                    line_date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
                                    if [ -n "$line_date" ]; then
                                        # Strip milliseconds and timezone for comparison
                                        line_date_compare=$(echo "$line_date" | sed 's/\.[0-9]*$//' | sed 's/[+-][0-9][0-9]:[0-9][0-9]$//')
                                    fi
                                    ;;
                                "iso8601")
                                    # ISO 8601: 2025-12-18 13:41:05
                                    line_date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
                                    if [ -n "$line_date" ]; then
                                        # Convert to comparison form (replace space with T)
                                        line_date_compare=$(echo "$line_date" | sed 's/ /T/' | sed 's/\.[0-9]*$//')
                                    fi
                                    ;;
                                *)
                                    # Unknown or undetected format — try RFC3339
                                    line_date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
                                    if [ -z "$line_date" ]; then
                                        # Try ISO8601
                                        line_date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
                                        if [ -n "$line_date" ]; then
                                            line_date_compare=$(echo "$line_date" | sed 's/ /T/' | sed 's/\.[0-9]*$//')
                                        fi
                                    else
                                        line_date_compare=$(echo "$line_date" | sed 's/\.[0-9]*$//' | sed 's/[+-][0-9][0-9]:[0-9][0-9]$//')
                                    fi
                                    ;;
                            esac
                            
                            if [ -n "$line_date_compare" ]; then
                                # Compare dates (string compare works for ISO8601)
                                # Use [[ ]] for the comparison: when line_date <= end_time
                                if [[ "$line_date_compare" < "$end_time_compare" ]] || [[ "$line_date_compare" == "$end_time_compare" ]]; then
                                    filtered_output="${filtered_output}${line}"$'\n'
                                    has_data=1
                                fi
                            else
                                # If the date could not be extracted, keep the line
                                # (may be service text or a line in another format)
                                filtered_output="${filtered_output}${line}"$'\n'
                                has_data=1
                            fi
                        done <<< "$log_output"
                        
                        # Emit the filtered logs
                        if [ $has_data -eq 1 ]; then
                            echo -n "$filtered_output"
                        else
                            # When filtering removed everything but source data existed
                            # Print the first few lines for debugging
                            local first_lines=$(echo "$log_output" | head -5)
                            echo "⚠ Warning: All lines were filtered out by end_time: $end_time_compare"
                            echo "  First source log lines for debugging:"
                            echo "$first_lines" | sed 's/^/  /'
                            echo "  (Check the date format in the logs)"
                        fi
                    else
                        echo "$log_output"
                    fi
                else
                    # Empty logs — print a more informative message
                    if [ -n "$end_time" ]; then
                        echo "Logs are empty or missing for this time range"
                        echo "  Check:"
                        echo "  - Time format in --since-time"
                        echo "  - Whether logs exist in the given time range"
                        echo "  - Pod and container availability"
                    else
                        echo "Logs are empty or missing for this time range"
                    fi
                fi
            else
                echo "Error fetching logs: $log_output"
                echo "  Command: $log_cmd"
            fi
            echo ""
        } >> "$temp_file"
        
        ((pod_count++))
    done
    
    # Check whether the temp file has data
    if [ ! -f "$temp_file" ]; then
        echo -e "${RED}Error: Temp file was not created${NC}"
        return 1
    fi
    
    # Check file size for debugging
    local file_size=0
    if [ -f "$temp_file" ]; then
        file_size=$(wc -c < "$temp_file" 2>/dev/null || echo "0")
    fi
    
    # Save the file in the current directory (pwd)
    # The file is always saved in the directory from which the script was started
    if mv "$temp_file" "$output_file" 2>/dev/null; then
        # Resolve the full absolute path
        local abs_path="$(pwd)/${output_file}"
        
        echo ""
        if [ -s "$output_file" ]; then
            echo -e "${GREEN}✓ Logs saved successfully!${NC}"
        else
            echo -e "${YELLOW}⚠ File saved, but it is empty${NC}"
        fi
        echo -e "${CYAN}File name: ${output_file}${NC}"
        echo -e "${CYAN}Full path: ${abs_path}${NC}"
        local final_size=$(wc -c < "$output_file" 2>/dev/null || echo "0")
        echo -e "${CYAN}Size: ${final_size} bytes${NC}"
        echo -e "${CYAN}Pods processed: ${pod_count}${NC}"
        
        if [ ! -s "$output_file" ]; then
            echo ""
            echo -e "${YELLOW}Possible reasons for an empty file:${NC}"
            echo -e "${YELLOW}  - The selected time range has no logs${NC}"
            echo -e "${YELLOW}  - The pod has no logs in the given container${NC}"
            echo -e "${YELLOW}  - No access to logs${NC}"
        fi
        echo ""
    else
        echo -e "${RED}Error: Could not save the file${NC}" >&2
        rm -f "$temp_file"
        return 1
    fi
}

# List namespaces
get_namespaces() {
    kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | sort
}

# Interactive namespace selection
select_namespace() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Namespace selection${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Collect the namespace list
    local namespaces=($(get_namespaces))
    
    if [ ${#namespaces[@]} -eq 0 ]; then
        echo -e "${YELLOW}Could not list namespaces${NC}"
        echo ""
        read -p "Enter namespace manually [${DEFAULT_NAMESPACE}]: " input_ns
        
        if [ -z "$input_ns" ]; then
            input_ns="$DEFAULT_NAMESPACE"
        fi
        
        if ! check_namespace "$input_ns"; then
            return 1
        fi
        
        NAMESPACE="$input_ns"
        echo -e "${GREEN}✓ Selected namespace: ${NAMESPACE}${NC}"
        echo ""
        return 0
    fi
    
    # Print a numbered namespace list
    local index=1
    local default_index=0
    
    for ns in "${namespaces[@]}"; do
        local marker=""
        if [ "$ns" = "$DEFAULT_NAMESPACE" ]; then
            marker="${GREEN}✓${NC} (default)"
            default_index=$index
        fi
        echo -e "  ${index}) ${BLUE}${ns}${NC} ${marker}"
        ((index++))
    done
    echo ""
    
    # Prompt for a choice
    if [ $default_index -gt 0 ]; then
        read -p "Select a namespace (1-${#namespaces[@]}) or 'q' to quit [${default_index}]: " choice
    else
        read -p "Select a namespace (1-${#namespaces[@]}) or type a name, 'q' to quit: " choice
    fi
    
    # Quit check
    if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
        echo "Cancelled"
        return 1
    fi
    
    # Empty input with a default uses the default
    if [ -z "$choice" ] && [ $default_index -gt 0 ]; then
        choice=$default_index
    fi
    
    # Check whether the choice is a number
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        # Choice by number
        if [ "$choice" -ge 1 ] && [ "$choice" -le ${#namespaces[@]} ]; then
            NAMESPACE="${namespaces[$((choice-1))]}"
        else
            echo -e "${RED}Invalid number!${NC}"
            return 1
        fi
    else
        # Manual input
        if [ -z "$choice" ]; then
            choice="$DEFAULT_NAMESPACE"
        fi
        
        # Check whether that namespace is in the list
        local found=0
        for ns in "${namespaces[@]}"; do
            if [ "$ns" = "$choice" ]; then
                found=1
                break
            fi
        done
        
        if [ $found -eq 1 ]; then
            NAMESPACE="$choice"
        else
            # Try the typed value (may be a new namespace)
            if check_namespace "$choice"; then
                NAMESPACE="$choice"
            else
                echo -e "${RED}Namespace '${choice}' not found!${NC}"
                return 1
            fi
        fi
    fi
    
    echo -e "${GREEN}✓ Selected namespace: ${NAMESPACE}${NC}"
    echo ""
    return 0
}

# Interactive service selection
select_service() {
    local ns="$1"
    
    # Print the header and list to stderr so they stay visible under $()
    echo "" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${CYAN}Service selection${NC}" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo "" >&2
    
    local services=($(get_services "$ns"))
    
    if [ ${#services[@]} -eq 0 ]; then
        echo -e "${YELLOW}No deployments or statefulsets in namespace '${ns}'${NC}" >&2
        return 1
    fi
    
    # Print the service list to stderr
    local index=1
    for service in "${services[@]}"; do
        local service_type=$(echo "$service" | cut -d: -f1)
        local service_name=$(echo "$service" | cut -d: -f2-)
        echo -e "  ${index}) ${BLUE}${service_name}${NC} (${service_type})" >&2
        ((index++))
    done
    echo "" >&2
    
    # Prompt in a loop until a valid choice
    while true; do
        read -p "Select a service (1-${#services[@]}) or 'q' to quit: " choice
        
        # Quit check
        if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
            echo "Cancelled" >&2
            return 1
        fi
        
        # Empty-input check
        if [ -z "$choice" ]; then
            echo -e "${YELLOW}Enter a service number${NC}" >&2
            continue
        fi
        
        # Validate the choice
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Invalid choice! Enter a number from 1 to ${#services[@]}${NC}" >&2
            continue
        fi
        
        if [ "$choice" -lt 1 ] || [ "$choice" -gt ${#services[@]} ]; then
            echo -e "${RED}Invalid choice! Enter a number from 1 to ${#services[@]}${NC}" >&2
            continue
        fi
        
        # Valid choice — return the result on stdout
        local selected_service="${services[$((choice-1))]}"
        echo "$selected_service"
        return 0
    done
}

# Select a time range
select_time_range() {
    local date_format="$1"
    local ns="$2"
    local pod="$3"
    local container="$4"
    
    # Get a real date sample from the logs
    local date_example=""
    if [ -n "$ns" ] && [ -n "$pod" ] && [ -n "$container" ]; then
        date_example=$(get_date_example "$ns" "$pod" "$container")
    fi
    
    # If no sample is available, use a standard one
    if [ -z "$date_example" ]; then
        date_example="2025-12-18T13:41:05+03:00"
    fi
    
    # Print the header and list to stderr so they stay visible under $()
    echo "" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${CYAN}Time range selection${NC}" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo "" >&2
    echo "  1) Last hour" >&2
    echo "  2) Last 3 hours" >&2
    echo "  3) Last 6 hours" >&2
    echo "  4) Custom number of hours" >&2
    echo "  5) Custom number of minutes" >&2
    echo "  6) Specific period (start and end)" >&2
    echo "  7) All available logs" >&2
    echo "" >&2
    
    read -p "Select an option (1-7): " time_choice
    
    case "$time_choice" in
        1)
            echo "--since=1h"
            ;;
        2)
            echo "--since=3h"
            ;;
        3)
            echo "--since=6h"
            ;;
        4)
            read -p "Enter the number of hours: " hours
            if [[ "$hours" =~ ^[0-9]+$ ]]; then
                echo "--since=${hours}h"
            else
                echo -e "${RED}Invalid value!${NC}" >&2
                return 1
            fi
            ;;
        5)
            read -p "Enter the number of minutes: " minutes
            if [[ "$minutes" =~ ^[0-9]+$ ]]; then
                echo "--since=${minutes}m"
            else
                echo -e "${RED}Invalid value!${NC}" >&2
                return 1
            fi
            ;;
        6)
            echo "" >&2
            # Use a real date sample from the logs
            local example_with_tz="$date_example"
            local example_without_tz=$(echo "$date_example" | sed 's/[+\-][0-9][0-9]:[0-9][0-9]$//' | sed 's/Z$//' | sed 's/\.[0-9]*$//')
            
            if [ -n "$date_example" ]; then
                echo -e "${YELLOW}Date format: RFC3339 (sample from logs: ${example_with_tz})${NC}" >&2
                if [ "$example_with_tz" != "$example_without_tz" ]; then
                    echo -e "${YELLOW}A value without timezone is also accepted: ${example_without_tz}${NC}" >&2
                fi
            else
                echo -e "${YELLOW}Date format: RFC3339 (for example: 2025-12-18T13:41:05+03:00 or 2025-12-18T13:41:05Z)${NC}" >&2
                echo -e "${YELLOW}A value without timezone is also accepted: 2025-12-18T13:41:05${NC}" >&2
            fi
            echo "" >&2
            read -p "Enter start time: " start_time
            read -p "Enter end time: " end_time
            
            if [ -z "$start_time" ] || [ -z "$end_time" ]; then
                echo -e "${RED}Both times must be set!${NC}" >&2
                return 1
            fi
            
            # Convert to RFC3339 when needed
            # Add seconds when missing (format must be HH:MM:SS, not HH:MM)
            if [[ "$start_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}$ ]]; then
                # Format YYYY-MM-DDTHH:MM — append seconds
                start_time="${start_time}:00"
            elif [[ "$start_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}[+\-][0-9]{2}:[0-9]{2}$ ]]; then
                # Format YYYY-MM-DDTHH:MM+HH:MM — insert seconds before the timezone
                start_time=$(echo "$start_time" | sed 's/\(T[0-9][0-9]:[0-9][0-9]\)\([+\-]\)/\1:00\2/')
            fi
            
            if [[ "$end_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}$ ]]; then
                # Format YYYY-MM-DDTHH:MM — append seconds
                end_time="${end_time}:00"
            elif [[ "$end_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}[+\-][0-9]{2}:[0-9]{2}$ ]]; then
                # Format YYYY-MM-DDTHH:MM+HH:MM — insert seconds before the timezone
                end_time=$(echo "$end_time" | sed 's/\(T[0-9][0-9]:[0-9][0-9]\)\([+\-]\)/\1:00\2/')
            fi
            
            # When there is no timezone, do NOT append Z automatically
            # Timezone is detected from logs in get_logs()
            # This uses the timezone from the logs themselves instead of forcing UTC
            
            # Check --until-time support
            if check_until_time_support; then
                echo "--since-time=${start_time} --until-time=${end_time}"
            else
                # When --until-time is unsupported, use --since-time only
                # and keep end_time for later filtering
                echo -e "${YELLOW}⚠ This kubectl version does not support --until-time${NC}" >&2
                echo -e "${YELLOW}Logs will be filtered by the end date in the log lines themselves${NC}" >&2
                echo "--since-time=${start_time}|END_TIME:${end_time}"
            fi
            ;;
        7)
            echo ""
            ;;
        *)
            echo -e "${RED}Invalid choice!${NC}" >&2
            return 1
            ;;
    esac
}


# Main function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -h|--help|help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown argument: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check kubectl
    check_kubectl
    
    # Select namespace
    if ! select_namespace; then
        exit 1
    fi
    
    # Validate namespace
    if ! check_namespace "$NAMESPACE"; then
        exit 1
    fi
    
    # Select service
    local selected_service=$(select_service "$NAMESPACE")
    if [ -z "$selected_service" ]; then
        exit 1
    fi
    
    local service_type=$(echo "$selected_service" | cut -d: -f1)
    local service_name=$(echo "$selected_service" | cut -d: -f2-)
    
    echo -e "${GREEN}✓ Selected service: ${service_name} (${service_type})${NC}"
    
    # Get pods for the service
    local pods=($(get_pods_for_service "$NAMESPACE" "$service_type" "$service_name"))
    
    if [ ${#pods[@]} -eq 0 ] || [ -z "${pods[0]}" ]; then
        echo -e "${YELLOW}No pods found for service '${service_name}'${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Pods found: ${#pods[@]}${NC}"
    for pod in "${pods[@]}"; do
        echo -e "  - ${pod}"
    done
    
    # Detect the application container (use the first pod)
    local first_pod="${pods[0]}"
    local container=$(get_application_containers "$NAMESPACE" "$first_pod")
    
    if [ -z "$container" ]; then
        echo -e "${YELLOW}Could not detect the application container, using 'application'${NC}"
        container="application"
    fi
    
    echo -e "${GREEN}✓ Using container: ${container}${NC}"
    
    # Detect the date format from logs (internal use)
    local date_format=$(detect_date_format "$NAMESPACE" "$first_pod" "$container")
    
    # Select a time range (pass pod info to get a real date sample)
    local time_filter=$(select_time_range "$date_format" "$NAMESPACE" "$first_pod" "$container")
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # Generate the file name — always save in the current directory (pwd)
    local output_file="${service_name}-logs-$(date +%Y%m%d_%H%M%S).log"
    
    echo ""
    echo -e "${CYAN}The file will be saved in the current directory: $(pwd)${NC}"
    echo ""
    
    # Fetch logs
    if get_logs "$NAMESPACE" "$container" "$time_filter" "$output_file" "${pods[@]}"; then
        echo -e "${GREEN}Done!${NC}"
    else
        echo -e "${RED}An error occurred while saving logs${NC}"
        exit 1
    fi
}

# Entry point
main "$@"


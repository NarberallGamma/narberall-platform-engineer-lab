#!/bin/bash

# Fetch logs from Kubernetes pods
# Usage:
#   ./kube_logs.sh                         # Interactive mode
#   ./kube_logs.sh -n <namespace>           # Set namespace
#   ./kube_logs.sh -n <ns> -s <service>     # Non-interactive (agent): namespace + service
#   ./kube_logs.sh -n <ns> -s <svc> -t 1h  # + time range (1h, 3h, 6h, 30m, and similar)
#   ./kube_logs.sh -n <ns> -s <svc> --from-time RFC3339 --to-time RFC3339  # from/to interval; trim the file by line timestamps (GNU date)
#   ./kube_logs.sh -n <ns> -s <svc> -o /path/to/dir  # Directory to save the .log
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

# Default namespace (can be overridden via an environment variable)
DEFAULT_NAMESPACE="${K8S_DEFAULT_NAMESPACE:-default}"
NAMESPACE="${DEFAULT_NAMESPACE}"

# Non-interactive mode (for an agent): -n and -s are set
CLI_SERVICE=""
CLI_SINCE=""
CLI_FROM_TIME=""
CLI_TO_TIME=""
OUTPUT_DIR=""

# Help printer
show_help() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Kubernetes Logs Extractor${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Usage:"
    echo "  $0                              # Interactive mode"
    echo "  $0 -n <namespace>               # Set namespace"
    echo "  $0 -n <ns> -s <service>         # Non-interactive mode (for an agent): namespace + service name"
    echo "  $0 -n <ns> -s <svc> -t <time>   # + time range (1h, 3h, 6h, 30m, and similar)"
    echo "  $0 -n <ns> -s <svc> --from-time RFC3339 --to-time RFC3339  # from/to interval (after download — trim the file)"
    echo "  $0 -n <ns> -s <svc> -o <dir>    # Directory to save the .log"
    echo "  $0 help                         # Show this help"
    echo ""
    echo "Arguments:"
    echo "  -n, --namespace <name>   Namespace (required in non-interactive mode)"
    echo "  -s, --service <name>     Deployment or statefulset name (non-interactive mode)"
    echo "  -t, --since <duration>   Time range: 1h, 3h, 6h, 30m, and similar (default: all logs)"
    echo "  --from-time <RFC3339>    Interval start (together with --to-time; incompatible with -t)"
    echo "  --to-time <RFC3339>      Interval end (after collection, logs are trimmed by line time; GNU date is required)"
    echo "  -o, --output-dir <path>  Directory to save the log file."
    echo "                           If the path starts with /mnt/,"
    echo "                           write to /tmp first, then copy into the given directory (cp)."
    echo "  -h, --help               Show help"
    echo ""
    echo "The script can:"
    echo "  - Select a namespace (default: ${DEFAULT_NAMESPACE})"
    echo "  - Select a service from deployments and statefulsets"
    echo "  - Select a time range for logs"
    echo "  - Detect the date format from the logs automatically"
    echo "  - Save logs to a .log file: directly or via a copy when -o /mnt/..."
    echo ""
}

# Check that kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl is not in PATH${NC}"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Error: Failed to connect to the cluster${NC}"
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
    
    # Get deployments
    local deployments=$(kubectl -n "$ns" get deployments -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    for deploy in $deployments; do
        services+=("deployment:$deploy")
    done
    
    # Get statefulsets
    local statefulsets=$(kubectl -n "$ns" get statefulsets -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    for sts in $statefulsets; do
        services+=("statefulset:$sts")
    done
    
    # Print the array
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
        
        # If the selector fails, try fallback methods
        if [ -z "$pods" ] || [ -z "$(echo "$pods" | tr -d ' ')" ]; then
            pods=$(kubectl -n "$ns" get pods -l app="$service_name" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || \
                   kubectl -n "$ns" get pods -l app.kubernetes.io/name="$service_name" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || \
                   kubectl -n "$ns" get pods | grep "$service_name" | awk '{print $1}' || echo "")
        fi
        
        echo "$pods"
    elif [ "$service_type" = "statefulset" ]; then
        # For a statefulset, pods are named: <statefulset-name>-<ordinal>
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
        
        # If the selector fails, try fallback methods
        if [ -z "$pods" ] || [ -z "$(echo "$pods" | tr -d ' ')" ]; then
            # Statefulset pods usually start with the statefulset name
            pods=$(kubectl -n "$ns" get pods | grep "^${service_name}-" | awk '{print $1}' || \
                   kubectl -n "$ns" get pods -l app.kubernetes.io/name="$service_name" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || \
                   kubectl -n "$ns" get pods | grep "$service_name" | awk '{print $1}' || echo "")
        fi
        
        echo "$pods"
    else
        echo ""
    fi
}

# Get containers in the pod (excluding sidecars)
get_application_containers() {
    local ns="$1"
    local pod="$2"
    
    # Get all containers
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
        # If several are found, prefer "application"
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
    
    # Search for various date formats in logs
    # RFC3339: 2025-12-18T13:41:05.741+03:00 or 2025-12-18T13:41:05Z
    if echo "$sample_logs" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}'; then
        echo "rfc3339"
        return
    fi
    
    # ISO 8601: 2025-12-18 13:41:05 or 2026-03-04 10:11:31,753 (Keycloak and others)
    if echo "$sample_logs" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}(,[0-9]+)?'; then
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
    
    # Fetch the last 50 log lines (more, to find a date with a timezone)
    local sample_logs=$(kubectl -n "$ns" logs "$pod" -c "$container" --tail=50 2>/dev/null || echo "")
    
    if [ -z "$sample_logs" ]; then
        echo ""
        return
    fi
    
    # Search for a timezone in various formats:
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
        # Check whether anything follows the date (milliseconds or a timezone)
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

# Get a sample date from the logs
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
    
    # Find the first RFC3339 date (with or without a timezone)
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

# Add a timezone from the logs when missing (for GNU date)
append_tz_if_missing() {
    local ts="$1"
    local tz_hint="$2"
    if [[ "$ts" =~ Z$ ]] || [[ "$ts" =~ [\+\-][0-9]{2}:[0-9]{2}$ ]]; then
        echo "$ts"
        return
    fi
    if [ -z "$tz_hint" ] || [ "$tz_hint" = "" ]; then
        echo "$ts"
        return
    fi
    if [ "$tz_hint" = "Z" ]; then
        echo "${ts}Z"
        return
    fi
    echo "${ts}${tz_hint}"
}

# First timestamp in the log line (RFC3339 / ISO with a space)
extract_timestamp_from_log_line() {
    local line="$1"
    local fmt_hint="$2"
    local m=""
    case "$fmt_hint" in
        iso8601)
            m=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}([.,][0-9]+)?' | head -1)
            if [ -n "$m" ]; then
                echo "$m" | sed 's/,/./g' | sed 's/ /T/'
                return
            fi
            ;;
    esac
    m=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[\+\-][0-9]{2}:[0-9]{2})' | head -1)
    echo "$m"
}

# Trim the saved file to [time_from, time_to] using line formats (GNU date for comparison)
filter_log_file_by_time_window() {
    local file_path="$1"
    local time_from="$2"
    local time_to="$3"
    local date_format_hint="$4"
    local tz_for_bare="$5"

    if ! command -v date &> /dev/null; then
        echo -e "${YELLOW}⚠ date not found, trim skipped${NC}" >&2
        return 1
    fi

    local tf
    local tt
    tf=$(append_tz_if_missing "$time_from" "$tz_for_bare")
    tt=$(append_tz_if_missing "$time_to" "$tz_for_bare")

    local from_s to_s
    from_s=$(date -d "$tf" +%s 2>/dev/null)
    to_s=$(date -d "$tt" +%s 2>/dev/null)
    if [ -z "$from_s" ] || [ -z "$to_s" ]; then
        echo -e "${RED}Error: failed to parse interval bounds (GNU date and RFC3339 required)${NC}" >&2
        return 1
    fi
    if [ "$from_s" -gt "$to_s" ]; then
        echo -e "${RED}Error: start time is after end time${NC}" >&2
        return 1
    fi

    local tmp_out
    tmp_out=$(mktemp)
    local last_kept=false
    local line ts line_s

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == "=== Pod:"* ]]; then
            echo "$line" >> "$tmp_out"
            last_kept=false
            continue
        fi
        if [ -z "$line" ]; then
            echo "" >> "$tmp_out"
            continue
        fi

        ts=$(extract_timestamp_from_log_line "$line" "$date_format_hint")
        if [ -z "$ts" ]; then
            if [ "$last_kept" = true ]; then
                echo "$line" >> "$tmp_out"
            fi
            continue
        fi

        line_s=$(date -d "$ts" +%s 2>/dev/null)
        if [ -z "$line_s" ]; then
            if [ "$last_kept" = true ]; then
                echo "$line" >> "$tmp_out"
            fi
            continue
        fi

        if [ "$line_s" -ge "$from_s" ] && [ "$line_s" -le "$to_s" ]; then
            echo "$line" >> "$tmp_out"
            last_kept=true
        else
            last_kept=false
        fi
    done < "$file_path"

    if ! mv "$tmp_out" "$file_path" 2>/dev/null; then
        rm -f "$tmp_out"
        return 1
    fi
    echo -e "${GREEN}✓ From/to interval trim applied (format: ${date_format_hint:-rfc3339})${NC}"
    return 0
}

# Fetch logs
get_logs() {
    local ns="$1"
    local container="$2"
    local time_filter="$3"
    local output_file="$4"
    shift 4
    local pods=("$@")
    
    # Confirm a file path is set
    if [ -z "$output_file" ]; then
        echo -e "${RED}Error: No path to save the file${NC}" >&2
        return 1
    fi
    
    local temp_file=$(mktemp)
    
    echo -e "${CYAN}Collecting logs...${NC}"
    
    # Detect timezone from the first pod when time has no timezone
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
                        # Try to find the full line with the date
                        local full_date_line=$(echo "$test_logs" | grep -m1 "$sample_date")
                        echo "  [DEBUG] Line with the date: ${full_date_line:0:100}..." >&2
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
        
        # If time has no timezone and one was detected, append it
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
        
        # Fetch logs and add a header
        {
            echo "=== Pod: $pod ==="
            local log_output
            log_output=$(eval "$log_cmd" 2>&1)
            local log_exit_code=$?
            
            if [ $log_exit_code -eq 0 ]; then
                if [ -n "$log_output" ]; then
                    # Raw pod logs; the from/to interval is applied after the full file is built (filter_log_file_by_time_window)
                    echo "$log_output"
                else
                    # Logs are empty — print a more informative message
                    if [ -n "$end_time" ]; then
                        echo "Logs are empty or missing for this time range"
                        echo "  Check:"
                        echo "  - That --since-time uses a valid format"
                        echo "  - That logs exist in the given time range"
                        echo "  - That the pod and container are reachable"
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
    
    # Check whether the temporary file has data
    if [ ! -f "$temp_file" ]; then
        echo -e "${RED}Error: Temporary file was not created${NC}"
        return 1
    fi
    
    # Check file size for debugging
    local file_size=0
    if [ -f "$temp_file" ]; then
        file_size=$(wc -c < "$temp_file" 2>/dev/null || echo "0")
    fi

    # After download: keep only lines in [since-time, END_TIME] (kubectl has no --until-time)
    if [[ "$time_filter" == *"|END_TIME:"* ]]; then
        local trim_to_var=""
        local trim_from_var=""
        trim_to_var=$(echo "$time_filter" | sed 's/.*|END_TIME://')
        local _rest="${time_filter%%|END_TIME:*}"
        trim_from_var="${_rest#--since-time=}"
        if [ -n "$trim_from_var" ] && [ -n "$trim_to_var" ] && [ -f "$temp_file" ]; then
            local df_trim=""
            df_trim=$(detect_date_format "$ns" "${pods[0]}" "$container")
            echo -e "${CYAN}Trim the file by timestamps in log lines: ${trim_from_var} … ${trim_to_var}${NC}"
            filter_log_file_by_time_window "$temp_file" "$trim_from_var" "$trim_to_var" "$df_trim" "$detected_timezone" || \
                echo -e "${YELLOW}⚠ Trim was not applied; the file still has the full kubectl --since-time output${NC}"
        fi
    fi
    
    # Save the file in the current directory (pwd)
    # The file is always saved in the directory from which the script was started
    if mv "$temp_file" "$output_file" 2>/dev/null; then
        # Resolve the full absolute file path (honour -o/--output-dir)
        local abs_path="$output_file"
        if [[ "$output_file" != /* ]]; then
            abs_path="$(pwd)/${output_file}"
        fi
        
        echo ""
        if [ -s "$output_file" ]; then
            echo -e "${GREEN}✓ Logs saved successfully!${NC}"
        else
            echo -e "${YELLOW}⚠ The file was saved but is empty${NC}"
        fi
        echo -e "${CYAN}File name: ${output_file}${NC}"
        echo -e "${CYAN}Full path: ${abs_path}${NC}"
        local final_size=$(wc -c < "$output_file" 2>/dev/null || echo "0")
        echo -e "${CYAN}Size: ${final_size} bytes${NC}"
        echo -e "${CYAN}Pods processed: ${pod_count}${NC}"
        
        if [ ! -s "$output_file" ]; then
            echo ""
            echo -e "${YELLOW}Possible reasons for an empty file:${NC}"
            echo -e "${YELLOW}  - The given time range has no logs${NC}"
            echo -e "${YELLOW}  - The pod has no logs in the given container${NC}"
            echo -e "${YELLOW}  - No access to the logs${NC}"
        fi
        echo ""
    else
        echo -e "${RED}Error: Failed to save the file${NC}" >&2
        rm -f "$temp_file"
        return 1
    fi
}

# List namespaces
get_namespaces() {
    kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | sort
}

# Interactive namespace picker
select_namespace() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Namespace selection${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Get the namespace list
    local namespaces=($(get_namespaces))
    
    if [ ${#namespaces[@]} -eq 0 ]; then
        echo -e "${YELLOW}Failed to get the namespace list${NC}"
        echo ""
        read -p "Enter the namespace manually [${DEFAULT_NAMESPACE}]: " input_ns
        
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
    
    # Print the numbered namespace list
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
    
    # Ask for a choice
    if [ $default_index -gt 0 ]; then
        read -p "Select a namespace (1-${#namespaces[@]}) or 'q' to quit [${default_index}]: " choice
    else
        read -p "Select a namespace (1-${#namespaces[@]}) or type a name, 'q' to quit: " choice
    fi
    
    # Check for quit
    if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
        echo "Cancelled"
        return 1
    fi
    
    # If input is empty and a default exists, use it
    if [ -z "$choice" ] && [ $default_index -gt 0 ]; then
        choice=$default_index
    fi
    
    # Check whether the choice is a number
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        # Choose by number
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
        
        # Check whether the namespace is in the list
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
            # Try the typed value (it may be a new namespace)
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

# Interactive service picker
select_service() {
    local ns="$1"
    
    # Print the header and list on stderr so they stay visible under $()
    echo "" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${CYAN}Service selection${NC}" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo "" >&2
    
    local services=($(get_services "$ns"))
    
    if [ ${#services[@]} -eq 0 ]; then
        echo -e "${YELLOW}In namespace '${ns}' no deployments or statefulsets found${NC}" >&2
        return 1
    fi
    
    # Print the service list on stderr
    local index=1
    for service in "${services[@]}"; do
        local service_type=$(echo "$service" | cut -d: -f1)
        local service_name=$(echo "$service" | cut -d: -f2-)
        echo -e "  ${index}) ${BLUE}${service_name}${NC} (${service_type})" >&2
        ((index++))
    done
    echo "" >&2
    
    # Loop until a valid choice is entered
    while true; do
        read -p "Select a service (1-${#services[@]}) or 'q' to quit: " choice
        
        # Check for quit
        if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
            echo "Cancelled" >&2
            return 1
        fi
        
        # Check for empty input
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

# Time-range picker
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
    
    # Print the header and list on stderr so they stay visible under $()
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
    echo "  6) Custom period (start and end)" >&2
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
            read -p "Enter hours: " hours
            if [[ "$hours" =~ ^[0-9]+$ ]]; then
                echo "--since=${hours}h"
            else
                echo -e "${RED}Invalid value!${NC}" >&2
                return 1
            fi
            ;;
        5)
            read -p "Enter minutes: " minutes
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
                    echo -e "${YELLOW}A value without a timezone is also accepted: ${example_without_tz}${NC}" >&2
                fi
            else
                echo -e "${YELLOW}Date format: RFC3339 (example: 2025-12-18T13:41:05+03:00 or 2025-12-18T13:41:05Z)${NC}" >&2
                echo -e "${YELLOW}A value without a timezone is also accepted: 2025-12-18T13:41:05${NC}" >&2
            fi
            echo "" >&2
            read -p "Enter start time: " start_time
            read -p "Enter end time: " end_time
            
            if [ -z "$start_time" ] || [ -z "$end_time" ]; then
                echo -e "${RED}Both times must be set!${NC}" >&2
                return 1
            fi
            
            # Convert to RFC3339 if needed
            # Add seconds when missing (format must be HH:MM:SS, not HH:MM)
            if [[ "$start_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}$ ]]; then
                # Format YYYY-MM-DDTHH:MM — add seconds
                start_time="${start_time}:00"
            elif [[ "$start_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}[+\-][0-9]{2}:[0-9]{2}$ ]]; then
                # Format YYYY-MM-DDTHH:MM+HH:MM — add seconds before the timezone
                start_time=$(echo "$start_time" | sed 's/\(T[0-9][0-9]:[0-9][0-9]\)\([+\-]\)/\1:00\2/')
            fi
            
            if [[ "$end_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}$ ]]; then
                # Format YYYY-MM-DDTHH:MM — add seconds
                end_time="${end_time}:00"
            elif [[ "$end_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}[+\-][0-9]{2}:[0-9]{2}$ ]]; then
                # Format YYYY-MM-DDTHH:MM+HH:MM — add seconds before the timezone
                end_time=$(echo "$end_time" | sed 's/\(T[0-9][0-9]:[0-9][0-9]\)\([+\-]\)/\1:00\2/')
            fi
            
            # If there is no timezone, do NOT append Z automatically
            # Timezone is detected from logs in get_logs()
            # This uses the timezone from the logs themselves instead of forcing UTC
            
            # Check --until-time support
            if check_until_time_support; then
                echo "--since-time=${start_time} --until-time=${end_time}"
            else
                # If --until-time is unsupported, use only --since-time
                # and keep end_time for later filtering
                echo -e "${YELLOW}⚠ This kubectl version does not support --until-time${NC}" >&2
                echo -e "${YELLOW}Logs will be filtered by the end date in the log lines${NC}" >&2
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


# Resolve service type (deployment or statefulset) by name
resolve_service_type() {
    local ns="$1"
    local name="$2"
    local services=($(get_services "$ns"))
    for s in "${services[@]}"; do
        local st=$(echo "$s" | cut -d: -f1)
        local sn=$(echo "$s" | cut -d: -f2-)
        if [ "$sn" = "$name" ]; then
            echo "$s"
            return 0
        fi
    done
    echo ""
    return 1
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
            -s|--service)
                CLI_SERVICE="$2"
                shift 2
                ;;
            -t|--since)
                CLI_SINCE="$2"
                shift 2
                ;;
            -o|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --from-time)
                CLI_FROM_TIME="$2"
                shift 2
                ;;
            --to-time)
                CLI_TO_TIME="$2"
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

    if [ -n "$CLI_FROM_TIME" ] || [ -n "$CLI_TO_TIME" ]; then
        if [ -z "$CLI_FROM_TIME" ] || [ -z "$CLI_TO_TIME" ]; then
            echo -e "${RED}A from/to interval needs both --from-time and --to-time (RFC3339)${NC}"
            exit 1
        fi
        if [ -n "$CLI_SINCE" ]; then
            echo -e "${RED}Cannot combine -t/--since with --from-time/--to-time${NC}"
            exit 1
        fi
    fi
    
    # Check kubectl
    check_kubectl
    
    local selected_service=""
    local service_type=""
    local service_name=""
    
    if [ -n "$CLI_SERVICE" ] && [ -n "$NAMESPACE" ]; then
        # Non-interactive mode: validate namespace and resolve the service by name
        if ! check_namespace "$NAMESPACE"; then
            exit 1
        fi
        selected_service=$(resolve_service_type "$NAMESPACE" "$CLI_SERVICE")
        if [ -z "$selected_service" ]; then
            echo -e "${RED}Service '${CLI_SERVICE}' not found in namespace '${NAMESPACE}'${NC}"
            exit 1
        fi
        service_type=$(echo "$selected_service" | cut -d: -f1)
        service_name=$(echo "$selected_service" | cut -d: -f2-)
        echo -e "${GREEN}✓ Namespace: ${NAMESPACE}, service: ${service_name} (${service_type})${NC}"
    else
        # Interactive mode
        if ! select_namespace; then
            exit 1
        fi
        if ! check_namespace "$NAMESPACE"; then
            exit 1
        fi
        selected_service=$(select_service "$NAMESPACE")
        if [ -z "$selected_service" ]; then
            exit 1
        fi
        service_type=$(echo "$selected_service" | cut -d: -f1)
        service_name=$(echo "$selected_service" | cut -d: -f2-)
        echo -e "${GREEN}✓ Selected service: ${service_name} (${service_type})${NC}"
    fi
    
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
    
    # Resolve the application container (use the first pod)
    local first_pod="${pods[0]}"
    local container=$(get_application_containers "$NAMESPACE" "$first_pod")
    
    if [ -z "$container" ]; then
        echo -e "${YELLOW}Could not detect the application container, using 'application'${NC}"
        container="application"
    fi
    
    echo -e "${GREEN}✓ Using container: ${container}${NC}"
    
    # Time range
    local time_filter=""
    if [ -n "$CLI_FROM_TIME" ] && [ -n "$CLI_TO_TIME" ]; then
        if check_until_time_support; then
            time_filter="--since-time=${CLI_FROM_TIME} --until-time=${CLI_TO_TIME}"
        else
            time_filter="--since-time=${CLI_FROM_TIME}|END_TIME:${CLI_TO_TIME}"
        fi
    elif [ -n "$CLI_SINCE" ]; then
        # Supported formats: 1h, 3h, 30m, 24h
        if [[ "$CLI_SINCE" =~ ^[0-9]+[hm]$ ]]; then
            time_filter="--since=${CLI_SINCE}"
        else
            echo -e "${RED}Invalid -t/--since format. Examples: 1h, 3h, 30m${NC}"
            exit 1
        fi
    else
        local date_format=$(detect_date_format "$NAMESPACE" "$first_pod" "$container")
        time_filter=$(select_time_range "$date_format" "$NAMESPACE" "$first_pod" "$container")
        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi
    
    # Save path: current directory or OUTPUT_DIR
    # For a /mnt/ path, write to /tmp first, then copy into the given directory
    local log_basename="${service_name}-logs-$(date +%Y%m%d_%H%M%S).log"
    local output_file=""
    local copy_to_path=""
    
    if [ -n "$OUTPUT_DIR" ]; then
        output_file="${OUTPUT_DIR}/${log_basename}"
        if [[ "$output_file" == /mnt/* ]]; then
            # Path under /mnt/: write to /tmp, then copy to -o on success
            copy_to_path="$output_file"
            output_file="/tmp/kube_logs_${log_basename}"
            if ! mkdir -p "$(dirname "$copy_to_path")" 2>/dev/null; then
                echo -e "${YELLOW}Warning: failed to create the copy destination directory: $(dirname "$copy_to_path")${NC}"
            fi
            echo -e "${CYAN}Writing to a temporary file: ${output_file}${NC}"
            echo -e "${CYAN}On success — copy to: ${copy_to_path}${NC}"
        else
            if ! mkdir -p "$OUTPUT_DIR" 2>/dev/null; then
                echo -e "${RED}Failed to create directory: ${OUTPUT_DIR}${NC}"
                exit 1
            fi
            echo -e "${CYAN}The file will be saved: ${output_file}${NC}"
        fi
    else
        output_file="$(pwd)/${log_basename}"
        echo -e "${CYAN}The file will be saved in the current directory: ${output_file}${NC}"
    fi
    echo ""
    
    # Fetch logs (write to the final path or /tmp when copy_to_path is set)
    if get_logs "$NAMESPACE" "$container" "$time_filter" "$output_file" "${pods[@]}"; then
        if [ -n "$copy_to_path" ] && [ -f "$output_file" ]; then
            if cp "$output_file" "$copy_to_path" 2>/dev/null; then
                echo -e "${GREEN}✓ File copied to the given directory: ${copy_to_path}${NC}"
                rm -f "$output_file"
            else
                echo -e "${YELLOW}⚠ File saved: ${output_file}${NC}"
                echo -e "${YELLOW}  Copy to ${copy_to_path} failed (check the path and permissions).${NC}"
            fi
        fi
        echo -e "${GREEN}Done!${NC}"
    else
        echo -e "${RED}An error occurred while saving logs${NC}"
        exit 1
    fi
}

# Run
main "$@"


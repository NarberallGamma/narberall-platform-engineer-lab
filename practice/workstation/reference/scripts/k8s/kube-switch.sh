#!/bin/bash

# Switch between Kubernetes clusters
# Usage:
#   ./kube-switch.sh                    # Interactive cluster selection
#   ./kube-switch.sh <cluster-name>     # Switch to the given cluster
#   ./kube-switch.sh list               # Show available clusters
#   ./kube-switch.sh current            # Show the current active cluster

set -e

# Colors for readable output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Directory with cluster configs
KUBE_CLUSTERS_DIR="${HOME}/.kube/clusters"
KUBE_CONFIG_DIR="${HOME}/.kube"

# Create the configs directory when it is missing
mkdir -p "$KUBE_CLUSTERS_DIR"

# Print help
show_help() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Kubernetes Cluster Switcher${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Usage:"
    echo "  $0                    # Interactive cluster selection"
    echo "  $0 <cluster-name>     # Switch to the given cluster"
    echo "  $0 list               # Show available clusters"
    echo "  $0 current            # Show the current active cluster"
    echo "  $0 help               # Show this help"
    echo ""
    echo "Cluster configs belong in: ${KUBE_CLUSTERS_DIR}/<cluster-name>/config"
    echo "Layout: each cluster-named subdirectory contains a 'config' file"
    echo ""
}

# List available clusters
list_clusters() {
    echo -e "${CYAN}Available clusters:${NC}"
    echo ""
    
    if [ ! -d "$KUBE_CLUSTERS_DIR" ]; then
        echo -e "${YELLOW}Config directory not found: ${KUBE_CLUSTERS_DIR}${NC}"
        echo ""
        echo "To add a cluster, create a directory and copy the config:"
        echo "  mkdir -p ${KUBE_CLUSTERS_DIR}/<cluster-name>"
        echo "  cp /path/to/config ${KUBE_CLUSTERS_DIR}/<cluster-name>/config"
        echo ""
        return 1
    fi
    
    local clusters=()
    local current_cluster=""
    
    # Detect the current active cluster
    if [ -f "${KUBE_CONFIG_DIR}/config" ]; then
        current_cluster=$(kubectl config current-context 2>/dev/null || echo "")
    fi
    
    # Collect clusters (subdirectories that contain a config file)
    for cluster_dir in "$KUBE_CLUSTERS_DIR"/*; do
        if [ -d "$cluster_dir" ] && [ -f "$cluster_dir/config" ]; then
            local cluster_name=$(basename "$cluster_dir")
            clusters+=("$cluster_name")
        fi
    done
    
    if [ ${#clusters[@]} -eq 0 ]; then
        echo -e "${YELLOW}No cluster configs found!${NC}"
        echo ""
        echo "To add a cluster, create a directory and copy the config:"
        echo "  mkdir -p ${KUBE_CLUSTERS_DIR}/<cluster-name>"
        echo "  cp /path/to/config ${KUBE_CLUSTERS_DIR}/<cluster-name>/config"
        echo ""
        return 1
    fi
    
    # Print the list
    local index=1
    for cluster in "${clusters[@]}"; do
        local marker=""
        if [ -n "$current_cluster" ] && echo "$current_cluster" | grep -q "$cluster"; then
            marker="${GREEN}✓${NC}"
        else
            marker=" "
        fi
        echo -e "  ${marker} ${index}) ${BLUE}${cluster}${NC}"
        ((index++))
    done
    echo ""
    
    return 0
}

# Show the current cluster
show_current() {
    if [ ! -f "${KUBE_CONFIG_DIR}/config" ]; then
        echo -e "${YELLOW}Active config not found${NC}"
        return 1
    fi
    
    local current_context=$(kubectl config current-context 2>/dev/null || echo "not set")
    local current_cluster=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null || echo "not determined")
    
    echo -e "${CYAN}Current active cluster:${NC}"
    echo -e "  Context: ${GREEN}${current_context}${NC}"
    echo -e "  Cluster: ${GREEN}${current_cluster}${NC}"
    echo ""
    
    # Show the path to the active config
    if [ -L "${KUBE_CONFIG_DIR}/config" ]; then
        local symlink_target=$(readlink -f "${KUBE_CONFIG_DIR}/config")
        echo -e "  Config: ${symlink_target}"
    else
        echo -e "  Config: ${KUBE_CONFIG_DIR}/config (regular file)"
    fi
    echo ""
}

# Switch to a cluster
switch_cluster() {
    local cluster_name="$1"
    local config_file="${KUBE_CLUSTERS_DIR}/${cluster_name}/config"
    
    # Check that the config exists
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Error: Config for cluster '${cluster_name}' not found!${NC}"
        echo ""
        echo "The config should be at: ${config_file}"
        echo ""
        echo "Available clusters:"
        list_clusters
        return 1
    fi
    
    # Validate the config
    if ! kubectl --kubeconfig="$config_file" cluster-info &>/dev/null; then
        echo -e "${YELLOW}Warning: Could not verify the cluster connection${NC}"
        echo "The config will be activated; tokens/certificates may still need updating"
        echo ""
    fi
    
    # Create a symlink or copy the config
    if [ -L "${KUBE_CONFIG_DIR}/config" ] || [ ! -f "${KUBE_CONFIG_DIR}/config" ]; then
        # When it is a symlink or the file is missing, create a new symlink
        ln -sf "$config_file" "${KUBE_CONFIG_DIR}/config"
    else
        # When it is a regular file, make a backup and create a symlink
        local backup_file="${KUBE_CONFIG_DIR}/config.backup.$(date +%Y%m%d_%H%M%S)"
        cp "${KUBE_CONFIG_DIR}/config" "$backup_file"
        echo -e "${YELLOW}Backup created: ${backup_file}${NC}"
        rm "${KUBE_CONFIG_DIR}/config"
        ln -sf "$config_file" "${KUBE_CONFIG_DIR}/config"
    fi
    
    # Check the current context
    local current_context=$(kubectl config current-context 2>/dev/null || echo "")
    
    echo -e "${GREEN}✓ Switched to cluster: ${cluster_name}${NC}"
    if [ -n "$current_context" ]; then
        echo -e "  Context: ${current_context}"
    fi
    echo ""
    
    # Show cluster information
    echo -e "${CYAN}Cluster information:${NC}"
    kubectl cluster-info 2>/dev/null || echo -e "${YELLOW}Could not get cluster information${NC}"
    echo ""
}

# Interactive cluster selection
interactive_select() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Kubernetes cluster selection${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Collect the cluster list
    local clusters=()
    local current_cluster=""
    
    if [ -f "${KUBE_CONFIG_DIR}/config" ]; then
        current_cluster=$(kubectl config current-context 2>/dev/null || echo "")
    fi
    
    # Collect clusters (subdirectories that contain a config file)
    for cluster_dir in "$KUBE_CLUSTERS_DIR"/*; do
        if [ -d "$cluster_dir" ] && [ -f "$cluster_dir/config" ]; then
            local cluster_name=$(basename "$cluster_dir")
            clusters+=("$cluster_name")
        fi
    done
    
    if [ ${#clusters[@]} -eq 0 ]; then
        echo -e "${YELLOW}No cluster configs found!${NC}"
        echo ""
        echo "To add a cluster, create a directory and copy the config:"
        echo "  mkdir -p ${KUBE_CLUSTERS_DIR}/<cluster-name>"
        echo "  cp /path/to/config ${KUBE_CLUSTERS_DIR}/<cluster-name>/config"
        echo ""
        return 1
    fi
    
    # Print a numbered list
    local index=1
    for cluster in "${clusters[@]}"; do
        local marker=""
        if [ -n "$current_cluster" ] && echo "$current_cluster" | grep -q "$cluster"; then
            marker="${GREEN}✓${NC} (current)"
        else
            marker=" "
        fi
        echo -e "  ${index}) ${BLUE}${cluster}${NC} ${marker}"
        ((index++))
    done
    echo ""
    
    # Prompt for a choice
    read -p "Select a cluster (1-${#clusters[@]}) or 'q' to quit: " choice
    
    if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
        echo "Cancelled"
        return 0
    fi
    
    # Validate the choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#clusters[@]} ]; then
        echo -e "${RED}Invalid choice!${NC}"
        return 1
    fi
    
    # Switch to the selected cluster
    local selected_cluster="${clusters[$((choice-1))]}"
    switch_cluster "$selected_cluster"
}

# Main logic
main() {
    local command="${1:-}"
    
    case "$command" in
        "list"|"ls")
            list_clusters
            ;;
        "current"|"cur")
            show_current
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        "")
            interactive_select
            ;;
        *)
            switch_cluster "$command"
            ;;
    esac
}

# Entry point
main "$@"

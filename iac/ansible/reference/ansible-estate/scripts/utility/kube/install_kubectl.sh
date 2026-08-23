#!/bin/bash

# Install the latest kubectl on Linux
# Usage: ./install_kubectl.sh

set -e

# Colors for readable output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Install kubectl (latest version)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check whether kubectl is already installed
if command -v kubectl &> /dev/null; then
    CURRENT_VERSION=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo "unknown")
    echo -e "${YELLOW}kubectl is already installed: ${CURRENT_VERSION}${NC}"
    echo ""
    read -p "Continue installing the latest version? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Install cancelled"
        exit 0
    fi
fi

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        KUBECTL_ARCH="amd64"
        ;;
    aarch64|arm64)
        KUBECTL_ARCH="arm64"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

echo -e "${BLUE}Architecture: ${KUBECTL_ARCH}${NC}"
echo -e "${BLUE}OS: ${OS}${NC}"
echo ""

# Fetch the latest kubectl version
echo -e "${CYAN}Fetching the latest kubectl version...${NC}"
LATEST_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)

if [ -z "$LATEST_VERSION" ]; then
    echo -e "${RED}Error: Failed to get the kubectl version${NC}"
    exit 1
fi

echo -e "${GREEN}Latest version: ${LATEST_VERSION}${NC}"
echo ""

# Create a temporary directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Download kubectl
DOWNLOAD_URL="https://dl.k8s.io/release/${LATEST_VERSION}/bin/${OS}/${KUBECTL_ARCH}/kubectl"
echo -e "${CYAN}Downloading kubectl from: ${DOWNLOAD_URL}${NC}"

if ! curl -L -o "$TMP_DIR/kubectl" "$DOWNLOAD_URL"; then
    echo -e "${RED}Error: Failed to download kubectl${NC}"
    exit 1
fi

# Make the file executable
chmod +x "$TMP_DIR/kubectl"

# Integrity check (optional, needs sha256sum)
if command -v sha256sum &> /dev/null; then
    echo -e "${CYAN}Checking integrity...${NC}"
    SHA256_URL="https://dl.k8s.io/${LATEST_VERSION}/bin/${OS}/${KUBECTL_ARCH}/kubectl.sha256"
    
    if curl -L -o "$TMP_DIR/kubectl.sha256" "$SHA256_URL"; then
        cd "$TMP_DIR"
        
        # The sha256 file contains only the hash; verify it manually
        EXPECTED_HASH=$(cat kubectl.sha256 | tr -d '[:space:]')
        ACTUAL_HASH=$(sha256sum kubectl | cut -d' ' -f1)
        
        if [ "$EXPECTED_HASH" = "$ACTUAL_HASH" ]; then
            echo -e "${GREEN}✓ Integrity check passed${NC}"
        else
            echo -e "${YELLOW}⚠ Warning: Integrity check failed${NC}"
            echo -e "${YELLOW}  Expected hash: ${EXPECTED_HASH}${NC}"
            echo -e "${YELLOW}  Actual hash: ${ACTUAL_HASH}${NC}"
            read -p "Continue the install? (y/N): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Install cancelled"
                exit 0
            fi
        fi
        cd - > /dev/null
    else
        echo -e "${YELLOW}⚠ Failed to download the integrity file, skipping the check${NC}"
    fi
fi

# Install kubectl
echo ""
echo -e "${CYAN}Installing kubectl...${NC}"

# Resolve the install directory
INSTALL_DIR="/usr/local/bin"
if [ ! -w "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}sudo is required to install into ${INSTALL_DIR}${NC}"
    sudo install -o root -g root -m 0755 "$TMP_DIR/kubectl" "$INSTALL_DIR/kubectl"
else
    install -m 0755 "$TMP_DIR/kubectl" "$INSTALL_DIR/kubectl"
fi

# Verify the install
if command -v kubectl &> /dev/null; then
    INSTALLED_VERSION=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo "unknown")
    echo ""
    echo -e "${GREEN}✓ kubectl installed successfully!${NC}"
    echo -e "${GREEN}Version: ${INSTALLED_VERSION}${NC}"
    echo ""
    
    # Show kubectl info
    echo -e "${CYAN}kubectl information:${NC}"
    kubectl version --client
    echo ""
    
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Place cluster configs in: ~/.kube/clusters/"
    echo "  2. Use the switcher script: ./scripts/utility/kube/kube_switch.sh"
    echo ""
else
    echo -e "${RED}Error: kubectl not found after install${NC}"
    exit 1
fi


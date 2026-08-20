#!/usr/bin/env bash
# Vault HA Cluster Deployment Script for PROD Environment
# Скрипт для развертывания отказоустойчивого Vault кластера в prod окружении

set -euo pipefail
cd "$(dirname "$0")/../.."

COLL_DIR="$(pwd)/.collections"
mkdir -p "$COLL_DIR"

# Проверка аргументов
if [ $# -eq 0 ]; then
    echo "Usage: $0 [deploy|init|status|secrets|help]"
    echo ""
    echo "Commands:"
    echo "  deploy  - Deploy Vault HA cluster and Load Balancers"
    echo "  init    - Initialize and unseal Vault cluster"
    echo "  status  - Check cluster status"
    echo "  secrets - Upload secrets to Vault"
    echo "  help    - Show this help"
    exit 1
fi

COMMAND=$1
INVENTORY="inventories/prod/hosts.ini"
ENV="prod"

# Проверка наличия inventory
if [ ! -f "$INVENTORY" ]; then
    echo "ERROR: Inventory file not found: $INVENTORY"
    exit 1
fi

# Функция для получения значений из group_vars
get_vault_config() {
    local var_name=$1
    local group_vars_file="group_vars/$ENV/vault_cluster.yml"
    
    if [ ! -f "$group_vars_file" ]; then
        echo "ERROR: Group vars file not found: $group_vars_file"
        exit 1
    fi
    
    # Извлекаем значение переменной из YAML файла
    grep "^${var_name}:" "$group_vars_file" | sed 's/.*: *"\(.*\)"/\1/' | sed 's/.*: *\([^"]*\)$/\1/' | head -1
}

# Получаем конфигурацию
VAULT_DOMAIN=$(get_vault_config "vault_domain")
VAULT_VIP=$(get_vault_config "vault_virtual_ip")

# Проверка наличия SSL сертификатов
check_ssl_certificates() {
    echo "Checking SSL certificates..."
    
    if [ ! -f "artifacts/example.com.crt" ] || [ ! -f "artifacts/example.com.key" ]; then
        echo "ERROR: SSL certificates not found in artifacts/ directory"
        echo ""
        echo "Required files:"
        echo "  - artifacts/example.com.crt"
        echo "  - artifacts/example.com.key"
        echo ""
        exit 1
    fi
    
    echo "SUCCESS: SSL certificates found"
}

# Проверка Docker registry credentials
check_registry_credentials() {
    echo "Checking Docker registry credentials..."
    
    if grep -q "your_username" group_vars/prod/vault_cluster.yml || grep -q "your_password" group_vars/prod/vault_cluster.yml; then
        echo "ERROR: Docker registry credentials not configured in group_vars/prod/vault_cluster.yml"
        echo ""
        echo "Please update the following variables:"
        echo "  - docker_registry_username"
        echo "  - docker_registry_password"
        exit 1
    fi
    
    echo "SUCCESS: Docker registry credentials configured"
}

# Установка коллекций Ansible
install_collections() {
    echo "Installing Ansible collections..."
    # Удаляем старые коллекции
    rm -rf .collections
    mkdir -p .collections
    
    docker run --rm -t \
      -v "$(pwd):/work" -w /work \
      --network host \
      ghcr.io/ansible/creator-ee:latest \
      ansible-galaxy collection install -r requirements.yml -p /work/.collections --force
}

# Развертывание Vault кластера
deploy_vault() {
    echo "Starting Vault HA cluster deployment..."
    
    check_ssl_certificates
    check_registry_credentials
    install_collections
    
    echo "Deploying Vault cluster and Load Balancers..."
    docker run --rm -it \
      -v "$(pwd):/work" -w /work \
      -v "$HOME/.ssh:/root/.ssh:ro" \
      --network host \
      -e ANSIBLE_CONFIG=/work/ansible.cfg \
      -e ANSIBLE_ROLES_PATH=/work/roles \
      -e ANSIBLE_COLLECTIONS_PATHS=/work/.collections:/usr/share/ansible/collections \
      ghcr.io/ansible/creator-ee:latest \
      ansible-playbook -i "$INVENTORY" playbooks/vault-deploy-prod.yml "${@:2}"
    
    if [ $? -eq 0 ]; then
        echo "SUCCESS: Vault cluster deployment completed successfully!"
        echo ""
        echo "Next steps:"
        echo "  1. Run: $0 init"
        echo "  2. Configure DNS: $VAULT_DOMAIN -> $VAULT_VIP"
        echo "  3. Access: https://$VAULT_DOMAIN"
    else
        echo "ERROR: Vault cluster deployment failed!"
        exit 1
    fi
}

# Инициализация Vault кластера
init_vault() {
    echo "Initializing Vault cluster..."
    
    install_collections
    
    docker run --rm -it \
      -v "$(pwd):/work" -w /work \
      -v "$HOME/.ssh:/root/.ssh:ro" \
      --network host \
      -e ANSIBLE_CONFIG=/work/ansible.cfg \
      -e ANSIBLE_ROLES_PATH=/work/roles \
      -e ANSIBLE_COLLECTIONS_PATHS=/work/.collections:/usr/share/ansible/collections \
      ghcr.io/ansible/creator-ee:latest \
      ansible-playbook -i "$INVENTORY" playbooks/vault-init-prod.yml "${@:2}"
    
    if [ $? -eq 0 ]; then
        echo "SUCCESS: Vault cluster initialization completed successfully!"
        echo ""
        echo "Cluster is ready for use:"
        echo "  - API: https://$VAULT_VIP"
        echo "  - Domain: https://$VAULT_DOMAIN"
        echo ""
        echo "IMPORTANT: Save the unseal keys and root token securely!"
    else
        echo "ERROR: Vault cluster initialization failed!"
        exit 1
    fi
}

# Проверка статуса кластера
check_status() {
    echo "Checking Vault cluster status..."
    
    install_collections
    
    echo ""
    echo "=== VAULT CLUSTER STATUS ==="
    echo ""
    
    # Проверка Vault нод
    echo "Checking Vault nodes..."
    docker run --rm -t \
      -v "$(pwd):/work" -w /work \
      -v "$HOME/.ssh:/root/.ssh:ro" \
      --network host \
      -e ANSIBLE_CONFIG=/work/ansible.cfg \
      -e ANSIBLE_ROLES_PATH=/work/roles \
      -e ANSIBLE_COLLECTIONS_PATHS=/work/.collections:/usr/share/ansible/collections \
      ghcr.io/ansible/creator-ee:latest \
      ansible vault_cluster -i "$INVENTORY" -m uri -a "url=https://{{ ansible_host }}:8200/v1/sys/health validate_certs=no" --one-line
    
    echo ""
    
    # Проверка Load Balancer нод
    echo "Checking Load Balancer nodes..."
    docker run --rm -t \
      -v "$(pwd):/work" -w /work \
      -v "$HOME/.ssh:/root/.ssh:ro" \
      --network host \
      -e ANSIBLE_CONFIG=/work/ansible.cfg \
      -e ANSIBLE_ROLES_PATH=/work/roles \
      -e ANSIBLE_COLLECTIONS_PATHS=/work/.collections:/usr/share/ansible/collections \
      ghcr.io/ansible/creator-ee:latest \
      ansible vault_lb -i "$INVENTORY" -m uri -a "url=https://{{ ansible_host }}/nginx-health validate_certs=no" --one-line
    
    echo ""
    
    # Проверка через VIP
    echo "Checking cluster through Virtual IP..."
    curl -k -s "https://$VAULT_VIP/v1/sys/health" | jq '.' 2>/dev/null || echo "Cluster not accessible through VIP"
    
    echo ""
    echo "SUCCESS: Status check completed"
}

# Загрузка секретов в Vault
upload_secrets() {
    echo "⚠️  WARNING: PRODUCTION ENVIRONMENT ⚠️"
    echo "Uploading secrets to PRODUCTION Vault cluster..."
    echo ""
    
    # Проверка наличия VAULT_TOKEN
    if [ -z "${VAULT_TOKEN:-}" ]; then
        echo "ERROR: VAULT_TOKEN environment variable is not set!"
        echo ""
        echo "Please export your Vault root token:"
        echo "  export VAULT_TOKEN=\"your-root-token-here\""
        echo ""
        echo "You can find the root token in the output of the init command"
        echo "or in /tmp/vault-keys-*.txt on vault-1 server"
        exit 1
    fi
    
    # Проверка на CHANGE_ME в secrets файле
    if grep -q "CHANGE_ME" group_vars/prod/vault_secrets.yml; then
        echo "ERROR: Found CHANGE_ME placeholder in group_vars/prod/vault_secrets.yml"
        echo ""
        echo "Please replace ALL CHANGE_ME values with actual PROD secrets before uploading!"
        echo "This is a PRODUCTION environment and requires real credentials."
        exit 1
    fi
    
    # Дополнительное подтверждение для PROD
    echo "⚠️  You are about to upload secrets to PRODUCTION Vault cluster ⚠️"
    echo ""
    read -p "Type 'PRODUCTION' to confirm: " confirmation
    
    if [ "$confirmation" != "PRODUCTION" ]; then
        echo "Upload cancelled. Confirmation failed."
        exit 1
    fi
    
    install_collections
    
    echo ""
    echo "=== UPLOADING SECRETS TO VAULT ==="
    echo "Environment: PRODUCTION"
    echo "Vault Address: https://$VAULT_VIP"
    echo ""
    
    docker run --rm -it \
      -v "$(pwd):/work" -w /work \
      --network host \
      -e ANSIBLE_CONFIG=/work/ansible.cfg \
      -e ANSIBLE_ROLES_PATH=/work/roles \
      -e ANSIBLE_COLLECTIONS_PATHS=/work/.collections:/usr/share/ansible/collections \
      -e VAULT_TOKEN="$VAULT_TOKEN" \
      ghcr.io/ansible/creator-ee:latest \
      ansible-playbook playbooks/vault-secrets-prod.yml "${@:2}"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "SUCCESS: Secrets uploaded successfully to PRODUCTION!"
        echo ""
        echo "You can now access secrets via:"
        echo "  - Vault UI: https://$VAULT_DOMAIN"
        echo "  - Vault CLI: vault kv get secret/SECRET_NAME"
        echo "  - API: https://$VAULT_VIP/v1/secret/data/SECRET_NAME"
        echo ""
        echo "⚠️  IMPORTANT: Save the VAULT_TOKEN securely and delete from shell history!"
    else
        echo "ERROR: Secrets upload failed!"
        exit 1
    fi
}

# Показать справку
show_help() {
    echo "Vault HA Cluster Deployment Script"
    echo ""
    echo "This script deploys a highly available Vault cluster with:"
    echo "  - 3 Vault nodes with Raft storage"
    echo "  - 2 Load Balancer nodes with Nginx"
    echo "  - SSL/TLS encryption"
    echo "  - Virtual IP for high availability"
    echo ""
    echo "Architecture:"
    echo "  DNS: $VAULT_DOMAIN -> $VAULT_VIP (Virtual IP)"
    echo "  Virtual IP -> 2 LB servers (Nginx + Keepalived)"
    echo "  LB -> 3 Vault nodes (Docker + Raft)"
    echo ""
    echo "Commands:"
    echo "  deploy  - Deploy infrastructure and services"
    echo "  init    - Initialize and unseal Vault cluster"
    echo "  status  - Check cluster health and status"
    echo "  secrets - Upload secrets to Vault (requires VAULT_TOKEN) ⚠️ PROD"
    echo "  help    - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 deploy                    # Full deployment"
    echo "  $0 init                      # Initialize cluster"
    echo "  $0 status                    # Check status"
    echo "  export VAULT_TOKEN=<token> && $0 secrets  # Upload secrets (PROD)"
    echo ""
    echo "Prerequisites:"
    echo "  1. SSL certificates in artifacts/ directory"
    echo "  2. Docker registry credentials in group_vars/prod/vault_cluster.yml"
    echo "  3. SSH access to target servers"
}

# Основная логика
case "$COMMAND" in
    deploy)
        deploy_vault "$@"
        ;;
    init)
        init_vault "$@"
        ;;
    status)
        check_status
        ;;
    secrets)
        upload_secrets "$@"
        ;;
    help)
        show_help
        ;;
    *)
        echo "ERROR: Unknown command: $COMMAND"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
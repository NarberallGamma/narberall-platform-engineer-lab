#!/usr/bin/env python3
"""
Configuration module for CCE/ECS Cluster Hibernate/Awake Management
"""

import os
import json
import re
from typing import List, Dict, Any, Optional, Tuple

class ClusterConfig:
    """Configuration for a single cluster"""
    
    def __init__(self, cluster_id: str, name: str, project_id: str, 
                 hibernate_schedule: Optional[str] = None,
                 wake_up_delay_minutes: int = 1):
        self.cluster_id = cluster_id
        self.name = name
        self.project_id = project_id
        self.hibernate_schedule = hibernate_schedule
        self.wake_up_delay_minutes = wake_up_delay_minutes

class ECSInstanceConfig:
    """Configuration for a single ECS instance (not part of a cluster)"""
    
    def __init__(self, instance_id: str, name: str, project_id: str,
                 hibernate_schedule: Optional[str] = None):
        self.instance_id = instance_id
        self.name = name
        self.project_id = project_id
        self.hibernate_schedule = hibernate_schedule

class Config:
    """Configuration class for Cluster Hibernate/Awake Management"""
    
    def __init__(self):
        """Initialize configuration from config file or environment variables"""
        
        # Load config from file if available, otherwise use environment variables
        config_file_path = os.getenv('CONFIG_FILE', '/etc/cloud-hibernate-operator.conf')
        config_vars = self._load_config_file(config_file_path)
        
        # Helper function to get value from config file or environment
        def get_config(key: str, default: str = '') -> str:
            if key in config_vars:
                return config_vars[key]
            return os.getenv(key, default)
        
        # IAM Configuration
        self.iam_endpoint = get_config('IAM_ENDPOINT', 'iam.example.com')
        
        # Password authentication (only supported method)
        self.iam_username = get_config('IAM_USERNAME', '')
        self.iam_password = get_config('IAM_PASSWORD', '')
        self.iam_domain_name = get_config('IAM_DOMAIN_NAME', '')
        self.iam_project_name = get_config('IAM_PROJECT_NAME', '')
        
        # API Endpoints
        self.cce_endpoint = get_config('CCE_ENDPOINT', 'cce.example.com')
        self.ecs_endpoint = get_config('ECS_ENDPOINT', 'ecs.example.com')
        
        # Ensure endpoints don't have protocol
        self.iam_endpoint = self.iam_endpoint.replace('https://', '').replace('http://', '')
        self.cce_endpoint = self.cce_endpoint.replace('https://', '').replace('http://', '')
        self.ecs_endpoint = self.ecs_endpoint.replace('https://', '').replace('http://', '')
        
        # Build full URLs
        self.iam_url = f"https://{self.iam_endpoint}/v3/auth/tokens"
        self.cce_base_url = f"https://{self.cce_endpoint}"
        self.ecs_base_url = f"https://{self.ecs_endpoint}"
        
        # Clusters Configuration (JSON format: [{"cluster_id": "...", "name": "...", "project_id": "...", "hibernate_schedule": "...", "wake_up_delay_minutes": 1}])
        clusters_json = get_config('CLUSTERS_CONFIG', '[]')
        self.clusters: List[ClusterConfig] = self._parse_clusters_config(clusters_json)
        
        # ECS Instances Configuration (JSON format: [{"instance_id": "...", "name": "...", "project_id": "...", "hibernate_schedule": "..."}])
        instances_json = get_config('ECS_INSTANCES_CONFIG', '[]')
        self.ecs_instances: List[ECSInstanceConfig] = self._parse_ecs_instances_config(instances_json)
        
        # Telegram Bot settings
        self.telegram_bot_token = get_config('TELEGRAM_BOT_TOKEN', '')
        self.telegram_chat_ids = self._parse_telegram_chat_ids(get_config('TELEGRAM_CHAT_IDS', ''))
        self.telegram_connect_timeout = int(get_config('TELEGRAM_CONNECT_TIMEOUT', '30'))
        self.telegram_total_timeout = int(get_config('TELEGRAM_TOTAL_TIMEOUT', '90'))
        self.telegram_retry_attempts = int(get_config('TELEGRAM_RETRY_ATTEMPTS', '5'))
        self.telegram_retry_delay_seconds = int(get_config('TELEGRAM_RETRY_DELAY_SECONDS', '6'))
        
        # Logging settings
        self.log_level = get_config('LOG_LEVEL', 'INFO')
        self.log_dir = get_config('LOG_DIR', '/app/logs')
        self.log_format = get_config('LOG_FORMAT', 'text')  # 'text' or 'json'
        
        # API Request settings
        self.request_timeout = int(get_config('REQUEST_TIMEOUT', '30'))
        self.max_retries = int(get_config('MAX_RETRIES', '3'))
        self.retry_delay = int(get_config('RETRY_DELAY', '5'))
        self.verify_ssl = get_config('VERIFY_SSL', 'true').lower() == 'true'
        
        # Cluster operation settings
        self.cluster_status_poll_interval = int(get_config('CLUSTER_STATUS_POLL_INTERVAL', '10'))  # seconds
        self.cluster_status_max_wait = int(get_config('CLUSTER_STATUS_MAX_WAIT', '600'))  # seconds (10 minutes)
        
        # ECS operation settings
        self.ecs_status_poll_interval = int(get_config('ECS_STATUS_POLL_INTERVAL', '5'))  # seconds
        self.ecs_status_max_wait = int(get_config('ECS_STATUS_MAX_WAIT', '300'))  # seconds (5 minutes)
        
        # Operation verification and retry settings
        self.operation_verification_delay = int(get_config('OPERATION_VERIFICATION_DELAY', '600'))  # seconds (10 minutes)
        self.operation_retry_attempts = int(get_config('OPERATION_RETRY_ATTEMPTS', '3'))  # number of retry attempts
        self.operation_retry_delay = int(get_config('OPERATION_RETRY_DELAY', '60'))  # seconds between retries
        
        # Schedule settings
        self.schedule_enabled = get_config('SCHEDULE_ENABLED', 'true').lower() == 'true'
        # Duration to ignore schedule after manual override (in hours, default 24)
        self.schedule_override_duration_hours = int(get_config('SCHEDULE_OVERRIDE_DURATION_HOURS', '24'))
        
        # REST API settings
        self.api_host = get_config('API_HOST', '0.0.0.0')
        self.api_port = int(get_config('API_PORT', '8080'))
        self.api_enabled = get_config('API_ENABLED', 'true').lower() == 'true'
        self.swagger_endpoint = get_config('SWAGGER_ENDPOINT', '/api/swagger.json')
        self.swagger_ui_enabled = get_config('SWAGGER_UI_ENABLED', 'true').lower() == 'true'
        self.swagger_ui_endpoint = get_config('SWAGGER_UI_ENDPOINT', '/api/swagger')
        
        # API Security settings
        # Empty value => true (security default); explicit "false" => disabled
        api_auth_val = get_config('API_AUTH_ENABLED', 'true').strip().lower()
        self.api_auth_enabled = (api_auth_val == 'true') if api_auth_val else True
        api_keys_string = get_config('API_KEYS', '')
        self.api_keys = self._parse_api_keys(api_keys_string)
        self.api_key_header = get_config('API_KEY_HEADER', 'X-API-Key')
        
        # IP Whitelisting settings
        api_ip_val = get_config('API_IP_WHITELIST_ENABLED', 'true').strip().lower()
        self.api_ip_whitelist_enabled = (api_ip_val == 'true') if api_ip_val else True
        allowed_ips_string = get_config('API_ALLOWED_IPS', '')
        self.api_allowed_ips = self._parse_allowed_ips(allowed_ips_string)
        
        # Health check settings
        self.health_check_interval = int(get_config('HEALTH_CHECK_INTERVAL', '60'))  # seconds
        self.api_health_check_enabled = get_config('API_HEALTH_CHECK_ENABLED', 'true').lower() == 'true'
        
        # IAM token refresh settings
        # Token expires in 24 hours, refresh it proactively (default: refresh 1 hour before expiration = 23 hours)
        # Set to 0 to refresh only when expired
        self.iam_token_refresh_interval = int(get_config('IAM_TOKEN_REFRESH_INTERVAL', '82800'))  # seconds (23 hours = 82800)
        
        # Application settings
        self.app_name = 'Cloud Hibernate Operator'
        self.app_version = '3.2.1'
    
    def _load_config_file(self, config_file_path: str) -> Dict[str, str]:
        """
        Load configuration from shell-style config file (VAR="value" or VAR='value')
        Returns dictionary with key-value pairs
        
        Handles:
        - VAR="value"
        - VAR='value'
        - VAR=value
        - CLUSTERS_CONFIG='{"key": "value"}' (with JSON containing quotes)
        """
        config_vars = {}
        
        if not os.path.exists(config_file_path):
            # Config file doesn't exist, return empty dict (will use env vars)
            return config_vars
        
        try:
            with open(config_file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
                # Split by lines but handle multi-line values
                lines = content.split('\n')
                i = 0
                while i < len(lines):
                    line = lines[i].strip()
                    
                    # Skip empty lines and comments
                    if not line or line.startswith('#'):
                        i += 1
                        continue
                    
                    # Remove inline comments (but be careful with JSON)
                    comment_pos = line.find('#')
                    if comment_pos != -1:
                        # Check if # is inside quotes
                        in_single_quote = False
                        in_double_quote = False
                        for j, char in enumerate(line):
                            if j >= comment_pos:
                                break
                            if char == "'" and not in_double_quote:
                                in_single_quote = not in_single_quote
                            elif char == '"' and not in_single_quote:
                                in_double_quote = not in_double_quote
                        
                        if not in_single_quote and not in_double_quote:
                            line = line[:comment_pos].strip()
                    
                    # Parse VAR="value" or VAR='value' or VAR=value
                    # Pattern: VAR="value" or VAR='value' or VAR=value
                    match = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$', line)
                    if match:
                        key = match.group(1)
                        value = match.group(2).strip()
                        
                        # Handle quoted values
                        if value.startswith('"') and value.endswith('"'):
                            # Double quotes - remove them
                            value = value[1:-1]
                        elif value.startswith("'") and value.endswith("'"):
                            # Single quotes - remove them
                            value = value[1:-1]
                        
                        config_vars[key] = value
                    
                    i += 1
        except Exception as e:
            # If file can't be read, fall back to environment variables
            import sys
            print(f"Warning: Could not read config file {config_file_path}: {e}", file=sys.stderr)
        
        return config_vars
    
    def _parse_clusters_config(self, clusters_json: str) -> List[ClusterConfig]:
        """Parse clusters configuration from JSON string"""
        try:
            if not clusters_json or clusters_json.strip() == '':
                return []
            
            clusters_data = json.loads(clusters_json)
            clusters = []
            
            for cluster_data in clusters_data:
                # Parse schedules - can be string or list (for multiple schedules)
                hibernate_schedule = cluster_data.get('hibernate_schedule')
                if isinstance(hibernate_schedule, list):
                    hibernate_schedule = '\n'.join(hibernate_schedule)
                
                cluster = ClusterConfig(
                    cluster_id=cluster_data.get('cluster_id', ''),
                    name=cluster_data.get('name', 'unknown'),
                    project_id=cluster_data.get('project_id', ''),
                    hibernate_schedule=hibernate_schedule,
                    wake_up_delay_minutes=int(cluster_data.get('wake_up_delay_minutes', 1))
                )
                clusters.append(cluster)
            
            return clusters
            
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid CLUSTERS_CONFIG JSON format: {e}")
        except Exception as e:
            raise ValueError(f"Error parsing CLUSTERS_CONFIG: {e}")
    
    def _parse_ecs_instances_config(self, instances_json: str) -> List[ECSInstanceConfig]:
        """Parse ECS instances configuration from JSON string"""
        try:
            if not instances_json or instances_json.strip() == '':
                return []
            
            instances_data = json.loads(instances_json)
            instances = []
            
            for instance_data in instances_data:
                # Parse schedules - can be string or list (for multiple schedules)
                hibernate_schedule = instance_data.get('hibernate_schedule')
                if isinstance(hibernate_schedule, list):
                    hibernate_schedule = '\n'.join(hibernate_schedule)
                
                instance = ECSInstanceConfig(
                    instance_id=instance_data.get('instance_id', ''),
                    name=instance_data.get('name', 'unknown'),
                    project_id=instance_data.get('project_id', ''),
                    hibernate_schedule=hibernate_schedule
                )
                instances.append(instance)
            
            return instances
            
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid ECS_INSTANCES_CONFIG JSON format: {e}")
        except Exception as e:
            raise ValueError(f"Error parsing ECS_INSTANCES_CONFIG: {e}")
    
    def _parse_telegram_chat_ids(self, chat_ids_string: str) -> List[str]:
        """Parse Telegram chat IDs from string"""
        if not chat_ids_string:
            return []
        
        return [chat_id.strip() for chat_id in chat_ids_string.split(',') if chat_id.strip()]
    
    def _parse_api_keys(self, api_keys_string: str) -> List[str]:
        """Parse API keys from comma-separated string"""
        if not api_keys_string:
            return []
        
        return [key.strip() for key in api_keys_string.split(',') if key.strip()]
    
    def _parse_allowed_ips(self, allowed_ips_string: str) -> List[str]:
        """Parse allowed IPs/subnets from comma-separated string"""
        if not allowed_ips_string:
            return []
        
        return [ip.strip() for ip in allowed_ips_string.split(',') if ip.strip()]
    
    def has_telegram_bot(self) -> bool:
        """Check if Telegram bot is configured"""
        return bool(self.telegram_bot_token and self.telegram_chat_ids)
    
    def validate_config(self) -> Tuple[bool, List[str]]:
        """Validate configuration and return (is_valid, errors)"""
        errors = []
        
        # Validate password authentication credentials
        if not self.iam_username:
            errors.append("IAM_USERNAME is required")
        if not self.iam_password:
            errors.append("IAM_PASSWORD is required")
        if not self.iam_domain_name:
            errors.append("IAM_DOMAIN_NAME is required (Account Name from My Credential)")
        if not self.iam_project_name:
            errors.append("IAM_PROJECT_NAME is required")
        
        # Validate clusters (optional - can have only instances)
        for i, cluster in enumerate(self.clusters):
            if not cluster.cluster_id:
                errors.append(f"Cluster {i+1}: cluster_id is required")
            if not cluster.project_id:
                errors.append(f"Cluster {i+1}: project_id is required")
            if not cluster.name:
                errors.append(f"Cluster {i+1}: name is required")
        
        # Validate ECS instances (optional - can have only clusters)
        for i, instance in enumerate(self.ecs_instances):
            if not instance.instance_id:
                errors.append(f"ECS Instance {i+1}: instance_id is required")
            if not instance.project_id:
                errors.append(f"ECS Instance {i+1}: project_id is required")
            if not instance.name:
                errors.append(f"ECS Instance {i+1}: name is required")
        
        # At least one cluster or instance must be configured
        if not self.clusters and not self.ecs_instances:
            errors.append("At least one cluster (CLUSTERS_CONFIG) or ECS instance (ECS_INSTANCES_CONFIG) must be configured")
        
        # Validate endpoints
        if not self.iam_endpoint:
            errors.append("IAM_ENDPOINT is required")
        if not self.cce_endpoint:
            errors.append("CCE_ENDPOINT is required")
        if not self.ecs_endpoint:
            errors.append("ECS_ENDPOINT is required")
        
        # Validate API security settings
        if self.api_enabled:
            if self.api_auth_enabled and not self.api_keys:
                errors.append("API_AUTH_ENABLED is true but API_KEYS is empty. At least one API key is required.")
            
            if self.api_ip_whitelist_enabled and not self.api_allowed_ips:
                errors.append("API_IP_WHITELIST_ENABLED is true but API_ALLOWED_IPS is empty. At least one IP/subnet is required.")
            
            # Require at least one auth method when API is enabled (security)
            if not self.api_auth_enabled and not self.api_ip_whitelist_enabled:
                errors.append(
                    "API is enabled but both API_AUTH_ENABLED and API_IP_WHITELIST_ENABLED are false. "
                    "At least one authentication method is required for security."
                )
        
        return (len(errors) == 0, errors)
    
    def get_cluster_by_id(self, cluster_id: str) -> Optional[ClusterConfig]:
        """Get cluster configuration by cluster ID"""
        for cluster in self.clusters:
            if cluster.cluster_id == cluster_id:
                return cluster
        return None
    
    def get_ecs_instance_by_id(self, instance_id: str) -> Optional[ECSInstanceConfig]:
        """Get ECS instance configuration by instance ID"""
        for instance in self.ecs_instances:
            if instance.instance_id == instance_id:
                return instance
        return None
    
    def is_ip_allowed(self, ip: str) -> bool:
        """
        Check if IP address is in the whitelist
        Supports both individual IPs and CIDR notation (e.g., 10.0.0.0/8)
        
        Args:
            ip: IP address to check (e.g., "10.0.0.5")
            
        Returns:
            True if IP is allowed, False otherwise
        """
        if not self.api_ip_whitelist_enabled:
            return True  # If whitelist is disabled, allow all IPs
        
        if not self.api_allowed_ips:
            return False  # If whitelist is enabled but empty, deny all
        
        try:
            import ipaddress
            
            # Try to parse the IP
            try:
                ip_obj = ipaddress.ip_address(ip)
            except ValueError:
                # Invalid IP format
                return False
            
            # Check each allowed IP/subnet
            for allowed in self.api_allowed_ips:
                try:
                    # Try as CIDR network first
                    if '/' in allowed:
                        network = ipaddress.ip_network(allowed, strict=False)
                        if ip_obj in network:
                            return True
                    else:
                        # Try as individual IP
                        allowed_ip = ipaddress.ip_address(allowed)
                        if ip_obj == allowed_ip:
                            return True
                except (ValueError, ipaddress.AddressValueError):
                    # Invalid format, skip this entry
                    continue
            
            return False
            
        except ImportError:
            # ipaddress module not available (shouldn't happen in Python 3.3+)
            # Fallback to simple string comparison
            return ip in self.api_allowed_ips
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert configuration to dictionary (excluding sensitive data)"""
        return {
            'iam_endpoint': self.iam_endpoint,
            'cce_endpoint': self.cce_endpoint,
            'ecs_endpoint': self.ecs_endpoint,
            'clusters_count': len(self.clusters),
            'clusters': [
                {
                    'cluster_id': c.cluster_id,
                    'name': c.name,
                    'project_id': c.project_id,
                    'hibernate_schedule': c.hibernate_schedule,
                    'wake_up_delay_minutes': c.wake_up_delay_minutes
                }
                for c in self.clusters
            ],
            'ecs_instances_count': len(self.ecs_instances),
            'ecs_instances': [
                {
                    'instance_id': i.instance_id,
                    'name': i.name,
                    'project_id': i.project_id,
                    'hibernate_schedule': i.hibernate_schedule
                }
                for i in self.ecs_instances
            ],
            'telegram_enabled': self.has_telegram_bot(),
            'log_level': self.log_level,
            'log_dir': self.log_dir,
            'schedule_enabled': self.schedule_enabled,
            'schedule_override_duration_hours': self.schedule_override_duration_hours,
            'api_enabled': self.api_enabled,
            'api_port': self.api_port,
            'swagger_endpoint': self.swagger_endpoint,
            'swagger_ui_enabled': self.swagger_ui_enabled,
            'swagger_ui_endpoint': self.swagger_ui_endpoint,
            'api_auth_enabled': self.api_auth_enabled,
            'api_ip_whitelist_enabled': self.api_ip_whitelist_enabled,
            'api_keys_count': len(self.api_keys),
            'api_allowed_ips_count': len(self.api_allowed_ips),
            'app_name': self.app_name,
            'app_version': self.app_version
        }

# Global configuration instance
config = Config()

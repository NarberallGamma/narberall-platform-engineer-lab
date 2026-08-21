#!/usr/bin/env python3
"""
Configuration module for SSL Certificate Monitoring
"""

import os
import sys
import re
from typing import List, Dict, Any

class Config:
    """Configuration class for SSL Certificate Monitoring"""
    
    def __init__(self):
        """Initialize configuration from config file or environment variables"""
        
        # Load config from file if available, otherwise use environment variables
        config_file_path = os.getenv('CONFIG_FILE', '/etc/cert-monitoring.conf')
        config_vars = self._load_config_file(config_file_path)
        
        # Helper function to get value from config file or environment
        def get_config(key: str, default: str = '') -> str:
            if key in config_vars:
                return config_vars[key]
            return os.getenv(key, default)
        
        # Email settings
        self.email_recipients: List[str] = self._parse_email_list(
            get_config('EMAIL_RECIPIENTS', 'ops@example.com')
        )
        self.email_from: str = get_config('EMAIL_FROM', 'ssl-monitor@example.com')
        
        # Telegram Bot settings
        self.telegram_bot_token: str = get_config('TELEGRAM_BOT_TOKEN', '')
        self.telegram_chat_ids: List[str] = self._parse_telegram_chat_ids(get_config('TELEGRAM_CHAT_IDS', ''))
        self.telegram_connect_timeout: int = int(get_config('TELEGRAM_CONNECT_TIMEOUT', '30'))
        self.telegram_total_timeout: int = int(get_config('TELEGRAM_TOTAL_TIMEOUT', '90'))
        self.telegram_retry_attempts: int = int(get_config('TELEGRAM_RETRY_ATTEMPTS', '5'))
        self.telegram_retry_delay_seconds: int = int(get_config('TELEGRAM_RETRY_DELAY_SECONDS', '6'))
        
        # Monitoring settings
        self.warning_days: int = int(get_config('WARNING_DAYS', '21'))
        self.ssl_timeout: int = int(get_config('SSL_TIMEOUT', '10'))
        
        # Advanced warning settings (optional)
        self.critical_warning_days: int = int(get_config('CRITICAL_WARNING_DAYS', '7'))  # Critical warnings
        self.early_warning_days: int = int(get_config('EARLY_WARNING_DAYS', '30'))      # Early warnings
        
        # Logging settings
        self.log_level: str = get_config('LOG_LEVEL', 'INFO')
        self.log_file: str = get_config('LOG_FILE', '/app/logs/ssl_monitor.log')
        self.log_format: str = get_config('LOG_FORMAT', 'json')
        
        # Application settings
        self.app_name: str = 'SSL Certificate Monitor'
        self.app_version: str = get_config('APP_VERSION', '2.0.0')
        
        # Default ports to check
        self.default_ports: Dict[str, int] = {
            'https': 443,
            'custom': 8443
        }
        
        # Hosts excluded from Telegram alerts (connectivity errors will only be logged)
        # Format: comma-separated list of hostnames
        excluded_hosts_string = get_config('EXCLUDED_HOSTS_FROM_ALERTS', '')
        self.excluded_hosts_from_alerts: List[str] = self._parse_excluded_hosts(excluded_hosts_string)
        
        # Monitored hosts (comma-separated list or from command line args)
        monitored_hosts_string = get_config('MONITORED_HOSTS', '')
        self.monitored_hosts: List[str] = self._parse_monitored_hosts(monitored_hosts_string)
        
        # Check interval in seconds (how often to check hosts)
        self.check_interval_seconds: int = int(get_config('CHECK_INTERVAL_SECONDS', '3600'))  # Default: 1 hour
    
    def _parse_email_list(self, email_string: str) -> List[str]:
        """Parse comma-separated email list"""
        if not email_string:
            return []
        
        emails = [email.strip() for email in email_string.split(',')]
        return [email for email in emails if email]
    
    def get_hosts_from_args(self) -> List[str]:
        """Get hosts from command line arguments (returns empty list if no args, for long-running mode)"""
        # sys.argv[0] is the script name
        if len(sys.argv) < 2:
            # No arguments - return empty list (will be used in long-running mode with MONITORED_HOSTS)
            return []
        
        # Return all arguments except the script name
        hosts = sys.argv[1:]
        print(f"Monitoring hosts from command line: {', '.join(hosts)}")
        return hosts
    
    def validate_config(self) -> bool:
        """Validate configuration"""
        # Email or Telegram must be configured
        if not self.email_recipients and not self.has_telegram_bot():
            print("ERROR: No notification method configured. Set EMAIL_RECIPIENTS or TELEGRAM_BOT_TOKEN")
            return False
        
        if self.warning_days < 1:
            print("ERROR: Warning days must be >= 1")
            return False
        
        if self.ssl_timeout < 1:
            print("ERROR: SSL timeout must be >= 1")
            return False
        
        if self.check_interval_seconds < 60:
            print("WARNING: Check interval is less than 60 seconds. Recommended: at least 3600 (1 hour)")
        
        return True
    
    
    def _load_config_file(self, config_file_path: str) -> Dict[str, str]:
        """
        Load configuration from shell-style config file (VAR="value" or VAR='value')
        Returns dictionary with key-value pairs
        
        Handles:
        - VAR="value"
        - VAR='value'
        - VAR=value
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
                    
                    # Remove inline comments (but be careful with quotes)
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
                    
                    # Parse VAR="value" or VAR='value' or VAR=value or VAR=('val1' 'val2')
                    match = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$', line)
                    if match:
                        key = match.group(1)
                        value = match.group(2).strip()
                        
                        # Special handling for HOSTS=('host1' 'host2') format (old format)
                        if key == 'HOSTS' and value.startswith('(') and value.endswith(')'):
                            # Keep old format as-is for proper parsing later
                            config_vars[key] = value
                        else:
                            # Handle quoted values
                            if value.startswith('"') and value.endswith('"'):
                                # Double quotes - remove them
                                value = value[1:-1]
                            elif value.startswith("'") and value.endswith("'"):
                                # Single quotes - remove them (but not if it's part of array)
                                if not (value.startswith("('") or value.startswith("('")):
                                    value = value[1:-1]
                            
                            config_vars[key] = value
                    
                    i += 1
        except Exception as e:
            # If file can't be read, fall back to environment variables
            print(f"Warning: Could not read config file {config_file_path}: {e}", file=sys.stderr)
        
        return config_vars
    
    def _parse_telegram_chat_ids(self, chat_ids_string: str) -> List[str]:
        """Parse Telegram chat IDs from string"""
        if not chat_ids_string:
            return []
        
        return [chat_id.strip() for chat_id in chat_ids_string.split(',') if chat_id.strip()]
    
    def _parse_excluded_hosts(self, excluded_hosts_string: str) -> List[str]:
        """Parse excluded hosts from comma-separated string"""
        if not excluded_hosts_string:
            return []
        
        return [host.strip().lower() for host in excluded_hosts_string.split(',') if host.strip()]
    
    def _parse_monitored_hosts(self, monitored_hosts_string: str, old_hosts_string: str = '') -> List[str]:
        """Parse monitored hosts from comma-separated string"""
        # Try new format MONITORED_HOSTS
        if monitored_hosts_string:
            return [host.strip() for host in monitored_hosts_string.split(',') if host.strip()]
        
        # Try to get from command line arguments
        return self.get_hosts_from_args()
    
    def is_host_excluded_from_alerts(self, host: str) -> bool:
        """Check if host is excluded from Telegram alerts"""
        if not self.excluded_hosts_from_alerts:
            return False
        
        host_lower = host.lower()
        return host_lower in self.excluded_hosts_from_alerts
    
    def has_telegram_bot(self) -> bool:
        """Check if Telegram bot is configured"""
        return bool(self.telegram_bot_token and self.telegram_chat_ids)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert configuration to dictionary (excluding sensitive data)"""
        return {
            'email_recipients': self.email_recipients,
            'email_from': self.email_from,
            'warning_days': self.warning_days,
            'ssl_timeout': self.ssl_timeout,
            'critical_warning_days': self.critical_warning_days,
            'early_warning_days': self.early_warning_days,
            'log_level': self.log_level,
            'log_file': self.log_file,
            'log_format': self.log_format,
            'app_name': self.app_name,
            'app_version': self.app_version,
            'telegram_enabled': self.has_telegram_bot(),
            'excluded_hosts_from_alerts': self.excluded_hosts_from_alerts,
            'excluded_hosts_count': len(self.excluded_hosts_from_alerts),
            'monitored_hosts_count': len(self.monitored_hosts),
            'check_interval_seconds': self.check_interval_seconds
        }

# Global configuration instance
config = Config()

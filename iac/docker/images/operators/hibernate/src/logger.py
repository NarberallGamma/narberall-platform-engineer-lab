#!/usr/bin/env python3
"""
Logging module for CCE/ECS Cluster Hibernate/Awake Management
"""

import json
import logging
import os
import sys
from datetime import datetime
from typing import Dict, Any
from config import config

class JSONFormatter(logging.Formatter):
    """Custom JSON formatter for structured logging"""
    
    def format(self, record: logging.LogRecord) -> str:
        """Format log record as JSON"""
        log_entry = {
            'timestamp': datetime.now().isoformat(),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'module': record.module,
            'function': record.funcName,
            'line': record.lineno
        }
        
        # Add extra fields if present
        if hasattr(record, 'extra_fields'):
            log_entry.update(record.extra_fields)
        
        # Add exception info if present
        if record.exc_info:
            log_entry['exception'] = self.formatException(record.exc_info)
        
        return json.dumps(log_entry, ensure_ascii=False)

class ClusterLogger:
    """Cluster Hibernate/Awake Manager Logger"""
    
    def __init__(self):
        """Initialize logger"""
        self.logger = logging.getLogger('cluster_hibernate')
        self.logger.setLevel(getattr(logging, config.log_level.upper(), logging.INFO))
        
        # Remove existing handlers
        for handler in self.logger.handlers[:]:
            self.logger.removeHandler(handler)
        
        # Console handler (always text format)
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(logging.INFO)
        console_formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        console_handler.setFormatter(console_formatter)
        self.logger.addHandler(console_handler)
        
        # File handler
        if config.log_format.lower() == 'json':
            self._setup_json_file_handler()
        else:
            self._setup_text_file_handler()
    
    def _setup_json_file_handler(self):
        """Setup JSON file handler"""
        try:
            # Ensure log directory exists
            if not os.path.exists(config.log_dir):
                os.makedirs(config.log_dir, exist_ok=True)
            
            log_file = os.path.join(config.log_dir, 'cluster_hibernate.log')
            file_handler = logging.FileHandler(log_file)
            file_handler.setLevel(logging.DEBUG)
            file_handler.setFormatter(JSONFormatter())
            self.logger.addHandler(file_handler)
        except Exception as e:
            self.logger.warning(f"Could not setup JSON file logging: {e}")
    
    def _setup_text_file_handler(self):
        """Setup text file handler"""
        try:
            # Ensure log directory exists
            if not os.path.exists(config.log_dir):
                os.makedirs(config.log_dir, exist_ok=True)
            
            log_file = os.path.join(config.log_dir, 'cluster_hibernate.log')
            file_handler = logging.FileHandler(log_file)
            file_handler.setLevel(logging.DEBUG)
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            file_handler.setFormatter(formatter)
            self.logger.addHandler(file_handler)
        except Exception as e:
            self.logger.warning(f"Could not setup text file logging: {e}")
    
    def info(self, message: str, **kwargs):
        """Log info message"""
        self._log_with_extra(logging.INFO, message, kwargs)
    
    def warning(self, message: str, **kwargs):
        """Log warning message"""
        self._log_with_extra(logging.WARNING, message, kwargs)
    
    def error(self, message: str, **kwargs):
        """Log error message"""
        self._log_with_extra(logging.ERROR, message, kwargs)
    
    def debug(self, message: str, **kwargs):
        """Log debug message"""
        self._log_with_extra(logging.DEBUG, message, kwargs)
    
    def critical(self, message: str, **kwargs):
        """Log critical message"""
        self._log_with_extra(logging.CRITICAL, message, kwargs)
    
    def _log_with_extra(self, level: int, message: str, extra_fields: Dict[str, Any]):
        """Log message with extra fields"""
        if extra_fields:
            # Create a custom log record with extra fields
            record = self.logger.makeRecord(
                self.logger.name, level, '', 0, message, (), None
            )
            record.extra_fields = extra_fields
            self.logger.handle(record)
        else:
            self.logger.log(level, message)

# Global logger instance
logger = ClusterLogger()

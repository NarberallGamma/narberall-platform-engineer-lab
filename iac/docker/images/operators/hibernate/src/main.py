#!/usr/bin/env python3
"""
Main entry point for CCE/ECS Cluster Hibernate/Awake Management
Long-running container with scheduling, API, and health checks
"""

import sys
import signal
import threading
import time
import asyncio
from config import config
from logger import logger
from api_server import start_api_server, app
from schedule_manager import schedule_manager
from cloud_api import cloud_api
from telegram_notifier import telegram_notifier

class Application:
    """Main application class"""
    
    def __init__(self):
        """Initialize application"""
        self.running = True
        self.api_thread: threading.Thread = None
        self.health_check_thread: threading.Thread = None
        
        # Setup signal handlers
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        logger.info(f"Received signal {signum}, shutting down...")
        self.running = False
        self.shutdown()
        sys.exit(0)
    
    def validate_configuration(self):
        """Validate configuration before starting"""
        is_valid, errors = config.validate_config()
        if not is_valid:
            logger.error("Configuration validation failed:")
            for error in errors:
                logger.error(f"  - {error}")
            sys.exit(1)
        
        logger.info("Configuration validated successfully")
        logger.info(
            f"API security: auth_enabled={config.api_auth_enabled}, "
            f"ip_whitelist_enabled={config.api_ip_whitelist_enabled}"
        )
    
    def test_connections(self):
        """Test connections to external services (IAM; Telegram проверяется startup-уведомлением)."""
        logger.info("Testing connections...")
        if config.has_telegram_bot():
            logger.info("Telegram: проверка при отправке startup-уведомления (getMe пропущен)")
        else:
            logger.info("Telegram bot not configured, skipping test")
        
        # Test IAM authentication
        logger.info("Testing IAM authentication...")
        try:
            token = cloud_api.get_auth_token()
            if token:
                logger.info("IAM authentication: OK")
            else:
                logger.error("IAM authentication: FAILED")
                sys.exit(1)
        except Exception as e:
            logger.error(f"IAM authentication failed: {e}")
            sys.exit(1)
    
    def start_api_server_thread(self):
        """Start API server in a separate thread"""
        if not config.api_enabled:
            logger.info("API server is disabled")
            return
        
        def run_api():
            try:
                # Always use port 8080 inside container
                # API_PORT from config is used only for port mapping in docker-compose
                container_port = 8080
                app.run(
                    host=config.api_host,
                    port=container_port,
                    debug=False,
                    use_reloader=False,
                    threaded=True
                )
            except Exception as e:
                logger.error(f"API server error: {e}")
        
        self.api_thread = threading.Thread(target=run_api, daemon=True)
        self.api_thread.start()
        logger.info(f"API server started on {config.api_host}:8080 (mapped to host port {config.api_port})")
    
    def start_health_checks(self):
        """Start periodic health checks"""
        if not config.api_health_check_enabled:
            logger.info("API health checks are disabled")
            return
        
        def run_health_checks():
            while self.running:
                try:
                    logger.debug("Running API health checks...")
                    health_status = cloud_api.check_api_health()
                    
                    # Check if any API is unhealthy
                    unhealthy_apis = [api for api, status in health_status.items() if not status]
                    if unhealthy_apis:
                        logger.warning(f"Unhealthy APIs detected: {unhealthy_apis}")
                        # Send notification if Telegram is configured
                        if config.has_telegram_bot():
                            asyncio.run(telegram_notifier.send_api_health_notification(
                                service=', '.join(unhealthy_apis),
                                status='unhealthy',
                                error=f"APIs are not responding: {unhealthy_apis}"
                            ))
                    else:
                        logger.debug("All APIs are healthy")
                    
                    time.sleep(config.health_check_interval)
                except Exception as e:
                    logger.error(f"Health check error: {e}")
                    time.sleep(config.health_check_interval)
        
        self.health_check_thread = threading.Thread(target=run_health_checks, daemon=True)
        self.health_check_thread.start()
        logger.info("Health checks started")
    
    def start_scheduler(self):
        """Start the scheduler"""
        if config.schedule_enabled:
            schedule_manager.start()
        else:
            logger.info("Scheduling is disabled")
    
    def run(self):
        """Run the application"""
        logger.info(f"Starting {config.app_name} v{config.app_version}")
        
        # Validate configuration
        self.validate_configuration()
        
        # Test connections (IAM)
        self.test_connections()

        logger.info("Application starting")
        logger.info(f"Configured clusters: {len(config.clusters)}")
        logger.info(f"Configured ECS instances: {len(config.ecs_instances)}")
        logger.info(f"Scheduling enabled: {config.schedule_enabled}")
        logger.info(f"API enabled: {config.api_enabled}")
        logger.info(f"Telegram notifications: {config.has_telegram_bot()}")

        # Startup Telegram до Flask/scheduler (VPS egress чувствителен к параллельному трафику)
        if config.has_telegram_bot():
            try:
                asyncio.run(telegram_notifier.send_cluster_operation_notification(
                    cluster_name="System",
                    cluster_id="startup",
                    operation="startup",
                    status="success",
                    details={
                        'clusters_count': len(config.clusters),
                        'ecs_instances_count': len(config.ecs_instances),
                        'scheduling_enabled': config.schedule_enabled,
                        'api_enabled': config.api_enabled
                    }
                ))
            except Exception as e:
                logger.warning(f"Failed to send startup notification: {e}")

        # Start API server
        self.start_api_server_thread()
        
        # Start health checks
        self.start_health_checks()
        
        # Start scheduler
        self.start_scheduler()
        
        logger.info("Application started successfully")
        
        # Keep main thread alive
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            logger.info("Received keyboard interrupt, shutting down...")
            self.shutdown()
    
    def shutdown(self):
        """Shutdown the application"""
        logger.info("Shutting down application...")
        
        # Stop scheduler
        schedule_manager.stop()
        
        # Stop health checks (thread will stop when running is False)
        self.running = False
        
        logger.info("Application shutdown complete")

def main():
    """Main entry point"""
    app = Application()
    app.run()

if __name__ == '__main__':
    main()

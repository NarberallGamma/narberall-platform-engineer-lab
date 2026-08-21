#!/usr/bin/env python3
"""
Main entry point for SSL Certificate Monitoring
Long-running container with periodic checks and health checks
"""

import sys
import signal
import threading
import time
import asyncio
from config import config
from logger import logger
from ssl_monitor import SSLCertificateMonitor
from telegram_notifier import telegram_notifier

class Application:
    """Main application class"""
    
    def __init__(self):
        """Initialize application"""
        self.running = True
        self.monitor_thread: threading.Thread = None
        
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
        if not config.validate_config():
            logger.error("Configuration validation failed")
            sys.exit(1)
        
        # Validate monitored hosts
        if not config.monitored_hosts:
            logger.error("No hosts configured for monitoring. Set MONITORED_HOSTS in config file or environment.")
            logger.error("Example: MONITORED_HOSTS=\"host1.example.com,host2.example.com\"")
            sys.exit(1)
        
        logger.info("Configuration validated successfully")
    
    def test_connections(self):
        """Test connections to external services"""
        logger.info("Testing connections...")
        if config.has_telegram_bot():
            logger.info("Telegram: проверка при отправке startup-уведомления (getMe пропущен)")
        else:
            logger.info("Telegram bot not configured, skipping")
    
    def start_monitoring_loop(self):
        """Start periodic monitoring in a background thread"""
        def run_monitoring():
            monitor = SSLCertificateMonitor()
            
            while self.running:
                try:
                    from datetime import datetime
                    check_start_time = datetime.now()
                    logger.info("")
                    logger.info("=" * 60)
                    logger.info(f"Starting SSL certificate check cycle - {check_start_time.strftime('%Y-%m-%d %H:%M:%S')}")
                    logger.info(f"Monitoring {len(config.monitored_hosts)} host(s): {', '.join(config.monitored_hosts)}")
                    logger.info("=" * 60)
                    
                    # Check certificates
                    results = monitor.check_multiple_hosts(config.monitored_hosts)
                    
                    # Print summary
                    monitor.print_summary()
                    
                    # Send notifications
                    asyncio.run(monitor.send_notifications())
                    
                    # Log excluded hosts if any
                    if config.excluded_hosts_from_alerts:
                        logger.info(f"Note: Excluded hosts from Telegram alerts: {', '.join(config.excluded_hosts_from_alerts)}")
                    
                    # Calculate check duration
                    check_end_time = datetime.now()
                    check_duration = (check_end_time - check_start_time).total_seconds()
                    logger.info(f"Check cycle completed in {check_duration:.2f} seconds")
                    
                    # Wait for next check interval
                    next_check_time = check_end_time.timestamp() + config.check_interval_seconds
                    next_check_datetime = datetime.fromtimestamp(next_check_time)
                    logger.info(f"Next check scheduled at: {next_check_datetime.strftime('%Y-%m-%d %H:%M:%S')} (in {config.check_interval_seconds} seconds)")
                    logger.info("=" * 60)
                    logger.info("")
                    time.sleep(config.check_interval_seconds)
                    
                except Exception as e:
                    logger.error(f"Error in monitoring loop: {e}", exc_info=True)
                    # Wait before retrying
                    time.sleep(min(config.check_interval_seconds, 60))
        
        self.monitor_thread = threading.Thread(target=run_monitoring, daemon=True)
        self.monitor_thread.start()
        logger.info("Monitoring loop started")
    
    def run(self):
        """Run the application"""
        logger.info(f"Starting {config.app_name} v{config.app_version}")
        
        # Validate configuration
        self.validate_configuration()
        
        # Test connections
        self.test_connections()

        logger.info("Application started successfully")
        logger.info(f"Configured hosts: {len(config.monitored_hosts)}")
        logger.info(f"Check interval: {config.check_interval_seconds} seconds")
        logger.info(f"Telegram notifications: {config.has_telegram_bot()}")
        if config.excluded_hosts_from_alerts:
            logger.info(f"Excluded hosts from alerts: {', '.join(config.excluded_hosts_from_alerts)}")

        # Startup notification до фонового SSL-цикла (как cloud-hibernate-operator)
        if config.has_telegram_bot():
            try:
                asyncio.run(telegram_notifier.send_startup_notification({
                    'hosts_count': len(config.monitored_hosts),
                    'check_interval': config.check_interval_seconds,
                    'excluded_hosts': config.excluded_hosts_from_alerts,
                    'version': config.app_version
                }))
            except Exception as e:
                logger.warning(f"Failed to send startup notification: {e}")

        # Фоновый цикл SSL-проверок после Telegram startup
        self.start_monitoring_loop()
        
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
        self.running = False
        logger.info("Application shutdown complete")

def main():
    """Main entry point"""
    app = Application()
    app.run()

if __name__ == '__main__':
    main()

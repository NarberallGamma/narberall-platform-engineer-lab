#!/usr/bin/env python3
"""
SSL Certificate Monitoring Tool
Checks SSL certificates and sends email notifications for expiring certificates
"""

import asyncio
import socket
import ssl
import subprocess
import sys
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Tuple
import dns.resolver
from config import config
from logger import logger
from telegram_notifier import TelegramNotifier

class SSLCertificateMonitor:
    """SSL Certificate Monitor class"""
    
    def __init__(self):
        """Initialize SSL monitor"""
        self.telegram_notifier = TelegramNotifier()
        self.results: List[Dict[str, Any]] = []
    
    async def test_telegram_connection(self):
        """Test Telegram bot connection"""
        try:
            if config.has_telegram_bot():
                success = await self.telegram_notifier.test_connection()
                if success:
                    logger.info("Telegram bot connection successful")
                else:
                    logger.warning("Telegram bot connection failed")
                return success
            else:
                logger.info("Telegram bot not configured")
                return False
        except Exception as e:
            logger.error(f"Telegram connection test failed: {e}")
            return False
    
    def resolve_host(self, host: str) -> Optional[str]:
        """Resolve hostname to IP address"""
        try:
            # Try DNS resolution
            result = dns.resolver.resolve(host, 'A')
            ip = str(result[0])
            logger.debug(f"Resolved {host} to {ip}")
            return ip
        except Exception as e:
            logger.warning(f"DNS resolution failed for {host}: {e}")
            try:
                # Fallback to socket resolution
                ip = socket.gethostbyname(host)
                logger.debug(f"Socket resolved {host} to {ip}")
                return ip
            except Exception as e2:
                logger.error(f"All resolution methods failed for {host}: {e2}")
                return None
    
    def check_certificate_python_ssl(self, host: str, port: int = 443) -> Optional[Dict[str, Any]]:
        """Check SSL certificate using Python SSL library"""
        try:
            import ssl
            import socket
            
            logger.debug(f"Checking SSL certificate using Python SSL for {host}:{port}")
            
            # Create SSL context
            context = ssl.create_default_context()
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
            
            # Create socket and wrap with SSL
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(config.ssl_timeout)
            
            try:
                # Connect to the server
                sock.connect((host, port))
                logger.debug(f"TCP connection established to {host}:{port}")
                
                # Wrap socket with SSL
                ssl_sock = context.wrap_socket(sock, server_hostname=host)
                logger.debug(f"SSL connection established to {host}:{port}")
                
                # Get certificate
                cert = ssl_sock.getpeercert()
                cert_der = ssl_sock.getpeercert(binary_form=True)
                
                # Close connections
                ssl_sock.close()
                sock.close()
                
                # Parse certificate information
                from cryptography import x509
                from cryptography.hazmat.backends import default_backend
                
                cert_obj = x509.load_der_x509_certificate(cert_der, default_backend())
                
                # Extract information
                not_before = cert_obj.not_valid_before
                not_after = cert_obj.not_valid_after
                subject = cert_obj.subject.rfc4514_string()
                
                # Get SAN
                san = []
                try:
                    san_ext = cert_obj.extensions.get_extension_for_oid(x509.ExtensionOID.SUBJECT_ALTERNATIVE_NAME)
                    san = [name.value for name in san_ext.value]
                except:
                    pass
                
                # Calculate days until expiry
                now = datetime.utcnow()
                days_until_expiry = (not_after - now).days
                
                # Determine status
                status = "OK"
                if days_until_expiry <= 0:
                    status = "EXPIRED"
                elif days_until_expiry <= config.critical_warning_days:
                    status = "CRITICAL"
                elif days_until_expiry <= config.warning_days:
                    status = "WARNING"
                elif days_until_expiry <= config.early_warning_days:
                    status = "EARLY_WARNING"
                
                return {
                    'host': host,
                    'port': port,
                    'status': status,
                    'days_until_expiry': days_until_expiry,
                    'expiry_date': not_after.isoformat(),
                    'subject': subject,
                    'san': san,
                    'checked_at': now.isoformat(),
                    'error': None
                }
                
            except Exception as e:
                sock.close()
                raise e
                
        except Exception as e:
            logger.error(f"Python SSL check failed for {host}:{port}: {e}")
            return self._create_error_result(host, port, f"Python SSL error: {str(e)}")

    def check_certificate_openssl(self, host: str, port: int = 443) -> Optional[Dict[str, Any]]:
        """Check SSL certificate using openssl command"""
        try:
            # First, try to connect to the host to check basic connectivity
            logger.debug(f"Testing basic connectivity to {host}:{port}")
            
            # Use openssl s_client to get certificate info
            cmd = [
                'openssl', 's_client', 
                '-connect', f'{host}:{port}',
                '-servername', host,
                '-verify_return_error',
                '-quiet',
                '-showcerts',
                '-brief'
            ]
            
            logger.debug(f"Running openssl command: {' '.join(cmd)}")
            
            # Execute openssl command with timeout
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=config.ssl_timeout,
                input=''  # Close connection immediately
            )
            
            if result.returncode != 0:
                logger.warning(f"OpenSSL command failed for {host}:{port}", 
                             returncode=result.returncode,
                             stderr=result.stderr,
                             stdout=result.stdout)
                
                # Try to determine the specific error
                stderr_lower = result.stderr.lower()
                if "connection refused" in stderr_lower:
                    error_msg = "Connection refused - service may be down or port not open"
                elif "no route to host" in stderr_lower:
                    error_msg = "No route to host - network connectivity issue"
                elif "name or service not known" in stderr_lower:
                    error_msg = "DNS resolution failed"
                elif "timeout" in stderr_lower:
                    error_msg = "Connection timeout"
                elif "ssl handshake failure" in stderr_lower:
                    error_msg = "SSL handshake failed - possible SSL/TLS configuration issue"
                elif "certificate verify failed" in stderr_lower:
                    error_msg = "Certificate verification failed"
                elif "wrong version number" in stderr_lower:
                    error_msg = "Wrong SSL/TLS version - service may not support SSL"
                else:
                    error_msg = f"OpenSSL error: {result.stderr.strip()[:200]}"
                
                return self._create_error_result(host, port, error_msg)
            
            # Parse certificate info from openssl output
            cert_info = self._parse_openssl_output(result.stdout, host, port)
            return cert_info
            
        except subprocess.TimeoutExpired:
            logger.error(f"OpenSSL timeout for {host}:{port} after {config.ssl_timeout} seconds")
            return self._create_error_result(host, port, f"Connection timeout after {config.ssl_timeout} seconds")
        except Exception as e:
            logger.error(f"OpenSSL check failed for {host}:{port}: {e}")
            return self._create_error_result(host, port, f"Unexpected error: {str(e)}")
    
    def _parse_openssl_output(self, output: str, host: str, port: int) -> Dict[str, Any]:
        """Parse openssl s_client output"""
        try:
            # Extract certificate information using openssl x509
            cert_cmd = ['openssl', 'x509', '-text', '-noout']
            
            result = subprocess.run(
                cert_cmd,
                input=output,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode != 0:
                logger.warning(f"Failed to parse certificate for {host}:{port}")
                return self._create_error_result(host, port, "Parse error")
            
            cert_text = result.stdout
            
            # Extract key information
            not_before = self._extract_date(cert_text, "Not Before:")
            not_after = self._extract_date(cert_text, "Not After:")
            subject = self._extract_field(cert_text, "Subject:")
            issuer = self._extract_field(cert_text, "Issuer:")
            san = self._extract_san(cert_text)
            
            if not not_after:
                return self._create_error_result(host, port, "No expiry date found")
            
            # Calculate days until expiry
            now = datetime.utcnow()
            expiry_date = datetime.strptime(not_after, "%b %d %H:%M:%S %Y %Z")
            days_until_expiry = (expiry_date - now).days
            
            # Determine status with multiple warning levels
            status = "OK"
            if days_until_expiry <= 0:
                status = "EXPIRED"
            elif days_until_expiry <= config.critical_warning_days:
                status = "CRITICAL"
            elif days_until_expiry <= config.warning_days:
                status = "WARNING"
            elif days_until_expiry <= config.early_warning_days:
                status = "EARLY_WARNING"
            
            return {
                'host': host,
                'port': port,
                'status': status,
                'days_until_expiry': days_until_expiry,
                'expiry_date': expiry_date.isoformat(),
                'not_before': not_before,
                'not_after': not_after,
                'subject': subject,
                'issuer': issuer,
                'san': san,
                'checked_at': now.isoformat(),
                'error': None
            }
            
        except Exception as e:
            logger.error(f"Certificate parsing failed for {host}:{port}: {e}")
            return self._create_error_result(host, port, str(e))
    
    def _extract_date(self, text: str, field: str) -> Optional[str]:
        """Extract date field from certificate text"""
        try:
            lines = text.split('\n')
            for line in lines:
                if field in line:
                    # Extract date part after the field name
                    date_part = line.split(field, 1)[1].strip()
                    return date_part
            return None
        except Exception:
            return None
    
    def _extract_field(self, text: str, field: str) -> Optional[str]:
        """Extract field value from certificate text"""
        try:
            lines = text.split('\n')
            for line in lines:
                if field in line:
                    value = line.split(field, 1)[1].strip()
                    return value
            return None
        except Exception:
            return None
    
    def _extract_san(self, text: str) -> List[str]:
        """Extract Subject Alternative Names"""
        try:
            san_list = []
            lines = text.split('\n')
            in_san_section = False
            
            for line in lines:
                if "Subject Alternative Name:" in line:
                    in_san_section = True
                    continue
                
                if in_san_section:
                    if line.strip() == "":
                        break
                    # Extract DNS names
                    if "DNS:" in line:
                        dns_names = line.split("DNS:")[1:]
                        for dns in dns_names:
                            name = dns.strip().rstrip(',')
                            if name:
                                san_list.append(name)
            
            return san_list
        except Exception:
            return []
    
    def _create_error_result(self, host: str, port: int, error: str) -> Dict[str, Any]:
        """Create error result"""
        return {
            'host': host,
            'port': port,
            'status': 'ERROR',
            'days_until_expiry': None,
            'expiry_date': None,
            'not_before': None,
            'not_after': None,
            'subject': None,
            'issuer': None,
            'san': [],
            'checked_at': datetime.utcnow().isoformat(),
            'error': error
        }
    
    def check_host(self, host: str, port: int = 443) -> Dict[str, Any]:
        """Check SSL certificate for a single host"""
        logger.info(f"Checking SSL certificate for {host}:{port}")
        
        # Resolve hostname
        ip = self.resolve_host(host)
        if not ip:
            return self._create_error_result(host, port, "DNS resolution failed")
        
        logger.info(f"Resolved {host} to {ip}")
        
        # Test basic connectivity first
        if not self._test_connectivity(host, port):
            return self._create_error_result(host, port, "Basic connectivity test failed")
        
        # Check certificate using Python SSL (more reliable than OpenSSL command)
        cert_info = self.check_certificate_python_ssl(host, port)
        if cert_info:
            logger.info(f"Certificate check completed for {host}:{port}",
                       status=cert_info['status'],
                       days_until_expiry=cert_info['days_until_expiry'])
        else:
            cert_info = self._create_error_result(host, port, "Certificate check failed")
            logger.error(f"Certificate check failed for {host}:{port}")
        
        return cert_info
    
    def _test_connectivity(self, host: str, port: int) -> bool:
        """Test basic TCP connectivity to host:port"""
        try:
            import socket
            logger.debug(f"Testing TCP connectivity to {host}:{port}")
            
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)  # 5 second timeout
            
            result = sock.connect_ex((host, port))
            sock.close()
            
            if result == 0:
                logger.debug(f"TCP connection to {host}:{port} successful")
                return True
            else:
                logger.warning(f"TCP connection to {host}:{port} failed with code {result}")
                return False
                
        except Exception as e:
            logger.warning(f"Connectivity test failed for {host}:{port}: {e}")
            return False
    
    def check_multiple_hosts(self, hosts: List[str]) -> List[Dict[str, Any]]:
        """Check SSL certificates for multiple hosts"""
        results = []
        
        for host in hosts:
            try:
                # Check both HTTPS (443) and custom port (8443)
                for port in [443, 8443]:
                    result = self.check_host(host, port)
                    results.append(result)
                    
                    # If we got a valid result on 443, skip 8443
                    if port == 443 and result['status'] != 'ERROR':
                        break
                        
            except Exception as e:
                logger.error(f"Failed to check host {host}: {e}")
                results.append(self._create_error_result(host, 443, str(e)))
        
        self.results = results
        return results
    
    async def send_notifications(self):
        """Send Telegram notifications for expiring certificates"""
        warning_hosts = [r for r in self.results if r['status'] in ['EARLY_WARNING', 'WARNING', 'CRITICAL', 'EXPIRED']]
        error_hosts = [r for r in self.results if r['status'] == 'ERROR']
        
        if warning_hosts or error_hosts:
            try:
                sent = await self.telegram_notifier.send_certificate_report(
                    warning_hosts, error_hosts, self.results
                )
                if sent:
                    logger.info("Telegram notifications sent successfully")
                else:
                    logger.error("Telegram notifications were not delivered to any chat")
            except Exception as e:
                logger.error(f"Failed to send Telegram notifications: {e}")
        else:
            logger.info("No notifications needed - all certificates are OK")
    
    def print_summary(self):
        """Print monitoring summary with detailed results"""
        from datetime import datetime
        
        total_hosts = len(self.results)
        ok_hosts = len([r for r in self.results if r['status'] == 'OK'])
        early_warning_hosts = len([r for r in self.results if r['status'] == 'EARLY_WARNING'])
        warning_hosts = len([r for r in self.results if r['status'] == 'WARNING'])
        critical_hosts = len([r for r in self.results if r['status'] == 'CRITICAL'])
        expired_hosts = len([r for r in self.results if r['status'] == 'EXPIRED'])
        error_hosts = len([r for r in self.results if r['status'] == 'ERROR'])
        
        # Log summary
        logger.info("=" * 60)
        logger.info(f"SSL Certificate Monitoring Summary - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        logger.info("=" * 60)
        logger.info(f"Total checked: {total_hosts}")
        logger.info(f"✅ OK: {ok_hosts}")
        if early_warning_hosts > 0:
            logger.info(f"🔵 Early warnings: {early_warning_hosts}")
        if warning_hosts > 0:
            logger.warning(f"🟡 Warnings: {warning_hosts}")
        if critical_hosts > 0:
            logger.error(f"🟠 Critical: {critical_hosts}")
        if expired_hosts > 0:
            logger.error(f"🔴 Expired: {expired_hosts}")
        if error_hosts > 0:
            logger.error(f"❌ Errors: {error_hosts}")
        logger.info("=" * 60)
        
        # Print detailed results for ALL hosts (even if OK)
        logger.info("Detailed results:")
        for result in self.results:
            if result['status'] == 'ERROR':
                logger.warning(f"  ❌ {result['host']}:{result['port']} - ERROR: {result.get('error', 'Unknown error')}")
            elif result['status'] == 'EXPIRED':
                logger.error(f"  🔴 {result['host']}:{result['port']} - EXPIRED")
                if result.get('expiry_date'):
                    logger.error(f"     Expired on: {result['expiry_date']}")
            elif result['status'] == 'CRITICAL':
                logger.error(f"  🟠 {result['host']}:{result['port']} - CRITICAL ({result['days_until_expiry']} days left)")
                if result.get('expiry_date'):
                    logger.error(f"     Expires: {result['expiry_date']}")
            elif result['status'] == 'WARNING':
                logger.warning(f"  🟡 {result['host']}:{result['port']} - WARNING ({result['days_until_expiry']} days left)")
                if result.get('expiry_date'):
                    logger.warning(f"     Expires: {result['expiry_date']}")
            elif result['status'] == 'EARLY_WARNING':
                logger.info(f"  🔵 {result['host']}:{result['port']} - EARLY WARNING ({result['days_until_expiry']} days left)")
                if result.get('expiry_date'):
                    logger.info(f"     Expires: {result['expiry_date']}")
            else:
                # Log OK status with details
                logger.info(f"  🟢 {result['host']}:{result['port']} - OK ({result['days_until_expiry']} days until expiry)")
                if result.get('expiry_date'):
                    logger.info(f"     Expires: {result['expiry_date']}")
                if result.get('subject'):
                    logger.debug(f"     Subject: {result['subject']}")
        
        logger.info("=" * 60)

async def main():
    """Main function"""
    try:
        print(f"SSL Certificate Monitor starting...")
        print(f"Python version: {sys.version}")
        print(f"Arguments received: {sys.argv}")
        
        # Validate configuration
        if not config.validate_config():
            sys.exit(1)
        
        # Get hosts from command line arguments
        hosts = config.get_hosts_from_args()
        
        logger.info(f"Starting SSL Certificate Monitor v{config.app_version}",
                   hosts=hosts,
                   warning_days=config.warning_days)
        
        # Log notification configuration
        if config.has_telegram_bot():
            logger.info(f"Telegram bot configured: @{config.telegram_bot_token.split(':')[0]}...")
            logger.info(f"Telegram chat IDs: {', '.join(config.telegram_chat_ids)}")
        else:
            logger.info("Telegram bot not configured - notifications will be logged only")
        
        # Initialize monitor
        monitor = SSLCertificateMonitor()
        
        # Test Telegram connection
        await monitor.test_telegram_connection()
        
        try:
            # Check certificates
            results = monitor.check_multiple_hosts(hosts)
            
            # Print summary
            monitor.print_summary()
            
            # Send notifications (while SMTP server is still running)
            await monitor.send_notifications()
            
            # Exit with appropriate code
            has_errors = any(r['status'] in ['ERROR', 'EXPIRED', 'CRITICAL'] for r in results)
            has_warnings = any(r['status'] in ['WARNING', 'EARLY_WARNING'] for r in results)
            
            if has_errors:
                exit_code = 2  # Critical errors
            elif has_warnings:
                exit_code = 1  # Warnings
            else:
                exit_code = 0  # All OK
                
        finally:
            # Cleanup completed
            logger.info("SSL Certificate Monitor completed")
            
        # Exit with the determined code
        sys.exit(exit_code)
            
    except KeyboardInterrupt:
        logger.info("Monitoring interrupted by user")
        sys.exit(130)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())

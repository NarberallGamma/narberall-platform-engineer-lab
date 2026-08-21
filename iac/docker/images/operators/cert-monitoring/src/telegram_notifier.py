#!/usr/bin/env python3
"""
Telegram Notification Module for SSL Certificate Monitoring
Handles sending notifications via Telegram Bot API
"""

import asyncio
import json
import socket
from datetime import datetime
from typing import List, Dict, Any, Optional
import aiohttp
from config import config
from logger import logger


class TelegramNotifier:
    """Telegram notification handler for SSL certificate monitoring"""
    
    def __init__(self):
        """Initialize Telegram notifier"""
        self.bot_token = config.telegram_bot_token
        self.chat_ids = config.telegram_chat_ids
        self.api_url = f"https://api.telegram.org/bot{self.bot_token}"

    def _client_timeout(self) -> aiohttp.ClientTimeout:
        return aiohttp.ClientTimeout(
            total=config.telegram_total_timeout,
            connect=config.telegram_connect_timeout,
        )

    async def _request_with_retry(
        self,
        method: str,
        url: str,
        *,
        max_attempts: Optional[int] = None,
        **kwargs,
    ):
        """HTTP к Telegram API через VPS (extra_hosts + IPv4, без IPv6 happy-eyeballs)."""
        if max_attempts is None:
            max_attempts = config.telegram_retry_attempts
        last_error = None
        for attempt in range(1, max_attempts + 1):
            try:
                connector = aiohttp.TCPConnector(family=socket.AF_INET)
                async with aiohttp.ClientSession(
                    connector=connector,
                    timeout=self._client_timeout(),
                ) as session:
                    http_call = getattr(session, method)
                    async with http_call(url, **kwargs) as response:
                        body = await response.read()
                        if attempt > 1:
                            logger.info(f"Telegram request OK after {attempt} attempts")
                        return response.status, body
            except Exception as exc:
                last_error = exc
                if attempt < max_attempts:
                    logger.warning(
                        f"Telegram request failed (attempt {attempt}/{max_attempts}): {exc}; "
                        f"retry in {config.telegram_retry_delay_seconds}s"
                    )
                    await asyncio.sleep(config.telegram_retry_delay_seconds)
                else:
                    logger.error(
                        f"Telegram request failed after {max_attempts} attempts: {exc}"
                    )
        raise last_error
    
    async def send_certificate_report(self, 
                                    warning_hosts: List[Dict[str, Any]], 
                                    error_hosts: List[Dict[str, Any]], 
                                    all_results: List[Dict[str, Any]]) -> bool:
        """Send comprehensive certificate report via Telegram. Returns True if at least one chat succeeded."""
        try:
            # Filter out excluded hosts from alerts (connectivity errors for excluded hosts are only logged)
            filtered_warning_hosts = self._filter_excluded_hosts(warning_hosts)
            filtered_error_hosts = self._filter_excluded_hosts(error_hosts)
            filtered_all_results = self._filter_excluded_hosts(all_results)
            
            # Count excluded hosts for logging
            excluded_count = len(warning_hosts) + len(error_hosts) - len(filtered_warning_hosts) - len(filtered_error_hosts)
            if excluded_count > 0:
                logger.info(f"Excluded {excluded_count} host(s) from Telegram alerts (configured in EXCLUDED_HOSTS_FROM_ALERTS)")
            
            if not filtered_warning_hosts and not filtered_error_hosts:
                logger.info("No critical certificates found (after filtering excluded hosts), skipping Telegram notification")
                return True
            
            # Create message content
            message = self._create_telegram_message(filtered_warning_hosts, filtered_error_hosts, filtered_all_results)
            
            # Send to all configured chat IDs
            success_count = 0
            for chat_id in self.chat_ids:
                try:
                    await self._send_message(chat_id, message)
                    success_count += 1
                except Exception as e:
                    logger.error(f"Failed to send Telegram message to chat {chat_id}: {e}")
            
            if success_count > 0:
                logger.info(f"Telegram notifications sent successfully to {success_count}/{len(self.chat_ids)} chats")
                return True
            logger.error("Failed to send Telegram notifications to any chat")
            return False
                
        except Exception as e:
            logger.error(f"Error sending Telegram certificate report: {e}")
            return False
    
    def _filter_excluded_hosts(self, hosts: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Filter out hosts that are excluded from Telegram alerts"""
        if not config.excluded_hosts_from_alerts:
            return hosts
        
        filtered = []
        for host_info in hosts:
            host = host_info.get('host', '')
            if not config.is_host_excluded_from_alerts(host):
                filtered.append(host_info)
            else:
                logger.debug(f"Host {host} excluded from Telegram alerts (configured in EXCLUDED_HOSTS_FROM_ALERTS)")
        
        return filtered
    
    def _create_telegram_message(self, 
                               warning_hosts: List[Dict[str, Any]], 
                               error_hosts: List[Dict[str, Any]], 
                               all_results: List[Dict[str, Any]]) -> str:
        """Create Telegram message"""
        total_issues = len(warning_hosts) + len(error_hosts)
        
        # Emoji and status based on highest priority
        if any(h['status'] in ['ERROR', 'EXPIRED', 'CRITICAL'] for h in warning_hosts + error_hosts):
            emoji = "🚨"
            status = "КРИТИЧЕСКИЕ ОШИБКИ"
        elif any(h['status'] == 'WARNING' for h in warning_hosts):
            emoji = "⚠️"
            status = "ПРЕДУПРЕЖДЕНИЯ"
        elif any(h['status'] == 'EARLY_WARNING' for h in warning_hosts):
            emoji = "🔵"
            status = "РАННИЕ ПРЕДУПРЕЖДЕНИЯ"
        else:
            emoji = "✅"
            status = "ВСЕ В ПОРЯДКЕ"
        
        # Header
        message = f"{emoji} <b>SSL Certificate Monitor</b>\n"
        message += f"📊 <b>Статус:</b> {status}\n"
        message += f"🕐 <b>Время:</b> {datetime.now().strftime('%d.%m.%Y %H:%M:%S')}\n\n"
        
        # Summary
        message += f"📈 <b>Сводка:</b>\n"
        message += f"🔴 Истекшие: {len([r for r in all_results if r['status'] == 'EXPIRED'])}\n"
        message += f"🟠 Критические: {len([r for r in all_results if r['status'] == 'CRITICAL'])}\n"
        message += f"🟡 Предупреждения: {len([r for r in all_results if r['status'] == 'WARNING'])}\n"
        message += f"🔵 Ранние предупреждения: {len([r for r in all_results if r['status'] == 'EARLY_WARNING'])}\n"
        message += f"🟢 OK: {len([r for r in all_results if r['status'] == 'OK'])}\n"
        message += f"❌ Ошибки: {len([r for r in all_results if r['status'] == 'ERROR'])}\n\n"
        
        # Critical certificates (EXPIRED and CRITICAL)
        critical_certs = [r for r in warning_hosts + error_hosts if r['status'] in ['EXPIRED', 'CRITICAL']]
        if critical_certs:
            message += f"🚨 *КРИТИЧЕСКИЕ СЕРТИФИКАТЫ:*\n"
            for cert in critical_certs:
                if cert['status'] == 'EXPIRED':
                    message += f"🔴 `{cert['host']}:{cert['port']}` - ИСТЕКШИЙ\n"
                else:
                    message += f"🟠 `{cert['host']}:{cert['port']}` - КРИТИЧЕСКИЙ\n"
                message += f"   📅 Истекает: {cert['expiry_date'] or 'N/A'}\n"
                if cert['days_until_expiry'] is not None:
                    message += f"   ⏰ Осталось дней: {cert['days_until_expiry']}\n"
                if cert['subject']:
                    message += f"   📋 {cert['subject']}\n"
                message += "\n"
        
        # Warning certificates
        if warning_hosts:
            message += f"⚠️ *ПРЕДУПРЕЖДЕНИЯ (ИСТЕКАЮТ СКОРО):*\n"
            for cert in warning_hosts:
                message += f"🟡 `{cert['host']}:{cert['port']}`\n"
                message += f"   ⏰ Осталось дней: {cert['days_until_expiry']}\n"
                message += f"   📅 Истекает: {cert['expiry_date'] or 'N/A'}\n"
                if cert['subject']:
                    message += f"   📋 {cert['subject']}\n"
                message += "\n"
        
        # All certificates summary
        message += f"📋 *ВСЕ СЕРТИФИКАТЫ:*\n"
        for cert in all_results:
            status_emoji = {
                'OK': '🟢',
                'WARNING': '🟡',
                'EXPIRED': '🔴',
                'ERROR': '❌'
            }.get(cert['status'], '❓')
            
            message += f"{status_emoji} `{cert['host']}:{cert['port']}` - {cert['status']}"
            
            if cert['days_until_expiry'] is not None:
                message += f" ({cert['days_until_expiry']} дней)"
            elif cert['error']:
                # Escape special characters in error message for HTML
                error_msg = cert['error'].replace('<', '&lt;').replace('>', '&gt;').replace('&', '&amp;')
                message += f" - {error_msg}"
            
            message += "\n"
        
        # Footer
        message += f"\n🤖 <b>SSL Certificate Monitor v{config.app_version}</b>"
        
        return message
    
    async def _send_message(self, chat_id: str, message: str):
        """Send message to specific chat ID"""
        try:
            # Telegram API has a limit of 4096 characters per message
            if len(message) > 4096:
                # Split message into chunks
                chunks = self._split_message(message, 4000)  # Leave some buffer
                for i, chunk in enumerate(chunks):
                    if i > 0:
                        chunk = f"*Продолжение {i+1}/{len(chunks)}:*\n\n{chunk}"
                    await self._send_single_message(chat_id, chunk)
                    await asyncio.sleep(0.5)  # Small delay between messages
            else:
                await self._send_single_message(chat_id, message)
                
        except Exception as e:
            logger.error(f"Failed to send message to chat {chat_id}: {e}")
            raise
    
    async def _send_single_message(self, chat_id: str, message: str):
        """Send a single message to Telegram"""
        url = f"{self.api_url}/sendMessage"
        
        payload = {
            'chat_id': chat_id,
            'text': message,
            'parse_mode': 'HTML',
            'disable_web_page_preview': True
        }
        
        status, body = await self._request_with_retry('post', url, json=payload)
        if status == 200:
            result = json.loads(body)
            if result.get('ok'):
                logger.debug(f"Telegram message sent successfully to chat {chat_id}")
            else:
                error_msg = result.get('description', 'Unknown error')
                raise Exception(f"Telegram API error: {error_msg}")
        else:
            raise Exception(f"HTTP {status}: {body.decode('utf-8', errors='replace')}")
    
    def _split_message(self, message: str, max_length: int) -> List[str]:
        """Split long message into chunks"""
        chunks = []
        lines = message.split('\n')
        current_chunk = ""
        
        for line in lines:
            # If adding this line would exceed the limit, start a new chunk
            if len(current_chunk) + len(line) + 1 > max_length and current_chunk:
                chunks.append(current_chunk.rstrip())
                current_chunk = line + '\n'
            else:
                current_chunk += line + '\n'
        
        # Add the last chunk if it's not empty
        if current_chunk.strip():
            chunks.append(current_chunk.rstrip())
        
        return chunks
    
    async def send_startup_notification(self, details: Optional[Dict[str, Any]] = None):
        """Send startup notification to Telegram"""
        try:
            if not self.bot_token or not self.chat_ids:
                logger.debug("Telegram bot not configured, skipping startup notification")
                return
            
            message = self._create_startup_message(details)
            
            # Send to all configured chat IDs
            success_count = 0
            for chat_id in self.chat_ids:
                try:
                    await self._send_message(chat_id, message)
                    success_count += 1
                except Exception as e:
                    logger.error(f"Failed to send startup notification to chat {chat_id}: {e}")
            
            if success_count > 0:
                logger.info(f"Startup notification sent successfully to {success_count}/{len(self.chat_ids)} chats")
            else:
                logger.error("Failed to send startup notification to any chat")
                
        except Exception as e:
            logger.error(f"Error sending startup notification: {e}")
    
    def _create_startup_message(self, details: Optional[Dict[str, Any]] = None) -> str:
        """Create startup notification message"""
        message = f"✅ <b>SSL Certificate Monitor</b>\n"
        message += f"🚀 <b>Статус:</b> УСПЕШНО ЗАПУЩЕН\n"
        message += f"🕐 <b>Время:</b> {datetime.now().strftime('%d.%m.%Y %H:%M:%S')}\n"
        
        if details:
            message += f"\n📋 <b>Конфигурация:</b>\n"
            
            if 'hosts_count' in details:
                message += f"• Мониторинг хостов: {details['hosts_count']}\n"
            
            if 'check_interval' in details:
                hours = details['check_interval'] // 3600
                minutes = (details['check_interval'] % 3600) // 60
                if hours > 0:
                    interval_text = f"{hours} ч"
                    if minutes > 0:
                        interval_text += f" {minutes} мин"
                else:
                    interval_text = f"{minutes} мин"
                message += f"• Интервал проверки: {interval_text} ({details['check_interval']} сек)\n"
            
            if 'excluded_hosts' in details and details['excluded_hosts']:
                message += f"• Исключенные хосты из алертов: {len(details['excluded_hosts'])}\n"
            
            if 'version' in details:
                message += f"• Версия: {details['version']}\n"
        
        message += f"\n🤖 <b>SSL Certificate Monitor v{config.app_version}</b>"
        
        return message
    
    async def test_connection(self) -> bool:
        """Test Telegram bot connection"""
        try:
            url = f"{self.api_url}/getMe"
            
            status, body = await self._request_with_retry('get', url, max_attempts=1)
            if status == 200:
                result = json.loads(body)
                if result.get('ok'):
                    bot_info = result.get('result', {})
                    logger.info(f"Telegram bot connected: @{bot_info.get('username', 'unknown')}")
                    return True
                logger.error(f"Telegram bot connection failed: {result.get('description')}")
                return False
            logger.error(f"Telegram bot connection failed: HTTP {status}")
            return False
                        
        except Exception as e:
            logger.error(f"Telegram bot connection test failed: {e}")
            return False

# Global Telegram notifier instance
telegram_notifier = TelegramNotifier()

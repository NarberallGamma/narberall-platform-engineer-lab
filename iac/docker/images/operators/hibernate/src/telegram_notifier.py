#!/usr/bin/env python3
"""
Telegram Notification Module for CCE/ECS Cluster Hibernate/Awake Management
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
    """Telegram notification handler for cluster management"""
    
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
    
    async def send_cluster_operation_notification(self,
                                                  cluster_name: str,
                                                  cluster_id: str,
                                                  operation: str,
                                                  status: str,
                                                  details: Optional[Dict[str, Any]] = None):
        """Send notification about cluster operation (hibernate/awake)"""
        try:
            if not self.bot_token or not self.chat_ids:
                logger.debug("Telegram bot not configured, skipping notification")
                return
            
            message = self._create_operation_message(cluster_name, cluster_id, operation, status, details)
            
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
            else:
                logger.error("Failed to send Telegram notifications to any chat")
                
        except Exception as e:
            logger.error(f"Error sending Telegram notification: {e}")
    
    async def send_ecs_instance_operation_notification(self,
                                                       instance_name: str,
                                                       instance_id: str,
                                                       operation: str,
                                                       status: str,
                                                       details: Optional[Dict[str, Any]] = None):
        """Send notification about ECS instance operation (stop/start)"""
        try:
            if not self.bot_token or not self.chat_ids:
                logger.debug("Telegram bot not configured, skipping notification")
                return
            
            message = self._create_ecs_instance_operation_message(instance_name, instance_id, operation, status, details)
            
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
            else:
                logger.error("Failed to send Telegram notifications to any chat")
                
        except Exception as e:
            logger.error(f"Error sending Telegram notification: {e}")
    
    async def send_api_health_notification(self,
                                           service: str,
                                           status: str,
                                           error: Optional[str] = None):
        """Send notification about API health check"""
        try:
            if not self.bot_token or not self.chat_ids:
                return
            
            emoji = "✅" if status == "healthy" else "🚨"
            message = f"{emoji} <b>API Health Check</b>\n"
            message += f"🔧 <b>Сервис:</b> {service}\n"
            message += f"📊 <b>Статус:</b> {status.upper()}\n"
            message += f"🕐 <b>Время:</b> {datetime.now().strftime('%d.%m.%Y %H:%M:%S')}\n"
            
            if error:
                message += f"\n❌ <b>Ошибка:</b>\n<code>{error}</code>"
            
            message += f"\n\n🤖 <b>{config.app_name} v{config.app_version}</b>"
            
            for chat_id in self.chat_ids:
                try:
                    await self._send_message(chat_id, message)
                except Exception as e:
                    logger.error(f"Failed to send health check notification to chat {chat_id}: {e}")
                    
        except Exception as e:
            logger.error(f"Error sending API health notification: {e}")
    
    async def send_error_notification(self,
                                     error_type: str,
                                     error_message: str,
                                     cluster_name: Optional[str] = None,
                                     details: Optional[Dict[str, Any]] = None):
        """Send error notification"""
        try:
            if not self.bot_token or not self.chat_ids:
                return
            
            message = f"🚨 <b>Ошибка: {error_type}</b>\n"
            message += f"🕐 <b>Время:</b> {datetime.now().strftime('%d.%m.%Y %H:%M:%S')}\n"
            
            if cluster_name:
                message += f"🏗️ <b>Кластер:</b> {cluster_name}\n"
            
            message += f"\n❌ <b>Сообщение:</b>\n<code>{error_message}</code>"
            
            if details:
                message += f"\n\n📋 <b>Детали:</b>\n"
                for key, value in details.items():
                    message += f"• <b>{key}:</b> {value}\n"
            
            message += f"\n\n🤖 <b>{config.app_name} v{config.app_version}</b>"
            
            for chat_id in self.chat_ids:
                try:
                    await self._send_message(chat_id, message)
                except Exception as e:
                    logger.error(f"Failed to send error notification to chat {chat_id}: {e}")
                    
        except Exception as e:
            logger.error(f"Error sending error notification: {e}")
    
    def _create_operation_message(self,
                                  cluster_name: str,
                                  cluster_id: str,
                                  operation: str,
                                  status: str,
                                  details: Optional[Dict[str, Any]] = None) -> str:
        """Create Telegram message for cluster operation"""
        
        # Emoji and status based on operation and status
        if operation == "hibernate":
            emoji = "😴" if status == "success" else "⚠️"
            operation_text = "Усыпление кластера"
        elif operation == "awake":
            emoji = "🌅" if status == "success" else "⚠️"
            operation_text = "Пробуждение кластера"
        elif operation == "hibernate_verification" or operation == "awake_verification":
            emoji = "✅" if status == "success" else "⚠️"
            operation_text = f"Проверка {'усыпления' if 'hibernate' in operation else 'пробуждения'} кластера"
        elif operation == "hibernate_retry" or operation == "awake_retry":
            emoji = "🔄" if status == "in_progress" else ("✅" if status == "success" else "❌")
            operation_text = f"Повторная попытка {'усыпления' if 'hibernate' in operation else 'пробуждения'} кластера"
        else:
            emoji = "ℹ️"
            operation_text = operation
        
        if status == "success":
            status_emoji = "✅"
            status_text = "УСПЕШНО"
        elif status == "failed":
            status_emoji = "❌"
            status_text = "ОШИБКА"
        elif status == "in_progress":
            status_emoji = "⏳"
            status_text = "В ПРОЦЕССЕ"
        else:
            status_emoji = "⚠️"
            status_text = status.upper()
        
        # Header
        message = f"{emoji} <b>{operation_text}</b>\n"
        message += f"{status_emoji} <b>Статус:</b> {status_text}\n"
        message += f"🏗️ <b>Кластер:</b> {cluster_name}\n"
        message += f"🆔 <b>ID:</b> <code>{cluster_id}</code>\n"
        message += f"🕐 <b>Время:</b> {datetime.now().strftime('%d.%m.%Y %H:%M:%S')}\n"
        
        # Details
        if details:
            message += f"\n📋 <b>Детали:</b>\n"
            
            if 'worker_nodes_count' in details:
                message += f"• Worker nodes: {details['worker_nodes_count']}\n"
            
            if 'worker_nodes_processed' in details:
                message += f"• Обработано nodes: {details['worker_nodes_processed']}\n"
            
            if 'cluster_status' in details:
                message += f"• Статус кластера: {details['cluster_status']}\n"
            
            if 'current_status' in details:
                message += f"• Текущий статус: {details['current_status']}\n"
            
            if 'expected_status' in details:
                message += f"• Ожидаемый статус: {details['expected_status']}\n"
            
            if 'attempt' in details:
                message += f"• Попытка: {details['attempt']}"
                if 'max_attempts' in details:
                    message += f" из {details['max_attempts']}"
                message += "\n"
            
            if 'attempts' in details:
                message += f"• Всего попыток: {details['attempts']}\n"
            
            if 'duration_seconds' in details:
                message += f"• Длительность: {details['duration_seconds']} сек\n"
            
            if 'error' in details:
                error_msg = str(details['error']).replace('<', '&lt;').replace('>', '&gt;').replace('&', '&amp;')
                message += f"• Ошибка: <code>{error_msg}</code>\n"
        
        # Footer
        message += f"\n🤖 <b>{config.app_name} v{config.app_version}</b>"
        
        return message
    
    def _create_ecs_instance_operation_message(self,
                                               instance_name: str,
                                               instance_id: str,
                                               operation: str,
                                               status: str,
                                               details: Optional[Dict[str, Any]] = None) -> str:
        """Create Telegram message for ECS instance operation"""
        
        # Emoji and status based on operation and status
        if operation == "stop":
            emoji = "🛑" if status == "success" else "⚠️"
            operation_text = "Остановка ECS instance"
        elif operation == "start":
            emoji = "▶️" if status == "success" else "⚠️"
            operation_text = "Запуск ECS instance"
        elif operation == "stop_verification" or operation == "start_verification":
            emoji = "✅" if status == "success" else "⚠️"
            operation_text = f"Проверка {'остановки' if 'stop' in operation else 'запуска'} ECS instance"
        elif operation == "stop_retry" or operation == "start_retry":
            emoji = "🔄" if status == "in_progress" else ("✅" if status == "success" else "❌")
            operation_text = f"Повторная попытка {'остановки' if 'stop' in operation else 'запуска'} ECS instance"
        else:
            emoji = "ℹ️"
            operation_text = operation
        
        if status == "success":
            status_emoji = "✅"
            status_text = "УСПЕШНО"
        elif status == "failed":
            status_emoji = "❌"
            status_text = "ОШИБКА"
        elif status == "in_progress":
            status_emoji = "⏳"
            status_text = "В ПРОЦЕССЕ"
        else:
            status_emoji = "⚠️"
            status_text = status.upper()
        
        # Header
        message = f"{emoji} <b>{operation_text}</b>\n"
        message += f"{status_emoji} <b>Статус:</b> {status_text}\n"
        message += f"💻 <b>Instance:</b> {instance_name}\n"
        message += f"🆔 <b>ID:</b> <code>{instance_id}</code>\n"
        message += f"🕐 <b>Время:</b> {datetime.now().strftime('%d.%m.%Y %H:%M:%S')}\n"
        
        # Details
        if details:
            message += f"\n📋 <b>Детали:</b>\n"
            
            if 'current_status' in details:
                message += f"• Текущий статус: {details['current_status']}\n"
            
            if 'expected_status' in details:
                message += f"• Ожидаемый статус: {details['expected_status']}\n"
            
            if 'attempt' in details:
                message += f"• Попытка: {details['attempt']}"
                if 'max_attempts' in details:
                    message += f" из {details['max_attempts']}"
                message += "\n"
            
            if 'attempts' in details:
                message += f"• Всего попыток: {details['attempts']}\n"
            
            if 'duration_seconds' in details:
                message += f"• Длительность: {details['duration_seconds']} сек\n"
            
            if 'error' in details:
                error_msg = str(details['error']).replace('<', '&lt;').replace('>', '&gt;').replace('&', '&amp;')
                message += f"• Ошибка: <code>{error_msg}</code>\n"
        
        # Footer
        message += f"\n🤖 <b>{config.app_name} v{config.app_version}</b>"
        
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
    
    async def test_connection(self) -> bool:
        """Test Telegram bot connection"""
        try:
            if not self.bot_token:
                return False
            
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

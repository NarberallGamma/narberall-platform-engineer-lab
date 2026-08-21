#!/usr/bin/env python3
"""
ECS Instance Manager module for Cloud Hibernate Operator
Handles operations for individual ECS instances (not part of clusters)
"""

import time
import asyncio
import threading
from typing import Optional, Dict, Any
from config import config, ECSInstanceConfig
from cloud_api import cloud_api
from logger import logger
from telegram_notifier import telegram_notifier

class ECSInstanceManager:
    """Manages ECS instance stop/start operations"""
    
    def __init__(self):
        """Initialize ECS Instance Manager"""
        self.cloud_api = cloud_api
    
    async def stop_instance(self, instance_config: ECSInstanceConfig) -> Dict[str, Any]:
        """Stop an ECS instance"""
        start_time = time.time()
        instance_name = instance_config.name
        instance_id = instance_config.instance_id
        project_id = instance_config.project_id
        
        logger.info(f"Starting stop process for ECS instance: {instance_name} ({instance_id})")
        
        result = {
            'success': False,
            'instance_name': instance_name,
            'instance_id': instance_id,
            'operation': 'stop',
            'error': None,
            'duration_seconds': 0
        }
        
        try:
            # Stop the instance
            logger.info(f"Stopping ECS instance {instance_id}")
            stop_success = self.cloud_api.batch_stop_ecs_instances(project_id, [instance_id])
            
            if not stop_success:
                error_msg = "Failed to stop ECS instance"
                logger.error(error_msg)
                result['error'] = error_msg
                await telegram_notifier.send_ecs_instance_operation_notification(
                    instance_name, instance_id, 'stop', 'failed', result
                )
                return result
            
            # Wait a bit for instance to stop
            logger.info("Waiting for ECS instance to stop...")
            time.sleep(30)  # Give some time for instance to stop
            
            result['success'] = True
            result['duration_seconds'] = int(time.time() - start_time)
            
            logger.info(f"Successfully stopped ECS instance {instance_name} in {result['duration_seconds']} seconds")
            
            await telegram_notifier.send_ecs_instance_operation_notification(
                instance_name, instance_id, 'stop', 'success', result
            )
            
            # Schedule verification after delay
            self._schedule_verification(instance_config, 'stop', 'SHUTOFF')
        
        except Exception as e:
            error_msg = f"Unexpected error during instance stop: {str(e)}"
            logger.error(error_msg, exc_info=True)
            result['error'] = error_msg
            result['duration_seconds'] = int(time.time() - start_time)
            
            await telegram_notifier.send_ecs_instance_operation_notification(
                instance_name, instance_id, 'stop', 'failed', result
            )
        
        return result
    
    async def start_instance(self, instance_config: ECSInstanceConfig) -> Dict[str, Any]:
        """Start an ECS instance"""
        start_time = time.time()
        instance_name = instance_config.name
        instance_id = instance_config.instance_id
        project_id = instance_config.project_id
        
        logger.info(f"Starting start process for ECS instance: {instance_name} ({instance_id})")
        
        result = {
            'success': False,
            'instance_name': instance_name,
            'instance_id': instance_id,
            'operation': 'start',
            'error': None,
            'duration_seconds': 0
        }
        
        try:
            # Start the instance
            logger.info(f"Starting ECS instance {instance_id}")
            start_success = self.cloud_api.batch_start_ecs_instances(project_id, [instance_id])
            
            if not start_success:
                error_msg = "Failed to start ECS instance"
                logger.error(error_msg)
                result['error'] = error_msg
                await telegram_notifier.send_ecs_instance_operation_notification(
                    instance_name, instance_id, 'start', 'failed', result
                )
                return result
            
            # Wait a bit for instance to start
            logger.info("Waiting for ECS instance to start...")
            time.sleep(30)
            
            result['success'] = True
            result['duration_seconds'] = int(time.time() - start_time)
            
            logger.info(f"Successfully started ECS instance {instance_name} in {result['duration_seconds']} seconds")
            
            await telegram_notifier.send_ecs_instance_operation_notification(
                instance_name, instance_id, 'start', 'success', result
            )
            
            # Schedule verification after delay
            self._schedule_verification(instance_config, 'start', 'ACTIVE')
        
        except Exception as e:
            error_msg = f"Unexpected error during instance start: {str(e)}"
            logger.error(error_msg, exc_info=True)
            result['error'] = error_msg
            result['duration_seconds'] = int(time.time() - start_time)
            
            await telegram_notifier.send_ecs_instance_operation_notification(
                instance_name, instance_id, 'start', 'failed', result
            )
        
        return result
    
    async def get_instance_status(self, instance_config: ECSInstanceConfig) -> Optional[Dict[str, Any]]:
        """Get ECS instance status"""
        try:
            status = self.cloud_api.get_ecs_instance_status(
                instance_config.project_id,
                instance_config.instance_id
            )
            return status
        except Exception as e:
            logger.error(f"Failed to get ECS instance status: {e}")
            return None
    
    def get_instance_by_id(self, instance_id: str) -> Optional[ECSInstanceConfig]:
        """Get ECS instance configuration by instance ID"""
        return config.get_ecs_instance_by_id(instance_id)
    
    def _schedule_verification(self, instance_config: ECSInstanceConfig, operation: str, expected_status: str):
        """Schedule verification of operation after delay"""
        def verify_after_delay():
            """Verify operation after configured delay"""
            time.sleep(config.operation_verification_delay)
            asyncio.run(self._verify_operation(instance_config, operation, expected_status))
        
        # Run verification in background thread
        verification_thread = threading.Thread(target=verify_after_delay, daemon=True)
        verification_thread.start()
        logger.info(f"Scheduled verification for {operation} operation on ECS instance {instance_config.name} "
                   f"after {config.operation_verification_delay} seconds")
    
    async def _verify_operation(self, instance_config: ECSInstanceConfig, operation: str, expected_status: str):
        """Verify that operation was successful by checking ECS instance status"""
        instance_name = instance_config.name
        instance_id = instance_config.instance_id
        project_id = instance_config.project_id
        
        logger.info(f"Verifying {operation} operation for ECS instance {instance_name}")
        
        # Get current ECS instance status
        instance_status_data = self.cloud_api.get_ecs_instance_status(project_id, instance_id)
        if not instance_status_data:
            logger.error(f"Failed to get ECS instance status for verification")
            await self._handle_verification_failure(instance_config, operation, expected_status,
                                                   "Failed to get ECS instance status", attempt=1)
            return
        
        # Extract status from ECS API response
        # ECS API returns server object with status field
        current_status = instance_status_data.get('server', {}).get('status', 'UNKNOWN')
        logger.info(f"ECS instance {instance_name} current status: {current_status}, expected: {expected_status}")
        
        # Check if status matches expected
        if current_status == expected_status:
            logger.info(f"Verification successful: ECS instance {instance_name} is in expected status {expected_status}")
            await telegram_notifier.send_ecs_instance_operation_notification(
                instance_name, instance_id, f"{operation}_verification", 'success',
                {'current_status': current_status, 'expected_status': expected_status}
            )
            return
        
        # Status doesn't match - need to retry
        logger.warning(f"Verification failed: ECS instance {instance_name} status is {current_status}, "
                      f"expected {expected_status}. Will retry operation.")
        
        await self._retry_operation(instance_config, operation, expected_status, current_status)
    
    async def _retry_operation(self, instance_config: ECSInstanceConfig, operation: str,
                              expected_status: str, current_status: str, attempt: int = 1):
        """Retry operation if verification failed"""
        instance_name = instance_config.name
        instance_id = instance_config.instance_id
        
        if attempt > config.operation_retry_attempts:
            error_msg = (f"Operation {operation} failed after {config.operation_retry_attempts} retry attempts. "
                        f"Current status: {current_status}, expected: {expected_status}")
            logger.error(error_msg)
            await telegram_notifier.send_ecs_instance_operation_notification(
                instance_name, instance_id, f"{operation}_retry", 'failed',
                {
                    'error': error_msg,
                    'attempts': attempt - 1,
                    'current_status': current_status,
                    'expected_status': expected_status
                }
            )
            return
        
        logger.info(f"Retrying {operation} operation for ECS instance {instance_name} "
                   f"(attempt {attempt}/{config.operation_retry_attempts})")
        
        # Send notification about retry
        await telegram_notifier.send_ecs_instance_operation_notification(
            instance_name, instance_id, f"{operation}_retry", 'in_progress',
            {
                'attempt': attempt,
                'max_attempts': config.operation_retry_attempts,
                'current_status': current_status,
                'expected_status': expected_status
            }
        )
        
        # Wait before retry
        await asyncio.sleep(config.operation_retry_delay)
        
        # Retry the operation
        if operation == 'stop':
            result = await self.stop_instance(instance_config)
        elif operation == 'start':
            result = await self.start_instance(instance_config)
        else:
            logger.error(f"Unknown operation: {operation}")
            return
        
        # If retry was successful, schedule verification again
        if result.get('success'):
            logger.info(f"Retry {attempt} successful for {operation} operation on ECS instance {instance_name}")
            # Schedule verification again
            self._schedule_verification(instance_config, operation, expected_status)
        else:
            # Retry failed - try again if attempts left
            logger.warning(f"Retry {attempt} failed for {operation} operation on ECS instance {instance_name}")
            await self._retry_operation(instance_config, operation, expected_status, current_status, attempt + 1)
    
    async def _handle_verification_failure(self, instance_config: ECSInstanceConfig, operation: str,
                                          expected_status: str, error_msg: str, attempt: int = 1):
        """Handle verification failure"""
        await self._retry_operation(instance_config, operation, expected_status, 'UNKNOWN', attempt)

# Global ECS Instance Manager instance
ecs_instance_manager = ECSInstanceManager()

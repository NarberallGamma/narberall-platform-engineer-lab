#!/usr/bin/env python3
"""
Cluster Manager module for CCE/ECS Cluster Hibernate/Awake Management
Handles cluster operations with worker nodes management
"""

import time
import asyncio
from typing import Optional, Dict, Any, List
from datetime import datetime
from config import config, ClusterConfig
from cloud_api import cloud_api
from logger import logger
from telegram_notifier import telegram_notifier
import threading

class ClusterManager:
    """Manages cluster hibernation and wake-up operations"""
    
    def __init__(self):
        """Initialize Cluster Manager"""
        self.cloud_api = cloud_api
    
    async def hibernate_cluster(self, cluster_config: ClusterConfig) -> Dict[str, Any]:
        """Hibernate a cluster and its worker nodes"""
        start_time = time.time()
        cluster_name = cluster_config.name
        cluster_id = cluster_config.cluster_id
        project_id = cluster_config.project_id
        
        logger.info(f"Starting hibernation process for cluster: {cluster_name} ({cluster_id})")
        
        result = {
            'success': False,
            'cluster_name': cluster_name,
            'cluster_id': cluster_id,
            'operation': 'hibernate',
            'worker_nodes_count': 0,
            'worker_nodes_processed': 0,
            'cluster_status': 'unknown',
            'error': None,
            'duration_seconds': 0
        }
        
        try:
            # Step 1: Get worker nodes ECS IDs
            logger.info("Step 1: Getting worker nodes ECS instance IDs")
            worker_ecs_ids = self.cloud_api.get_worker_nodes_ecs_ids(project_id, cluster_id)
            result['worker_nodes_count'] = len(worker_ecs_ids)
            
            if worker_ecs_ids:
                logger.info(f"Found {len(worker_ecs_ids)} worker nodes to stop")
                
                # Step 2: Stop worker nodes first
                logger.info("Step 2: Stopping worker nodes")
                stop_success = self.cloud_api.batch_stop_ecs_instances(project_id, worker_ecs_ids)
                
                if not stop_success:
                    error_msg = "Failed to stop worker nodes"
                    logger.error(error_msg)
                    result['error'] = error_msg
                    await telegram_notifier.send_cluster_operation_notification(
                        cluster_name, cluster_id, 'hibernate', 'failed', result
                    )
                    return result
                
                # Wait for worker nodes to stop
                logger.info("Waiting for worker nodes to stop...")
                # Note: We don't have a direct way to check ECS status in batch, so we wait a bit
                time.sleep(30)  # Give some time for instances to stop
                result['worker_nodes_processed'] = len(worker_ecs_ids)
            
            # Step 3: Hibernate cluster (master nodes)
            logger.info("Step 3: Hibernating cluster (master nodes)")
            hibernate_success = self.cloud_api.hibernate_cluster(project_id, cluster_id)
            
            if not hibernate_success:
                error_msg = "Failed to hibernate cluster"
                logger.error(error_msg)
                result['error'] = error_msg
                await telegram_notifier.send_cluster_operation_notification(
                    cluster_name, cluster_id, 'hibernate', 'failed', result
                )
                return result
            
            # Step 4: Wait for cluster to reach Hibernation status
            logger.info("Step 4: Waiting for cluster to reach Hibernation status")
            status_reached = self.cloud_api.wait_for_cluster_status(
                project_id, cluster_id, 'Hibernation'
            )
            
            if status_reached:
                cluster_status = self.cloud_api.get_cluster_status(project_id, cluster_id)
                if cluster_status:
                    result['cluster_status'] = cluster_status.get('status', {}).get('phase', 'Unknown')
                
                result['success'] = True
                result['duration_seconds'] = int(time.time() - start_time)
                
                logger.info(f"Successfully hibernated cluster {cluster_name} in {result['duration_seconds']} seconds")
                
                await telegram_notifier.send_cluster_operation_notification(
                    cluster_name, cluster_id, 'hibernate', 'success', result
                )
                
                # Schedule verification after delay
                self._schedule_verification(cluster_config, 'hibernate', 'Hibernation')
            else:
                error_msg = "Cluster did not reach Hibernation status within timeout"
                logger.error(error_msg)
                result['error'] = error_msg
                await telegram_notifier.send_cluster_operation_notification(
                    cluster_name, cluster_id, 'hibernate', 'failed', result
                )
        
        except Exception as e:
            error_msg = f"Unexpected error during hibernation: {str(e)}"
            logger.error(error_msg, exc_info=True)
            result['error'] = error_msg
            result['duration_seconds'] = int(time.time() - start_time)
            
            await telegram_notifier.send_cluster_operation_notification(
                cluster_name, cluster_id, 'hibernate', 'failed', result
            )
        
        return result
    
    async def awake_cluster(self, cluster_config: ClusterConfig) -> Dict[str, Any]:
        """Wake up a cluster and its worker nodes"""
        start_time = time.time()
        cluster_name = cluster_config.name
        cluster_id = cluster_config.cluster_id
        project_id = cluster_config.project_id
        wake_up_delay = cluster_config.wake_up_delay_minutes * 60  # Convert to seconds
        
        logger.info(f"Starting wake-up process for cluster: {cluster_name} ({cluster_id})")
        
        result = {
            'success': False,
            'cluster_name': cluster_name,
            'cluster_id': cluster_id,
            'operation': 'awake',
            'worker_nodes_count': 0,
            'worker_nodes_processed': 0,
            'cluster_status': 'unknown',
            'error': None,
            'duration_seconds': 0
        }
        
        try:
            # Step 0: Check current cluster status - skip if already Available
            logger.info("Step 0: Checking current cluster status")
            cluster_status_data = self.cloud_api.get_cluster_status(project_id, cluster_id)
            if cluster_status_data:
                current_status = cluster_status_data.get('status', {}).get('phase', 'Unknown')
                result['cluster_status'] = current_status
                logger.info(f"Cluster {cluster_name} current status: {current_status}")
                
                if current_status == 'Available':
                    logger.info(f"Cluster {cluster_name} is already in Available status, skipping wake-up")
                    result['success'] = True
                    result['duration_seconds'] = 0
                    # Don't send notification for skipped operations - this is normal behavior
                    return result
            
            # Step 1: Wake up cluster (master nodes)
            logger.info("Step 1: Waking up cluster (master nodes)")
            awake_success = self.cloud_api.awake_cluster(project_id, cluster_id)
            
            if not awake_success:
                error_msg = "Failed to wake up cluster"
                logger.error(error_msg)
                result['error'] = error_msg
                await telegram_notifier.send_cluster_operation_notification(
                    cluster_name, cluster_id, 'awake', 'failed', result
                )
                return result
            
            # Step 2: Wait for cluster to reach Available status
            logger.info("Step 2: Waiting for cluster to reach Available status")
            status_reached = self.cloud_api.wait_for_cluster_status(
                project_id, cluster_id, 'Available'
            )
            
            if not status_reached:
                error_msg = "Cluster did not reach Available status within timeout"
                logger.error(error_msg)
                result['error'] = error_msg
                await telegram_notifier.send_cluster_operation_notification(
                    cluster_name, cluster_id, 'awake', 'failed', result
                )
                return result
            
            cluster_status = self.cloud_api.get_cluster_status(project_id, cluster_id)
            if cluster_status:
                result['cluster_status'] = cluster_status.get('status', {}).get('phase', 'Unknown')
            
            # Step 3: Wait for delay before starting worker nodes
            logger.info(f"Step 3: Waiting {wake_up_delay} seconds before starting worker nodes (to allow master nodes to fully start)")
            time.sleep(wake_up_delay)
            
            # Step 4: Get worker nodes ECS IDs
            logger.info("Step 4: Getting worker nodes ECS instance IDs")
            worker_ecs_ids = self.cloud_api.get_worker_nodes_ecs_ids(project_id, cluster_id)
            result['worker_nodes_count'] = len(worker_ecs_ids)
            
            if worker_ecs_ids:
                logger.info(f"Found {len(worker_ecs_ids)} worker nodes to start")
                
                # Step 5: Start worker nodes
                logger.info("Step 5: Starting worker nodes")
                start_success = self.cloud_api.batch_start_ecs_instances(project_id, worker_ecs_ids)
                
                if not start_success:
                    error_msg = "Failed to start worker nodes"
                    logger.error(error_msg)
                    result['error'] = error_msg
                    await telegram_notifier.send_cluster_operation_notification(
                        cluster_name, cluster_id, 'awake', 'failed', result
                    )
                    return result
                
                # Wait a bit for instances to start
                time.sleep(30)
                result['worker_nodes_processed'] = len(worker_ecs_ids)
            
            result['success'] = True
            result['duration_seconds'] = int(time.time() - start_time)
            
            logger.info(f"Successfully woke up cluster {cluster_name} in {result['duration_seconds']} seconds")
            
            await telegram_notifier.send_cluster_operation_notification(
                cluster_name, cluster_id, 'awake', 'success', result
            )
            
            # Schedule verification after delay
            self._schedule_verification(cluster_config, 'awake', 'Available')
        
        except Exception as e:
            error_msg = f"Unexpected error during wake-up: {str(e)}"
            logger.error(error_msg, exc_info=True)
            result['error'] = error_msg
            result['duration_seconds'] = int(time.time() - start_time)
            
            await telegram_notifier.send_cluster_operation_notification(
                cluster_name, cluster_id, 'awake', 'failed', result
            )
        
        return result
    
    async def get_cluster_status(self, cluster_config: ClusterConfig) -> Optional[Dict[str, Any]]:
        """Get cluster status"""
        try:
            status = self.cloud_api.get_cluster_status(
                cluster_config.project_id,
                cluster_config.cluster_id
            )
            return status
        except Exception as e:
            logger.error(f"Failed to get cluster status: {e}")
            return None
    
    def get_cluster_by_id(self, cluster_id: str) -> Optional[ClusterConfig]:
        """Get cluster configuration by cluster ID"""
        return config.get_cluster_by_id(cluster_id)
    
    def _schedule_verification(self, cluster_config: ClusterConfig, operation: str, expected_status: str):
        """Schedule verification of operation after delay"""
        def verify_after_delay():
            """Verify operation after configured delay"""
            time.sleep(config.operation_verification_delay)
            asyncio.run(self._verify_operation(cluster_config, operation, expected_status))
        
        # Run verification in background thread
        verification_thread = threading.Thread(target=verify_after_delay, daemon=True)
        verification_thread.start()
        logger.info(f"Scheduled verification for {operation} operation on cluster {cluster_config.name} "
                   f"after {config.operation_verification_delay} seconds")
    
    async def _verify_operation(self, cluster_config: ClusterConfig, operation: str, expected_status: str):
        """Verify that operation was successful by checking cluster status"""
        cluster_name = cluster_config.name
        cluster_id = cluster_config.cluster_id
        project_id = cluster_config.project_id
        
        logger.info(f"Verifying {operation} operation for cluster {cluster_name}")
        
        # Get current cluster status
        cluster_status_data = self.cloud_api.get_cluster_status(project_id, cluster_id)
        if not cluster_status_data:
            logger.error(f"Failed to get cluster status for verification")
            await self._handle_verification_failure(cluster_config, operation, expected_status, 
                                                   "Failed to get cluster status", attempt=1)
            return
        
        current_status = cluster_status_data.get('status', {}).get('phase', 'Unknown')
        logger.info(f"Cluster {cluster_name} current status: {current_status}, expected: {expected_status}")
        
        # Check if status matches expected
        if current_status == expected_status:
            logger.info(f"Verification successful: cluster {cluster_name} is in expected status {expected_status}")
            await telegram_notifier.send_cluster_operation_notification(
                cluster_name, cluster_id, f"{operation}_verification", 'success',
                {'current_status': current_status, 'expected_status': expected_status}
            )
            return
        
        # Status doesn't match - need to retry
        logger.warning(f"Verification failed: cluster {cluster_name} status is {current_status}, "
                      f"expected {expected_status}. Will retry operation.")
        
        await self._retry_operation(cluster_config, operation, expected_status, current_status)
    
    async def _retry_operation(self, cluster_config: ClusterConfig, operation: str, 
                              expected_status: str, current_status: str, attempt: int = 1):
        """Retry operation if verification failed"""
        cluster_name = cluster_config.name
        cluster_id = cluster_config.cluster_id
        
        if attempt > config.operation_retry_attempts:
            error_msg = (f"Operation {operation} failed after {config.operation_retry_attempts} retry attempts. "
                        f"Current status: {current_status}, expected: {expected_status}")
            logger.error(error_msg)
            await telegram_notifier.send_cluster_operation_notification(
                cluster_name, cluster_id, f"{operation}_retry", 'failed',
                {
                    'error': error_msg,
                    'attempts': attempt - 1,
                    'current_status': current_status,
                    'expected_status': expected_status
                }
            )
            return
        
        logger.info(f"Retrying {operation} operation for cluster {cluster_name} (attempt {attempt}/{config.operation_retry_attempts})")
        
        # Send notification about retry
        await telegram_notifier.send_cluster_operation_notification(
            cluster_name, cluster_id, f"{operation}_retry", 'in_progress',
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
        if operation == 'hibernate':
            result = await self.hibernate_cluster(cluster_config)
        elif operation == 'awake':
            result = await self.awake_cluster(cluster_config)
        else:
            logger.error(f"Unknown operation: {operation}")
            return
        
        # If retry was successful, schedule verification again
        if result.get('success'):
            logger.info(f"Retry {attempt} successful for {operation} operation on cluster {cluster_name}")
            # Schedule verification again
            self._schedule_verification(cluster_config, operation, expected_status)
        else:
            # Retry failed - try again if attempts left
            logger.warning(f"Retry {attempt} failed for {operation} operation on cluster {cluster_name}")
            await self._retry_operation(cluster_config, operation, expected_status, current_status, attempt + 1)
    
    async def _handle_verification_failure(self, cluster_config: ClusterConfig, operation: str,
                                          expected_status: str, error_msg: str, attempt: int = 1):
        """Handle verification failure"""
        await self._retry_operation(cluster_config, operation, expected_status, 'Unknown', attempt)

# Global Cluster Manager instance
cluster_manager = ClusterManager()

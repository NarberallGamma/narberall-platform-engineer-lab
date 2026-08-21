#!/usr/bin/env python3
"""
Cloud API module for CCE/ECS Cluster Hibernate/Awake Management
Handles IAM authentication, CCE cluster operations, and ECS instance management
"""

import time
import requests
from typing import Optional, Dict, Any, List
from config import config
from logger import logger

class CloudAPI:
    """Cloud API client for Huawei Cloud / cloud provider"""
    
    def __init__(self):
        """Initialize Cloud API client"""
        self.token: Optional[str] = None
        self.token_expires_at: Optional[float] = None
        self.session = requests.Session()
        self.session.verify = config.verify_ssl
    
    def get_auth_token(self, force_refresh: bool = False) -> str:
        """Obtain authentication token from IAM API"""
        # Check if we have a valid cached token
        if not force_refresh and self.token and self.token_expires_at:
            current_time = time.time()
            # Check if token is still valid and not close to expiration
            if current_time < self.token_expires_at:
                # Refresh proactively if close to expiration (based on config)
                refresh_threshold = self.token_expires_at - config.iam_token_refresh_interval
                if current_time < refresh_threshold:
                    logger.debug("Using cached authentication token")
                    return self.token
                else:
                    logger.info(f"Token expires soon (in {int(self.token_expires_at - current_time)}s), refreshing proactively")
        
        # Use password authentication
        logger.info("Obtaining new authentication token from IAM using password")
        auth_data = self._build_password_auth_data()
        
        headers = {
            'Content-Type': 'application/json;charset=utf8'
        }
        
        try:
            response = self.session.post(
                config.iam_url,
                json=auth_data,
                headers=headers,
                timeout=config.request_timeout
            )
            response.raise_for_status()
            
            # Extract token from response header
            self.token = response.headers.get('X-Subject-Token')
            if not self.token:
                raise ValueError("X-Subject-Token not found in response headers")
            
            # Parse token expiration (usually 24 hours, but we'll use 23 for safety)
            self.token_expires_at = time.time() + (23 * 3600)
            
            logger.info("Successfully obtained authentication token")
            return self.token
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to obtain authentication token: {e}")
            if hasattr(e, 'response') and e.response is not None:
                logger.error(f"Response status: {e.response.status_code}")
                logger.error(f"Response body: {e.response.text}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error obtaining token: {e}")
            raise
    
    def _build_password_auth_data(self) -> Dict[str, Any]:
        """Build authentication data for password-based authentication"""
        return {
            "auth": {
                "identity": {
                    "methods": ["password"],
                    "password": {
                        "user": {
                            "name": config.iam_username,
                            "password": config.iam_password,
                            "domain": {
                                "name": config.iam_domain_name
                            }
                        }
                    }
                },
                "scope": {
                    "project": {
                        "name": config.iam_project_name
                    }
                }
            }
        }
    
    def _get_headers(self) -> Dict[str, str]:
        """Get request headers with authentication token"""
        token = self.get_auth_token()
        return {
            'Content-Type': 'application/json',
            'X-Auth-Token': token
        }
    
    def hibernate_cluster(self, project_id: str, cluster_id: str) -> bool:
        """Hibernate a CCE cluster"""
        logger.info(f"Starting hibernation for cluster {cluster_id}")
        
        url = f"{config.cce_base_url}/api/v3/projects/{project_id}/clusters/{cluster_id}/operation/hibernate"
        headers = self._get_headers()
        
        for attempt in range(1, config.max_retries + 1):
            try:
                logger.info(f"Hibernation attempt {attempt}/{config.max_retries}")
                response = self.session.post(
                    url,
                    headers=headers,
                    timeout=config.request_timeout
                )
                response.raise_for_status()
                
                logger.info(f"Successfully initiated hibernation for cluster {cluster_id}")
                logger.info("Note: Keep querying the cluster status. When status changes to 'Hibernation', the cluster is hibernated.")
                return True
                
            except requests.exceptions.RequestException as e:
                logger.warning(f"Hibernation attempt {attempt} failed: {e}")
                if hasattr(e, 'response') and e.response is not None:
                    logger.warning(f"Response status: {e.response.status_code}")
                    logger.warning(f"Response body: {e.response.text}")
                
                if attempt < config.max_retries:
                    logger.info(f"Retrying in {config.retry_delay} seconds...")
                    time.sleep(config.retry_delay)
                else:
                    logger.error(f"Failed to hibernate cluster after {config.max_retries} attempts")
                    return False
        
        return False
    
    def awake_cluster(self, project_id: str, cluster_id: str) -> bool:
        """Wake up a hibernated CCE cluster"""
        logger.info(f"Starting wake-up for cluster {cluster_id}")
        
        url = f"{config.cce_base_url}/api/v3/projects/{project_id}/clusters/{cluster_id}/operation/awake"
        headers = self._get_headers()
        
        for attempt in range(1, config.max_retries + 1):
            try:
                logger.info(f"Wake-up attempt {attempt}/{config.max_retries}")
                response = self.session.post(
                    url,
                    headers=headers,
                    timeout=config.request_timeout
                )
                response.raise_for_status()
                
                logger.info(f"Successfully initiated wake-up for cluster {cluster_id}")
                logger.info("Note: Keep querying the cluster status. When status changes to 'Available', the cluster is woken up.")
                return True
                
            except requests.exceptions.RequestException as e:
                logger.warning(f"Wake-up attempt {attempt} failed: {e}")
                if hasattr(e, 'response') and e.response is not None:
                    logger.warning(f"Response status: {e.response.status_code}")
                    logger.warning(f"Response body: {e.response.text}")
                
                if attempt < config.max_retries:
                    logger.info(f"Retrying in {config.retry_delay} seconds...")
                    time.sleep(config.retry_delay)
                else:
                    logger.error(f"Failed to wake up cluster after {config.max_retries} attempts")
                    return False
        
        return False
    
    def get_cluster_status(self, project_id: str, cluster_id: str) -> Optional[Dict[str, Any]]:
        """Get current cluster status"""
        url = f"{config.cce_base_url}/api/v3/projects/{project_id}/clusters/{cluster_id}"
        headers = self._get_headers()
        
        try:
            response = self.session.get(
                url,
                headers=headers,
                timeout=config.request_timeout
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get cluster status: {e}")
            if hasattr(e, 'response') and e.response is not None:
                logger.error(f"Response status: {e.response.status_code}")
                logger.error(f"Response body: {e.response.text}")
            return None
    
    def get_cluster_nodes(self, project_id: str, cluster_id: str) -> List[Dict[str, Any]]:
        """Get list of cluster nodes (including worker nodes with ECS instance IDs)"""
        url = f"{config.cce_base_url}/api/v3/projects/{project_id}/clusters/{cluster_id}/nodes"
        headers = self._get_headers()
        
        try:
            response = self.session.get(
                url,
                headers=headers,
                timeout=config.request_timeout
            )
            response.raise_for_status()
            result = response.json()
            
            # Extract nodes from response
            nodes = result.get('items', [])
            logger.info(f"Found {len(nodes)} nodes in cluster {cluster_id}")
            return nodes
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get cluster nodes: {e}")
            if hasattr(e, 'response') and e.response is not None:
                logger.error(f"Response status: {e.response.status_code}")
                logger.error(f"Response body: {e.response.text}")
            return []
    
    def get_worker_nodes_ecs_ids(self, project_id: str, cluster_id: str) -> List[str]:
        """Get ECS instance IDs of worker nodes"""
        nodes = self.get_cluster_nodes(project_id, cluster_id)
        ecs_ids = []
        
        for node in nodes:
            # Worker nodes typically have spec.kind == "Node" and spec.type == "VM"
            # ECS instance ID is usually in spec.serverId or status.serverId
            node_kind = node.get('kind', '')
            if node_kind == 'Node':
                # Try different possible fields for ECS instance ID
                server_id = (
                    node.get('spec', {}).get('serverId') or
                    node.get('status', {}).get('serverId') or
                    node.get('spec', {}).get('ecsInstanceId') or
                    node.get('status', {}).get('ecsInstanceId')
                )
                if server_id:
                    ecs_ids.append(server_id)
                    logger.debug(f"Found worker node ECS ID: {server_id}")
        
        logger.info(f"Found {len(ecs_ids)} worker node ECS instances")
        return ecs_ids
    
    def batch_stop_ecs_instances(self, project_id: str, ecs_instance_ids: List[str]) -> bool:
        """Stop ECS instances in batch"""
        if not ecs_instance_ids:
            logger.warning("No ECS instance IDs provided for batch stop")
            return True
        
        logger.info(f"Stopping {len(ecs_instance_ids)} ECS instances")
        
        url = f"{config.ecs_base_url}/v1/{project_id}/cloudservers/action"
        headers = self._get_headers()
        
        # Prepare request body for batch stop
        body = {
            "os-stop": {
                "type": "SOFT",  # SOFT for graceful shutdown, HARD for force shutdown
                "servers": [{"id": ecs_id} for ecs_id in ecs_instance_ids]
            }
        }
        
        try:
            response = self.session.post(
                url,
                json=body,
                headers=headers,
                timeout=config.request_timeout
            )
            response.raise_for_status()
            
            logger.info(f"Successfully initiated batch stop for {len(ecs_instance_ids)} ECS instances")
            return True
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to batch stop ECS instances: {e}")
            if hasattr(e, 'response') and e.response is not None:
                logger.error(f"Response status: {e.response.status_code}")
                logger.error(f"Response body: {e.response.text}")
            return False
    
    def batch_start_ecs_instances(self, project_id: str, ecs_instance_ids: List[str]) -> bool:
        """Start ECS instances in batch"""
        if not ecs_instance_ids:
            logger.warning("No ECS instance IDs provided for batch start")
            return True
        
        logger.info(f"Starting {len(ecs_instance_ids)} ECS instances")
        
        url = f"{config.ecs_base_url}/v1/{project_id}/cloudservers/action"
        headers = self._get_headers()
        
        # Prepare request body for batch start
        body = {
            "os-start": {
                "servers": [{"id": ecs_id} for ecs_id in ecs_instance_ids]
            }
        }
        
        try:
            response = self.session.post(
                url,
                json=body,
                headers=headers,
                timeout=config.request_timeout
            )
            response.raise_for_status()
            
            logger.info(f"Successfully initiated batch start for {len(ecs_instance_ids)} ECS instances")
            return True
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to batch start ECS instances: {e}")
            if hasattr(e, 'response') and e.response is not None:
                logger.error(f"Response status: {e.response.status_code}")
                logger.error(f"Response body: {e.response.text}")
            return False
    
    def get_ecs_instance_status(self, project_id: str, ecs_instance_id: str) -> Optional[Dict[str, Any]]:
        """Get ECS instance status"""
        url = f"{config.ecs_base_url}/v1/{project_id}/cloudservers/{ecs_instance_id}"
        headers = self._get_headers()
        
        try:
            response = self.session.get(
                url,
                headers=headers,
                timeout=config.request_timeout
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get ECS instance status: {e}")
            return None
    
    def wait_for_cluster_status(self,
                                project_id: str,
                                cluster_id: str,
                                target_status: str,
                                timeout: Optional[int] = None) -> bool:
        """Wait for cluster to reach target status"""
        if timeout is None:
            timeout = config.cluster_status_max_wait
        
        start_time = time.time()
        logger.info(f"Waiting for cluster {cluster_id} to reach status '{target_status}' (timeout: {timeout}s)")
        
        while time.time() - start_time < timeout:
            status_data = self.get_cluster_status(project_id, cluster_id)
            if status_data:
                current_status = status_data.get('status', {}).get('phase', 'Unknown')
                logger.debug(f"Cluster status: {current_status} (target: {target_status})")
                
                if current_status == target_status:
                    logger.info(f"Cluster {cluster_id} reached target status '{target_status}'")
                    return True
            
            time.sleep(config.cluster_status_poll_interval)
        
        logger.warning(f"Timeout waiting for cluster {cluster_id} to reach status '{target_status}'")
        return False
    
    def check_api_health(self) -> Dict[str, bool]:
        """Check health of all APIs"""
        health_status = {
            'iam': False,
            'cce': False,
            'ecs': False
        }
        
        # Check IAM (use cached token, don't force refresh)
        try:
            token = self.get_auth_token(force_refresh=False)
            health_status['iam'] = bool(token)
        except Exception as e:
            logger.error(f"IAM health check failed: {e}")
        
        # Check CCE (try to get cluster status for first cluster)
        if config.clusters:
            try:
                cluster = config.clusters[0]
                status = self.get_cluster_status(cluster.project_id, cluster.cluster_id)
                health_status['cce'] = status is not None
            except Exception as e:
                logger.error(f"CCE health check failed: {e}")
        
        # Check ECS (we can't easily test without instance ID, so we'll just check if we can get token)
        health_status['ecs'] = health_status['iam']  # ECS uses same auth
        
        return health_status

# Global Cloud API instance
cloud_api = CloudAPI()

#!/usr/bin/env python3
"""
REST API Server for CCE/ECS Cluster Hibernate/Awake Management
Provides on-demand API for cluster operations
"""

import asyncio
import os
import json
from flask import Flask, request, jsonify, send_from_directory, Response
from flask_cors import CORS
from typing import Dict, Any
from config import config
from logger import logger
from cluster_manager import cluster_manager
from ecs_instance_manager import ecs_instance_manager
from cloud_api import cloud_api
from schedule_manager import schedule_manager

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

def mask_api_key(api_key: str) -> str:
    """Mask API key for logging (show first 8 and last 4 characters)"""
    if not api_key or len(api_key) < 12:
        return "***"
    return f"{api_key[:8]}...{api_key[-4:]}"

def get_client_ip() -> str:
    """Get client IP address, considering X-Forwarded-For header"""
    # Check X-Forwarded-For first (if behind proxy)
    forwarded_for = request.headers.get('X-Forwarded-For')
    if forwarded_for:
        # X-Forwarded-For can contain multiple IPs, take the first one
        return forwarded_for.split(',')[0].strip()
    
    # Fallback to remote_addr
    return request.remote_addr or 'unknown'

def check_ip_whitelist() -> tuple[bool, str]:
    """
    Check if client IP is in whitelist
    Returns: (is_allowed, error_message)
    """
    if not config.api_ip_whitelist_enabled:
        return True, ""
    
    client_ip = get_client_ip()
    
    if not config.is_ip_allowed(client_ip):
        logger.warning(f"Unauthorized API access attempt from IP {client_ip} (not in whitelist): {request.method} {request.path}")
        return False, f"IP address not allowed: {client_ip}"
    
    return True, ""

def check_api_key() -> tuple[bool, str, str]:
    """
    Check if API key is present and valid
    Returns: (is_valid, error_message, api_key)
    """
    if not config.api_auth_enabled:
        return True, "", ""
    
    api_key = request.headers.get(config.api_key_header, '')
    
    if not api_key:
        logger.warning(f"API request without key from IP {get_client_ip()}: {request.method} {request.path}")
        return False, f"API key required (header: {config.api_key_header})", ""
    
    if api_key not in config.api_keys:
        masked_key = mask_api_key(api_key)
        logger.warning(f"Invalid API key attempt from IP {get_client_ip()} (key: {masked_key}): {request.method} {request.path}")
        return False, "Invalid API key", api_key
    
    return True, "", api_key

@app.before_request
def require_authentication():
    """
    Middleware to check IP whitelist and API key for all requests
    Exceptions: 
    - /health endpoint (for health checks)
    - /api/swagger and /api/swagger.json (Swagger UI - accessible without key, but requests require key)
    """
    # Skip authentication for health check endpoint
    if request.path == '/health':
        return None
    
    # Swagger UI endpoints - check IP whitelist but skip API key (UI itself is accessible, but requests need key)
    if request.path == config.swagger_ui_endpoint or request.path == config.swagger_endpoint:
        # Check IP whitelist for Swagger UI access
        if config.api_ip_whitelist_enabled:
            ip_allowed, ip_error = check_ip_whitelist()
            if not ip_allowed:
                return jsonify({
                    'error': ip_error,
                    'ip': get_client_ip()
                }), 403
        # Skip API key check for Swagger UI/JSON endpoints (UI is accessible, but requests through UI need key)
        return None
    
    # Check IP whitelist first
    if config.api_ip_whitelist_enabled:
        ip_allowed, ip_error = check_ip_whitelist()
        if not ip_allowed:
            return jsonify({
                'error': ip_error,
                'ip': get_client_ip()
            }), 403
    
    # Check API key
    api_key = ""
    if config.api_auth_enabled:
        key_valid, key_error, api_key = check_api_key()
        if not key_valid:
            return jsonify({
                'error': key_error,
                'header': config.api_key_header
            }), 401
    
    # Log successful request (if authentication is enabled)
    if config.api_auth_enabled or config.api_ip_whitelist_enabled:
        client_ip = get_client_ip()
        masked_key = mask_api_key(api_key) if api_key else "N/A"
        logger.info(f"API request: {request.method} {request.path} from IP {client_ip} (API Key: {masked_key})")
    
    return None

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'app_name': config.app_name,
        'app_version': config.app_version
    }), 200

@app.route('/api/health', methods=['GET'])
def api_health_check():
    """API health check endpoint - checks cloud APIs"""
    try:
        health_status = cloud_api.check_api_health()
        all_healthy = all(health_status.values())
        
        return jsonify({
            'status': 'healthy' if all_healthy else 'degraded',
            'apis': health_status,
            'app_name': config.app_name,
            'app_version': config.app_version
        }), 200 if all_healthy else 503
    except Exception as e:
        logger.error(f"API health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 503

@app.route('/api/clusters', methods=['GET'])
def list_clusters():
    """List all configured clusters"""
    clusters_info = []
    for cluster in config.clusters:
        clusters_info.append({
            'cluster_id': cluster.cluster_id,
            'name': cluster.name,
            'project_id': cluster.project_id,
            'hibernate_schedule': cluster.hibernate_schedule,
            'wake_up_delay_minutes': cluster.wake_up_delay_minutes
        })
    
    return jsonify({
        'clusters': clusters_info,
        'count': len(clusters_info)
    }), 200

@app.route('/api/clusters/<cluster_id>/status', methods=['GET'])
def get_cluster_status(cluster_id: str):
    """Get cluster status"""
    cluster = cluster_manager.get_cluster_by_id(cluster_id)
    if not cluster:
        return jsonify({'error': f'Cluster {cluster_id} not found'}), 404
    
    try:
        status = asyncio.run(cluster_manager.get_cluster_status(cluster))
        if status:
            return jsonify({
                'cluster_id': cluster_id,
                'cluster_name': cluster.name,
                'status': status
            }), 200
        else:
            return jsonify({
                'error': 'Failed to get cluster status'
            }), 500
    except Exception as e:
        logger.error(f"Error getting cluster status: {e}")
        return jsonify({
            'error': str(e)
        }), 500

@app.route('/api/clusters/<cluster_id>/hibernate', methods=['POST'])
def hibernate_cluster(cluster_id: str):
    """Hibernate a cluster on-demand (sets schedule override)"""
    cluster = cluster_manager.get_cluster_by_id(cluster_id)
    if not cluster:
        return jsonify({'error': f'Cluster {cluster_id} not found'}), 404
    
    try:
        logger.info(f"On-demand hibernation requested for cluster: {cluster.name}")
        
        # Set schedule override to ignore schedule for configured duration
        override_duration = config.schedule_override_duration_hours
        schedule_manager.set_schedule_override(
            cluster_id, 
            override_duration, 
            reason=f"Manual hibernation via API"
        )
        
        result = asyncio.run(cluster_manager.hibernate_cluster(cluster))
        
        if result['success']:
            return jsonify({
                'success': True,
                'message': f'Cluster {cluster.name} hibernation initiated successfully',
                'schedule_override': {
                    'enabled': True,
                    'duration_hours': override_duration,
                    'reason': 'Manual hibernation via API'
                },
                'result': result
            }), 200
        else:
            return jsonify({
                'success': False,
                'message': f'Failed to hibernate cluster {cluster.name}',
                'result': result
            }), 500
    except Exception as e:
        logger.error(f"Error hibernating cluster: {e}", exc_info=True)
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/clusters/<cluster_id>/awake', methods=['POST'])
def awake_cluster(cluster_id: str):
    """Wake up a cluster on-demand (sets schedule override)"""
    cluster = cluster_manager.get_cluster_by_id(cluster_id)
    if not cluster:
        return jsonify({'error': f'Cluster {cluster_id} not found'}), 404
    
    try:
        logger.info(f"On-demand wake-up requested for cluster: {cluster.name}")
        
        # Set schedule override to ignore schedule for configured duration
        override_duration = config.schedule_override_duration_hours
        schedule_manager.set_schedule_override(
            cluster_id, 
            override_duration, 
            reason=f"Manual wake-up via API"
        )
        
        result = asyncio.run(cluster_manager.awake_cluster(cluster))
        
        if result['success']:
            return jsonify({
                'success': True,
                'message': f'Cluster {cluster.name} wake-up initiated successfully',
                'schedule_override': {
                    'enabled': True,
                    'duration_hours': override_duration,
                    'reason': 'Manual wake-up via API'
                },
                'result': result
            }), 200
        else:
            return jsonify({
                'success': False,
                'message': f'Failed to wake up cluster {cluster.name}',
                'result': result
            }), 500
    except Exception as e:
        logger.error(f"Error waking up cluster: {e}", exc_info=True)
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/schedules', methods=['GET'])
def list_schedules():
    """List all scheduled jobs"""
    if not config.schedule_enabled:
        return jsonify({
            'schedules_enabled': False,
            'jobs': []
        }), 200
    
    jobs = schedule_manager.get_scheduled_jobs()
    return jsonify({
        'schedules_enabled': True,
        'jobs': jobs,
        'count': len(jobs)
    }), 200

@app.route('/api/instances', methods=['GET'])
def list_instances():
    """List all configured ECS instances"""
    instances_info = []
    for instance in config.ecs_instances:
        instances_info.append({
            'instance_id': instance.instance_id,
            'name': instance.name,
            'project_id': instance.project_id,
            'hibernate_schedule': instance.hibernate_schedule
        })
    
    return jsonify({
        'instances': instances_info,
        'count': len(instances_info)
    }), 200

@app.route('/api/instances/<instance_id>/status', methods=['GET'])
def get_instance_status(instance_id: str):
    """Get ECS instance status"""
    instance = ecs_instance_manager.get_instance_by_id(instance_id)
    if not instance:
        return jsonify({'error': f'ECS instance {instance_id} not found'}), 404
    
    try:
        status = asyncio.run(ecs_instance_manager.get_instance_status(instance))
        if status:
            return jsonify({
                'instance_id': instance_id,
                'instance_name': instance.name,
                'status': status
            }), 200
        else:
            return jsonify({
                'error': 'Failed to get ECS instance status'
            }), 500
    except Exception as e:
        logger.error(f"Error getting ECS instance status: {e}")
        return jsonify({
            'error': str(e)
        }), 500

@app.route('/api/instances/<instance_id>/stop', methods=['POST'])
def stop_instance(instance_id: str):
    """Stop an ECS instance on-demand"""
    instance = ecs_instance_manager.get_instance_by_id(instance_id)
    if not instance:
        return jsonify({'error': f'ECS instance {instance_id} not found'}), 404
    
    try:
        logger.info(f"On-demand stop requested for ECS instance: {instance.name}")
        result = asyncio.run(ecs_instance_manager.stop_instance(instance))
        
        if result['success']:
            return jsonify({
                'success': True,
                'message': f'ECS instance {instance.name} stop initiated successfully',
                'result': result
            }), 200
        else:
            return jsonify({
                'success': False,
                'message': f'Failed to stop ECS instance {instance.name}',
                'result': result
            }), 500
    except Exception as e:
        logger.error(f"Error stopping ECS instance: {e}", exc_info=True)
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/instances/<instance_id>/start', methods=['POST'])
def start_instance(instance_id: str):
    """Start an ECS instance on-demand"""
    instance = ecs_instance_manager.get_instance_by_id(instance_id)
    if not instance:
        return jsonify({'error': f'ECS instance {instance_id} not found'}), 404
    
    try:
        logger.info(f"On-demand start requested for ECS instance: {instance.name}")
        result = asyncio.run(ecs_instance_manager.start_instance(instance))
        
        if result['success']:
            return jsonify({
                'success': True,
                'message': f'ECS instance {instance.name} start initiated successfully',
                'result': result
            }), 200
        else:
            return jsonify({
                'success': False,
                'message': f'Failed to start ECS instance {instance.name}',
                'result': result
            }), 500
    except Exception as e:
        logger.error(f"Error starting ECS instance: {e}", exc_info=True)
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/clusters/<cluster_id>/override', methods=['GET'])
def get_schedule_override(cluster_id: str):
    """Get current schedule override status for a cluster"""
    cluster = cluster_manager.get_cluster_by_id(cluster_id)
    if not cluster:
        return jsonify({'error': f'Cluster {cluster_id} not found'}), 404
    
    override = schedule_manager.get_schedule_override(cluster_id)
    if override:
        return jsonify({
            'cluster_id': cluster_id,
            'cluster_name': cluster.name,
            'override': override
        }), 200
    else:
        return jsonify({
            'cluster_id': cluster_id,
            'cluster_name': cluster.name,
            'override': None,
            'message': 'No active schedule override'
        }), 200

@app.route('/api/clusters/<cluster_id>/override', methods=['POST'])
def set_schedule_override(cluster_id: str):
    """Set schedule override for a cluster (ignore schedule for specified duration)"""
    cluster = cluster_manager.get_cluster_by_id(cluster_id)
    if not cluster:
        return jsonify({'error': f'Cluster {cluster_id} not found'}), 404
    
    try:
        data = request.get_json() or {}
        duration_hours = int(data.get('duration_hours', config.schedule_override_duration_hours))
        reason = data.get('reason', 'Manual override via API')
        
        schedule_manager.set_schedule_override(cluster_id, duration_hours, reason)
        
        override = schedule_manager.get_schedule_override(cluster_id)
        return jsonify({
            'success': True,
            'message': f'Schedule override set for cluster {cluster.name}',
            'override': override
        }), 200
    except ValueError as e:
        return jsonify({
            'success': False,
            'error': f'Invalid duration_hours: {str(e)}'
        }), 400
    except Exception as e:
        logger.error(f"Error setting schedule override: {e}", exc_info=True)
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/clusters/<cluster_id>/override', methods=['DELETE'])
def clear_schedule_override(cluster_id: str):
    """Clear schedule override for a cluster"""
    cluster = cluster_manager.get_cluster_by_id(cluster_id)
    if not cluster:
        return jsonify({'error': f'Cluster {cluster_id} not found'}), 404
    
    try:
        cleared = schedule_manager.clear_schedule_override(cluster_id)
        if cleared:
            return jsonify({
                'success': True,
                'message': f'Schedule override cleared for cluster {cluster.name}'
            }), 200
        else:
            return jsonify({
                'success': False,
                'message': f'No active override found for cluster {cluster.name}'
            }), 404
    except Exception as e:
        logger.error(f"Error clearing schedule override: {e}", exc_info=True)
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/clusters/<cluster_id>/schedule', methods=['GET'])
def get_cluster_schedule(cluster_id: str):
    """Get current schedule for a cluster"""
    cluster = cluster_manager.get_cluster_by_id(cluster_id)
    if not cluster:
        return jsonify({'error': f'Cluster {cluster_id} not found'}), 404
    
    return jsonify({
        'cluster_id': cluster_id,
        'cluster_name': cluster.name,
        'hibernate_schedule': cluster.hibernate_schedule,
        'wake_up_delay_minutes': cluster.wake_up_delay_minutes
    }), 200

@app.route('/api/clusters/<cluster_id>/schedule', methods=['PUT'])
def update_cluster_schedule(cluster_id: str):
    """Update cluster schedule in runtime"""
    cluster = cluster_manager.get_cluster_by_id(cluster_id)
    if not cluster:
        return jsonify({'error': f'Cluster {cluster_id} not found'}), 404
    
    try:
        data = request.get_json() or {}
        new_schedule = data.get('hibernate_schedule')
        
        if new_schedule is None:
            return jsonify({
                'success': False,
                'error': 'hibernate_schedule is required'
            }), 400
        
        # Validate schedule format by parsing it
        schedules = schedule_manager.parse_schedules(new_schedule)
        if not schedules:
            return jsonify({
                'success': False,
                'error': 'Invalid schedule format'
            }), 400
        
        # Update schedule
        success = schedule_manager.update_cluster_schedule(cluster_id, new_schedule)
        
        if success:
            return jsonify({
                'success': True,
                'message': f'Schedule updated for cluster {cluster.name}',
                'cluster_id': cluster_id,
                'cluster_name': cluster.name,
                'hibernate_schedule': new_schedule
            }), 200
        else:
            return jsonify({
                'success': False,
                'error': 'Failed to update schedule'
            }), 500
    except Exception as e:
        logger.error(f"Error updating cluster schedule: {e}", exc_info=True)
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/config', methods=['GET'])
def get_config():
    """Get configuration (excluding sensitive data)"""
    return jsonify(config.to_dict()), 200

@app.route('/api/swagger.json', methods=['GET'])
@app.route(config.swagger_endpoint, methods=['GET'])
def get_swagger():
    """Get Swagger/OpenAPI specification"""
    try:
        # Load swagger.json file
        swagger_path = os.path.join(os.path.dirname(__file__), 'swagger.json')
        
        if not os.path.exists(swagger_path):
            logger.warning(f"Swagger file not found at {swagger_path}")
            return jsonify({
                'error': 'Swagger specification not found'
            }), 404
        
        with open(swagger_path, 'r', encoding='utf-8') as f:
            swagger_spec = json.load(f)
        
        # Update server URL dynamically based on request
        if request.host:
            # Determine the base URL
            # Check if request is secure (HTTPS)
            scheme = 'https' if request.is_secure else 'http'
            base_url = f"{scheme}://{request.host}"
            swagger_spec['servers'] = [
                {
                    "url": base_url,
                    "description": "Current server"
                }
            ]
        
        return jsonify(swagger_spec), 200
        
    except Exception as e:
        logger.error(f"Error loading Swagger specification: {e}", exc_info=True)
        return jsonify({
            'error': f'Failed to load Swagger specification: {str(e)}'
        }), 500

@app.route('/api/swagger', methods=['GET'])
@app.route(config.swagger_ui_endpoint, methods=['GET'])
def get_swagger_ui():
    """Get Swagger UI HTML page"""
    if not config.swagger_ui_enabled:
        return jsonify({
            'error': 'Swagger UI is disabled'
        }), 404
    
    try:
        # Determine the swagger.json URL
        scheme = 'https' if request.is_secure else 'http'
        swagger_json_url = f"{scheme}://{request.host}{config.swagger_endpoint}"
        
        # Generate Swagger UI HTML
        swagger_ui_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Cloud Hibernate Operator API - Swagger UI</title>
    <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui.css" />
    <style>
        html {{
            box-sizing: border-box;
            overflow: -moz-scrollbars-vertical;
            overflow-y: scroll;
        }}
        *, *:before, *:after {{
            box-sizing: inherit;
        }}
        body {{
            margin:0;
            background: #fafafa;
        }}
    </style>
</head>
<body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-bundle.js"></script>
    <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-standalone-preset.js"></script>
    <script>
        window.onload = function() {{
            const ui = SwaggerUIBundle({{
                url: "{swagger_json_url}",
                dom_id: '#swagger-ui',
                deepLinking: true,
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIStandalonePreset
                ],
                plugins: [
                    SwaggerUIBundle.plugins.DownloadUrl
                ],
                layout: "StandaloneLayout",
                validatorUrl: null,
                persistAuthorization: true,
                onComplete: function() {{
                    // Auto-expand security section if API auth is enabled
                    const authBtn = document.querySelector('.btn.authorize');
                    if (authBtn) {{
                        console.log('API Key authentication is required. Click the "Authorize" button to enter your API key.');
                    }}
                }}
            }});
        }};
    </script>
</body>
</html>"""
        
        return Response(swagger_ui_html, mimetype='text/html')
        
    except Exception as e:
        logger.error(f"Error generating Swagger UI: {e}", exc_info=True)
        return jsonify({
            'error': f'Failed to generate Swagger UI: {str(e)}'
        }), 500

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    return jsonify({'error': 'Internal server error'}), 500

def start_api_server():
    """Start the API server"""
    if not config.api_enabled:
        logger.info("API server is disabled")
        return
    
    # Always use port 8080 inside container
    # API_PORT from config is used only for port mapping in docker-compose
    container_port = 8080
    logger.info(f"Starting API server on {config.api_host}:{container_port} (mapped to host port {config.api_port})")
    app.run(
        host=config.api_host,
        port=container_port,
        debug=False,
        threaded=True
    )

if __name__ == '__main__':
    start_api_server()

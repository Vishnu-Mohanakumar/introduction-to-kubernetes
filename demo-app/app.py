from flask import Flask, request, render_template_string, jsonify
import os
import socket
from datetime import datetime

app = Flask(__name__)

# HTML template for the demo application
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kubernetes Demo App</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .header {
            background: linear-gradient(135deg, #326ce5 0%, #1a73e8 100%);
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        .section {
            border-left: 4px solid #326ce5;
            padding-left: 15px;
            margin: 20px 0;
        }
        .config-item, .secret-item {
            background-color: #f8f9fa;
            padding: 10px;
            border-radius: 4px;
            margin: 5px 0;
            font-family: monospace;
        }
        .form-group {
            margin: 15px 0;
        }
        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
        }
        .form-group input {
            width: 100%;
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 4px;
            box-sizing: border-box;
        }
        .btn {
            background-color: #326ce5;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        .btn:hover {
            background-color: #1a73e8;
        }
        .status-ok {
            color: #28a745;
            font-weight: bold;
        }
        .status-error {
            color: #dc3545;
            font-weight: bold;
        }
        .grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
        }
        @media (max-width: 768px) {
            .grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🎯 Kubernetes Demo Application</h1>
        <p>Demonstrating ConfigMaps, Secrets, Services, and RBAC</p>
    </div>

    <div class="grid">
        <div class="container">
            <div class="section">
                <h2>📊 Pod Information</h2>
                <div class="config-item"><strong>Pod Name:</strong> {{ pod_info.name }}</div>
                <div class="config-item"><strong>Namespace:</strong> {{ pod_info.namespace }}</div>
                <div class="config-item"><strong>Node:</strong> {{ pod_info.node }}</div>
                <div class="config-item"><strong>Pod IP:</strong> {{ pod_info.pod_ip }}</div>
                <div class="config-item"><strong>Service Account:</strong> {{ pod_info.service_account }}</div>
                <div class="config-item"><strong>Started:</strong> {{ pod_info.start_time }}</div>
            </div>

            <div class="section">
                <h2>⚙️ Configuration from ConfigMap</h2>
                {% for key, value in config_data.items() %}
                    <div class="config-item"><strong>{{ key }}:</strong> {{ value }}</div>
                {% endfor %}
            </div>
        </div>

        <div class="container">
            <div class="section">
                <h2>🔐 Secrets Management</h2>
                {% if secret_data %}
                    <h4>Current Stored Credentials:</h4>
                    {% for key, value in secret_data.items() %}
                        <div class="secret-item"><strong>{{ key }}:</strong> ****{{ value[-4:] if value|length > 4 else '****' }}</div>
                    {% endfor %}
                {% endif %}
                
                <h4>Store New Credentials:</h4>
                <form method="POST" action="/store-secret">
                    <div class="form-group">
                        <label for="username">Username:</label>
                        <input type="text" id="username" name="username" required>
                    </div>
                    <div class="form-group">
                        <label for="password">Password:</label>
                        <input type="password" id="password" name="password" required>
                    </div>
                    <button type="submit" class="btn">Store as Secret</button>
                </form>
            </div>

            <div class="section">
                <h2>🔑 Service Account Permissions</h2>
                <div class="config-item">
                    <strong>Can list pods:</strong> 
                    <span class="{{ 'status-ok' if permissions.can_list_pods else 'status-error' }}">
                        {{ 'Yes' if permissions.can_list_pods else 'No' }}
                    </span>
                </div>
                <div class="config-item">
                    <strong>Can create secrets:</strong> 
                    <span class="{{ 'status-ok' if permissions.can_create_secrets else 'status-error' }}">
                        {{ 'Yes' if permissions.can_create_secrets else 'No' }}
                    </span>
                </div>
                <div class="config-item">
                    <strong>Can read configmaps:</strong> 
                    <span class="{{ 'status-ok' if permissions.can_read_configmaps else 'status-error' }}">
                        {{ 'Yes' if permissions.can_read_configmaps else 'No' }}
                    </span>
                </div>
            </div>
        </div>
    </div>

    <div class="container">
        <div class="section">
            <h2>🌐 Service and Networking</h2>
            <div class="config-item"><strong>Service Name:</strong> {{ service_info.name }}</div>
            <div class="config-item"><strong>Service Type:</strong> {{ service_info.type }}</div>
            <div class="config-item"><strong>Cluster IP:</strong> {{ service_info.cluster_ip }}</div>
            <div class="config-item"><strong>Port:</strong> {{ service_info.port }}</div>
            <div class="config-item"><strong>Endpoints:</strong> {{ service_info.endpoints|length }} active</div>
        </div>
    </div>

    <div class="container">
        <div class="section">
            <h2>🔄 Real-time Status</h2>
            <p><strong>Last Updated:</strong> {{ current_time }}</p>
            <button class="btn" onclick="window.location.reload()">Refresh Status</button>
        </div>
    </div>
</body>
</html>
"""

def get_pod_info():
    """Get current pod information"""
    return {
        'name': os.environ.get('HOSTNAME', 'unknown'),
        'namespace': os.environ.get('POD_NAMESPACE', 'unknown'),
        'node': os.environ.get('NODE_NAME', 'unknown'),
        'pod_ip': os.environ.get('POD_IP', socket.gethostbyname(socket.gethostname())),
        'service_account': os.environ.get('SERVICE_ACCOUNT', 'default'),
        'start_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    }

def get_config_data():
    """Get configuration data from environment variables (ConfigMap)"""
    config_vars = {
        'APP_NAME': os.environ.get('APP_NAME', 'Demo Application'),
        'APP_VERSION': os.environ.get('APP_VERSION', '1.0.0'),
        'ENVIRONMENT': os.environ.get('ENVIRONMENT', 'development'),
        'LOG_LEVEL': os.environ.get('LOG_LEVEL', 'INFO'),
        'DATABASE_URL': os.environ.get('DATABASE_URL', 'Not configured'),
        'FEATURE_FLAG': os.environ.get('FEATURE_FLAG', 'disabled')
    }
    return config_vars

def get_secret_data():
    """Get secret data from environment variables"""
    secret_vars = {}
    if os.environ.get('DB_USERNAME'):
        secret_vars['DB_USERNAME'] = os.environ.get('DB_USERNAME')
    if os.environ.get('DB_PASSWORD'):
        secret_vars['DB_PASSWORD'] = os.environ.get('DB_PASSWORD')
    return secret_vars

def check_permissions():
    """Check service account permissions"""
    permissions = {
        'can_list_pods': False,
        'can_create_secrets': False,
        'can_read_configmaps': False
    }
    
    try:
        # These would normally check actual Kubernetes API permissions
        # For demo purposes, we'll simulate based on environment
        permissions['can_list_pods'] = os.environ.get('RBAC_PODS', 'false').lower() == 'true'
        permissions['can_create_secrets'] = os.environ.get('RBAC_SECRETS', 'false').lower() == 'true'
        permissions['can_read_configmaps'] = os.environ.get('RBAC_CONFIGMAPS', 'false').lower() == 'true'
    except Exception as e:
        app.logger.error(f"Error checking permissions: {e}")
    
    return permissions

def get_service_info():
    """Get service information"""
    return {
        'name': os.environ.get('SERVICE_NAME', 'demo-app-service'),
        'type': os.environ.get('SERVICE_TYPE', 'ClusterIP'),
        'cluster_ip': os.environ.get('SERVICE_CLUSTER_IP', 'Unknown'),
        'port': os.environ.get('SERVICE_PORT', '80'),
        'endpoints': ['pod-1', 'pod-2', 'pod-3']  # Simulated endpoints
    }

@app.route('/')
def index():
    """Main application page"""
    return render_template_string(HTML_TEMPLATE,
        pod_info=get_pod_info(),
        config_data=get_config_data(),
        secret_data=get_secret_data(),
        permissions=check_permissions(),
        service_info=get_service_info(),
        current_time=datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    )

@app.route('/store-secret', methods=['POST'])
def store_secret():
    """Store user credentials (simulated)"""
    username = request.form.get('username')
    password = request.form.get('password')
    
    if username and password:
        # In a real scenario, this would create a Kubernetes Secret
        # For demo purposes, we'll just set environment variables
        os.environ['DB_USERNAME'] = username
        os.environ['DB_PASSWORD'] = password
        
        app.logger.info(f"Stored credentials for user: {username}")
    
    return index()

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'pod': os.environ.get('HOSTNAME', 'unknown')
    })

@app.route('/api/info')
def api_info():
    """API endpoint for pod information"""
    return jsonify({
        'pod_info': get_pod_info(),
        'config_data': get_config_data(),
        'secret_data': get_secret_data(),
        'permissions': check_permissions(),
        'service_info': get_service_info()
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
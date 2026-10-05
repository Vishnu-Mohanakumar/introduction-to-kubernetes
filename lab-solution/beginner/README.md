# Kubernetes Todo App - Complete Solution

This is the **complete working solution** for the lab assignment. All components run on **killercoda.com's Kubernetes Playground or a local KIND cluster** - **no external systems needed**.

## 🗂️ Directory Structure

```
lab-solution/
├── todo-app/                    # Complete application code
│   ├── backend/                 # Flask REST API
│   ├── frontend/               # Single-page app with Nginx  
│   └── docker-compose.yml      # Local testing
├── k8s-manifests/              # Kubernetes deployment files
│   ├── 01-namespace.yaml       # Application namespace
│   ├── 02-configmaps.yaml      # Configuration management
│   ├── 03-secrets.yaml         # Sensitive data
│   ├── 04-serviceaccounts.yaml # RBAC service accounts
│   ├── 05-roles.yaml           # RBAC roles
│   ├── 06-rolebindings.yaml    # RBAC bindings
│   ├── 07-postgres-statefulset.yaml # PostgreSQL cluster
│   ├── 08-redis-deployment.yaml # Redis cache
│   ├── 09-services.yaml        # All services
│   ├── 10-deployments.yaml     # Frontend/Backend deployments
│   └── deploy.sh               # Automated deployment script
└── README.md                   # This file
```

## 🚀 Quick Deploy (Local)

### Prerequisites:
- **killercoda.com**: Start the Kubernetes Playground scenario - `kubectl` and `docker` pre-installed
- **OR KIND Cluster**: `kind create cluster --config ../../kind/kind.config.yaml --name workshop`
- **Docker**: Installed and running (if using KIND)
- **kubectl**: Installed and configured (if using KIND)

### One-Command Deploy:
```bash
cd k8s-manifests
./deploy.sh
```

This automatically:
1. Builds Docker images locally
2. Loads images into your cluster (KIND only)
3. Deploys all Kubernetes resources
4. Waits for everything to be ready
5. Tests functionality

### Manual Deploy:
```bash
# Build images
cd todo-app
docker build -t todo-backend:latest ./backend
docker build -t todo-frontend:latest ./frontend

# Load into KIND
kind load docker-image todo-backend:latest --name workshop
kind load docker-image todo-frontend:latest --name workshop

# On killercoda instead: docker build alone is NOT enough - see the top-level
# README's killercoda section for why. Shortcut once you understand why (one call per image):
bash ../../killercoda/load-image.sh todo-backend:latest
bash ../../killercoda/load-image.sh todo-frontend:latest

# Deploy manifests
cd ../k8s-manifests
kubectl apply -f .

# Check status
kubectl get all -n todo-app
```

## 📊 What's Deployed

### Services (All Running Locally):
- **PostgreSQL StatefulSet**: 3 replicas with persistent storage (1Gi each)
- **Redis Deployment**: 1 replica for application caching
- **Backend Deployment**: 2 replicas of Flask API
- **Frontend Deployment**: 2 replicas of Nginx + SPA

### Security (Built In):
- Separate ServiceAccounts for each component
- RBAC Roles with minimal required permissions
- Secrets for passwords and API keys
- Security contexts with non-root users

### Networking (Local DNS):
- ClusterIP services for internal communication
- Service discovery via DNS (postgres-service, redis-service, etc.)
- Nginx reverse proxy for frontend

### Storage (Local Volumes):
- PersistentVolumeClaims for PostgreSQL data
- EmptyDir volume for Redis caching

## 🧪 Access & Test

### Open the Application:
```bash
# Frontend (Full App UI)
kubectl port-forward -n todo-app service/frontend-service 8080:80
# Open http://localhost:8080 in browser

# Backend API (Direct)
kubectl port-forward -n todo-app service/backend-service 5000:5000
# Test: curl http://localhost:5000/health
```

### API Endpoints:
```bash
# Create a todo
curl -X POST http://localhost:5000/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Learn Kubernetes","description":"Master K8s concepts","priority":"high"}'

# Get all todos
curl http://localhost:5000/api/todos

# Get statistics
curl http://localhost:5000/api/stats

# Health checks
curl http://localhost:5000/health
curl http://localhost:5000/health/ready
```

### Verify All Resources:
```bash
# Check all running resources
kubectl get all,pvc,secrets,configmaps -n todo-app

# Check pod logs
kubectl logs -f deployment/backend -n todo-app

# Check database
kubectl exec -it postgres-0 -n todo-app -- psql -U todouser -d todoapp -c "SELECT * FROM todos;"
```

## 🔧 Key Configuration

### Environment Variables (Backend):
```yaml
DB_HOST: postgres-service      # Service DNS name
DB_PORT: 5432
DB_NAME: todoapp
DB_USER: todouser
REDIS_HOST: redis-service      # Service DNS name
REDIS_PORT: 6379
```

### Secrets (Base64 Encoded):
```yaml
POSTGRES_PASSWORD: todopass
DB_PASSWORD: todopass
JWT_SECRET: (base64 encoded)
API_KEY: (base64 encoded)
```

## 📈 Production Features

### Resource Management:
- CPU requests: backend 100m, frontend 50m, postgres 250m
- Memory requests: backend 128Mi, frontend 64Mi, postgres 256Mi
- Resource limits defined for all containers

### Health Checks:
- Liveness probes: detect hanging containers
- Readiness probes: ensure service is ready for traffic
- Database includes pg_isready checks
- API includes /health/ready endpoint

### Security:
- ServiceAccounts with specific RBAC permissions
- Non-root container users
- Secret management for sensitive data
- Security contexts configured

## 🧪 Test Scenarios

### 1. Basic Functionality:
```bash
# Access frontend and create todos
kubectl port-forward -n todo-app svc/frontend-service 8080:80
# Open http://localhost:8080
# Create and manage todos in the UI
```

### 2. Data Persistence:
```bash
# Delete a database pod
kubectl delete pod postgres-0 -n todo-app

# StatefulSet recreates it automatically
kubectl wait --for=condition=Ready pod/postgres-0 -n todo-app

# Check data still exists
kubectl exec -it postgres-0 -n todo-app -- psql -U todouser -d todoapp -c "SELECT count(*) FROM todos;"
```

### 3. Pod Recovery:
```bash
# Delete a backend pod
kubectl delete pod -l app=backend -n todo-app

# Watch new pods start
kubectl get pods -n todo-app -w

# Application still works
curl http://localhost:5000/api/todos
```

### 4. Scaling:
```bash
# Scale backend to 3 replicas
kubectl scale deployment backend --replicas=3 -n todo-app

# Watch new pods start
kubectl get pods -n todo-app -l app=backend

# Scale back down
kubectl scale deployment backend --replicas=2 -n todo-app
```

## 🛠️ Troubleshooting

### Common Issues:

#### Pods Not Starting:
```bash
# Check pod status
kubectl describe pod <pod-name> -n todo-app

# Check logs
kubectl logs <pod-name> -n todo-app
```

#### Database Connection Failed:
```bash
# Test database connectivity
kubectl exec -it postgres-0 -n todo-app -- pg_isready -U todouser -d todoapp

# Check if service exists
kubectl get service postgres-service -n todo-app
```

#### Image Pull Failed (KIND only):
```bash
# Make sure images are loaded
docker exec workshop-control-plane crictl images | grep todo
docker exec workshop-worker crictl images | grep todo

# If missing, reload
kind load docker-image todo-backend:latest --name workshop
```

### Useful Commands:
```bash
# View all resources with labels
kubectl get all -n todo-app --show-labels

# Get recent events
kubectl get events -n todo-app --sort-by=.metadata.creationTimestamp

# Debug a pod
kubectl exec -it backend-xxx -n todo-app -- /bin/bash

# Check network connectivity
kubectl exec -it backend-xxx -n todo-app -- curl postgres-service:5432
```

## 🧹 Cleanup

```bash
# Remove everything
cd k8s-manifests
./deploy.sh cleanup

# Or manually
kubectl delete namespace todo-app
kubectl get pvc --all-namespaces  # May need to delete PVCs manually
```

## 📝 Learning Outcomes

This solution demonstrates:

1. **StatefulSet Management**: Persistent database clustering
2. **Service Discovery**: DNS-based inter-service communication
3. **Configuration Management**: ConfigMaps and Secrets
4. **RBAC Implementation**: Security best practices
5. **Resource Management**: Production-ready allocations
6. **Health Monitoring**: Comprehensive health checking
7. **Deployment Automation**: Scripted local deployments

## 📚 For Students

### How to Use This Solution:
1. **Don't copy blindly** - understand each manifest
2. **Read the YAML** - comments explain each section
3. **Try breaking it** - intentionally delete pods and services
4. **Modify it** - change replica counts, add labels, experiment
5. **Compare** - check what you wrote vs. the solution

### Key Learning Points:
- Why StatefulSet instead of Deployment for databases?
- How services enable DNS discovery?
- Why RBAC matters for security?
- How manifests work together as a system?
- What happens when pods are deleted?

---

## ✅ Verification Checklist

- [ ] Cluster has 1-3 nodes ready
- [ ] kubectl configured correctly
- [ ] Docker images built successfully (locally for KIND; on killercoda, built AND imported into containerd via `ctr` on both nodes - see the top-level README)
- [ ] Images loaded into cluster (KIND only, via `kind load docker-image`)
- [ ] `kubectl get all -n todo-app` shows 5+ resources
- [ ] All pods in Running state
- [ ] Frontend accessible at http://localhost:8080
- [ ] Can create and view todos
- [ ] Database data persists after pod deletion
- [ ] Deleted pods are automatically recreated
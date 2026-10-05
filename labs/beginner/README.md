# Kubernetes Todo App - Student Starter Kit

## 📋 Assignment Overview

You have **1 week** to create Kubernetes manifests that deploy this Todo application successfully. The application code is provided - **your job is to write the Kubernetes YAML files**.

This assignment runs on **killercoda.com's Kubernetes Playground or a local KIND cluster**. **No external systems needed!**

## 🏗️ Application Architecture

This is a microservices Todo application with:

- **Frontend**: Nginx serving a single-page application
- **Backend**: Python Flask REST API  
- **Database**: PostgreSQL with persistent storage
- **Cache**: Redis for session storage and API caching

## 🗂️ Provided Code Structure

```
todo-app/
├── backend/
│   ├── app.py              # Flask REST API application
│   ├── requirements.txt    # Python dependencies
│   └── Dockerfile          # Backend container definition
├── frontend/
│   ├── index.html          # Single-page application
│   ├── nginx.conf          # Nginx configuration
│   └── Dockerfile          # Frontend container definition  
└── docker-compose.yml      # For local testing
```

## 🎯 Your Task: Write Kubernetes Manifests

Create a `k8s/` directory with the following manifest files:

### Required Files:
1. **01-namespace.yaml** - Application namespace
2. **02-configmaps.yaml** - Configuration for all components
3. **03-secrets.yaml** - Database passwords and API keys
4. **04-serviceaccounts.yaml** - Service accounts for RBAC
5. **05-roles.yaml** - RBAC roles with minimal permissions
6. **06-rolebindings.yaml** - Bind roles to service accounts
7. **07-postgres-statefulset.yaml** - PostgreSQL cluster (3 replicas)
8. **08-redis-deployment.yaml** - Redis cache deployment
9. **09-services.yaml** - All required services
10. **10-deployments.yaml** - Frontend and backend deployments

### Configuration Requirements:

#### Database Configuration:
- **Database Name**: `todoapp`
- **Database User**: `todouser`  
- **Database Password**: `todopass`
- **PostgreSQL Image**: `postgres:16-alpine`
- **Storage**: 1Gi persistent volume per replica

#### Backend Configuration:
- **Environment Variables Needed**:
  - `DB_HOST`: postgres-service
  - `DB_PORT`: 5432
  - `DB_NAME`: todoapp
  - `DB_USER`: todouser
  - `DB_PASSWORD`: (from secret)
  - `REDIS_HOST`: redis-service
  - `REDIS_PORT`: 6379
  - `PORT`: 5000

#### Frontend Configuration:
- **Nginx**: Proxy `/api/*` requests to backend service
- **Static Files**: Serve index.html on port 80

## 🚀 Quick Start (Local Only)

### 1. Test Locally First
```bash
# Test with Docker Compose (optional, for understanding the app)
cd todo-app
docker-compose up

# Access at http://localhost:8080
```

### 2. Setup Kubernetes Cluster

**Option A: killercoda.com (Recommended for quick iteration)**
- Start the Kubernetes Playground scenario at [killercoda.com](https://killercoda.com/)
- `kubectl` and `docker` are pre-installed - run: `kubectl get nodes`
- Sessions are time-limited and reset, so redeploy your manifests each time you resume - your deliverable is the code/manifests, not a long-running cluster

**Option B: KIND (if you want a cluster that stays up across the week)**
```bash
kind create cluster --config ../../kind/kind.config.yaml --name workshop
kubectl cluster-info --context kind-workshop
```

### 3. Build & Load Images

```bash
# Build images
docker build -t todo-backend:latest ./backend
docker build -t todo-frontend:latest ./frontend

# Load into Kubernetes (KIND)
kind load docker-image todo-backend:latest --name workshop
kind load docker-image todo-frontend:latest --name workshop
```

On killercoda, `docker build` alone is not enough - see the top-level README's killercoda
section for why. Once you understand why, `bash ../../killercoda/load-image.sh <image>` does it for
you (one call per image):
```bash
bash ../../killercoda/load-image.sh todo-backend:latest
bash ../../killercoda/load-image.sh todo-frontend:latest
```

### 4. Create Your Manifests
```bash
mkdir k8s
# Create your YAML files in the k8s/ directory
```

### 5. Deploy to Kubernetes
```bash
kubectl apply -f k8s/
```

### 6. Test Your Deployment
```bash
# Check all resources
kubectl get all -n todo-app

# Access frontend
kubectl port-forward -n todo-app service/frontend-service 8080:80

# Test API directly  
kubectl port-forward -n todo-app service/backend-service 5000:5000
```

## 📋 Requirements Checklist

### ✅ Core (Must Have)
- [ ] **Namespace**: `todo-app` with proper labels
- [ ] **StatefulSet**: PostgreSQL with 3 replicas and persistent storage
- [ ] **Deployment**: Backend with 2 replicas
- [ ] **Deployment**: Frontend with 2 replicas  
- [ ] **Deployment**: Redis with 1 replica
- [ ] **ConfigMaps**: Database and application configuration
- [ ] **Secrets**: Passwords and API keys (base64 encoded)
- [ ] **Services**: ClusterIP for backend, frontend, postgres, redis
- [ ] **ServiceAccounts**: One for each component
- [ ] **RBAC**: Roles and RoleBindings with minimal permissions

### ✅ Production Features (Should Have)
- [ ] **Resource Limits**: CPU and memory for all containers
- [ ] **Health Checks**: Liveness and readiness probes
- [ ] **Persistent Storage**: Database survives pod restarts
- [ ] **Security Context**: Non-root users where possible
- [ ] **Labels**: Consistent labeling strategy

### ✅ Bonus (Nice to Have)
- [ ] **Network Policies**: Secure inter-service communication
- [ ] **Horizontal Pod Autoscaler**: Scale based on CPU usage
- [ ] **Init Containers**: Database initialization
- [ ] **Monitoring**: Health check endpoints (already in app)

## 🔍 API Endpoints (For Testing)

### Backend API:
- `GET /health` - Health check
- `GET /health/ready` - Readiness check  
- `GET /api/todos` - List all todos
- `POST /api/todos` - Create new todo
- `PUT /api/todos/{id}` - Update todo
- `DELETE /api/todos/{id}` - Delete todo
- `GET /api/stats` - Todo statistics

### Frontend:
- `/` - Main application interface
- `/health` - Nginx health check
- `/api/*` - Proxied to backend

## 🧪 Testing Checklist

### Functionality Tests:
- [ ] Can access frontend at http://localhost:8080
- [ ] Can create new todos through UI
- [ ] Can mark todos as complete/incomplete
- [ ] Can delete todos
- [ ] Statistics update correctly

### Kubernetes Tests:
- [ ] All pods in Running state: `kubectl get pods -n todo-app`
- [ ] Database data persists after pod restart
- [ ] Backend can connect to database and Redis
- [ ] Frontend can communicate with backend
- [ ] Services resolve correctly within cluster

### Resilience Tests:
- [ ] Delete a backend pod → new pod starts automatically
- [ ] Delete a frontend pod → new pod starts automatically  
- [ ] Delete a database pod → StatefulSet recreates it
- [ ] Restart Redis → application continues working

## 📚 Helpful Resources

### Workshop Materials (Reference)
- Review demo-manifests from the workshop for examples
- Check out the database StatefulSet example
- Use `kubectl explain` for field documentation

### Kubernetes Documentation:
- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

## ❓ Common Issues & Solutions

### Images Not Found
```bash
# Make sure images are built and loaded
docker build -t todo-backend:latest ./backend
kind load docker-image todo-backend:latest --name workshop

# Check images are available
docker exec workshop-control-plane crictl images | grep todo
docker exec workshop-worker crictl images | grep todo
```

### Database Connection Issues
```bash
# Verify service names match environment variables
kubectl get services -n todo-app

# Test database connectivity
kubectl exec -it postgres-0 -n todo-app -- psql -U todouser -d todoapp -c "\dt"
```

### Pod Startup Issues
```bash
# Check pod logs
kubectl logs <pod-name> -n todo-app

# Describe pod for detailed errors
kubectl describe pod <pod-name> -n todo-app
```

## 🎯 Submission Requirements

### Deliverables:
1. **k8s/** directory with all 10 manifest files
2. **README.md** with deployment instructions
3. Working deployment on local Kubernetes
4. Passing all functional and resilience tests

### Optional Bonus:
- **deploy.sh** script for automated deployment
- **cleanup.sh** script for cleanup
- Custom health checks or monitoring

---

## 🚀 Ready to Start?

1. **Understand** the application by reviewing app.py
2. **Plan** your Kubernetes architecture  
3. **Start** with the database layer (StatefulSet)
4. **Work** your way up to frontend and backend
5. **Test** each component as you go
6. **Deploy** the full stack

**Everything runs on your local machine - no external services needed!** 🎉
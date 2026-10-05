# Step-by-Step Deployment Guide

This guide provides detailed steps to deploy the Todo application to killercoda.com's Kubernetes Playground or a local KIND cluster.

## Prerequisites

Before starting, ensure you have:
- A cluster: killercoda.com's Kubernetes Playground (kubectl + docker pre-installed), or a local KIND cluster (`kind create cluster --config ../../kind/kind.config.yaml --name workshop`)
- Docker command-line tools installed (if using KIND)
- kubectl installed and configured
- Access to the lab-solution directory

## Step-by-Step Deployment

### Step 1: Navigate to the Solution Directory

```bash
cd lab-solution/beginner
```

### Step 2: Build Docker Images

**On KIND**: build locally, then load the images into the cluster's container runtime.

**On killercoda**: `docker build` alone is not enough - see the top-level README's killercoda section for why. Build here, then run `bash ../../killercoda/load-image.sh <image>` for each image before moving on.

**Build Backend Image:**
```bash
docker build -t todo-backend:latest ./todo-app/backend/
```

Expected output:
```
[+] Building ...
[x] FINISHED ... in XXs
```

**Build Frontend Image:**
```bash
docker build -t todo-frontend:latest ./todo-app/frontend/
```

**Verify Images:**
```bash
docker images | grep todo
```

You should see both images listed.

**KIND only - load images into the cluster:**
```bash
kind load docker-image todo-backend:latest --name workshop
kind load docker-image todo-frontend:latest --name workshop

# Verify they landed on the node
docker exec workshop-control-plane crictl images | grep todo
docker exec workshop-worker crictl images | grep todo
```

### Step 3: Create Kubernetes Namespace

Create a dedicated namespace for the Todo application:

```bash
kubectl create namespace todo-app
```

Or apply the namespace manifest:
```bash
kubectl apply -f k8s-manifests/00-namespace.yaml
```

### Step 4: Apply Configuration and Secrets

Apply ConfigMaps and Secrets:

```bash
kubectl apply -f k8s-manifests/01-configmaps.yaml
kubectl apply -f k8s-manifests/02-secrets.yaml
```

Verify they were created:
```bash
kubectl get configmap -n todo-app
kubectl get secret -n todo-app
```

### Step 5: Create RBAC Resources

Create Service Accounts, Roles, and RoleBindings:

```bash
kubectl apply -f k8s-manifests/03-serviceaccount.yaml
kubectl apply -f k8s-manifests/04-role.yaml
kubectl apply -f k8s-manifests/05-rolebinding.yaml
```

Verify RBAC resources:
```bash
kubectl get serviceaccount -n todo-app
kubectl get role -n todo-app
kubectl get rolebinding -n todo-app
```

### Step 6: Deploy PostgreSQL

Deploy the PostgreSQL StatefulSet with persistent storage:

```bash
kubectl apply -f k8s-manifests/06-postgres-statefulset.yaml
kubectl apply -f k8s-manifests/07-postgres-service.yaml
```

Wait for PostgreSQL to be ready:
```bash
kubectl wait --for=condition=ready pod -l app=postgres -n todo-app --timeout=300s
```

Verify PostgreSQL is running:
```bash
kubectl get pod -n todo-app -l app=postgres
kubectl get pvc -n todo-app
```

All pods should show `1/1 Running` or similar.

### Step 7: Deploy Redis

Deploy the Redis deployment:

```bash
kubectl apply -f k8s-manifests/08-redis-deployment.yaml
kubectl apply -f k8s-manifests/09-redis-service.yaml
```

Verify Redis is running:
```bash
kubectl get pod -n todo-app -l app=redis
```

### Step 8: Deploy Backend and Frontend

Deploy the backend and frontend applications:

```bash
kubectl apply -f k8s-manifests/10-deployments.yaml
```

Wait for deployments to be ready:
```bash
kubectl wait --for=condition=available --timeout=300s \
  deployment/backend deployment/frontend -n todo-app
```

Verify all deployments:
```bash
kubectl get deployment -n todo-app
```

### Step 9: Verify All Resources

Check that all resources are created and running:

```bash
kubectl get all -n todo-app
```

Expected output:
```
NAME                            READY   STATUS    RESTARTS   AGE
pod/backend-xxxxx               1/1     Running   0          XXs
pod/backend-xxxxx               1/1     Running   0          XXs
pod/frontend-xxxxx              1/1     Running   0          XXs
pod/frontend-xxxxx              1/1     Running   0          XXs
pod/postgres-0                  1/1     Running   0          XXs
pod/postgres-1                  1/1     Running   0          XXs
pod/postgres-2                  1/1     Running   0          XXs
pod/redis-xxxxx                 1/1     Running   0          XXs

NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/backend-service     ClusterIP   10.43.x.x       <none>        5000/TCP       XXs
service/frontend-service    NodePort    10.43.x.x       <none>        80:30080/TCP   XXs
service/postgres-headless   ClusterIP   None            <none>        5432/TCP       XXs
service/postgres-service    ClusterIP   10.43.x.x       <none>        5432/TCP       XXs
service/redis-service       ClusterIP   10.43.x.x       <none>        6379/TCP       XXs

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/backend    2/2     2            2           XXs
deployment.apps/frontend   2/2     2            2           XXs
deployment.apps/redis      1/1     1            1           XXs

NAME                        READY   AGE
statefulset.apps/postgres   3/3     XXs
```

### Step 10: Initialize Database

The database needs to be initialized with the todos table. Follow these steps:

**Get a backend pod name:**
```bash
kubectl get pods -n todo-app -l app=backend
```

**Initialize the database:**
```bash
kubectl exec -it <BACKEND_POD_NAME> -n todo-app -- python3 << 'EOF'
import os
import psycopg2

DB_HOST = os.getenv('DB_HOST', 'postgres-service')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'todoapp')
DB_USER = os.getenv('DB_USER', 'todouser')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'todopass')

conn = psycopg2.connect(
    host=DB_HOST,
    port=DB_PORT,
    database=DB_NAME,
    user=DB_USER,
    password=DB_PASSWORD,
    connect_timeout=10
)

with conn.cursor() as cur:
    cur.execute('''
        CREATE TABLE IF NOT EXISTS todos (
            id SERIAL PRIMARY KEY,
            title VARCHAR(200) NOT NULL,
            description TEXT,
            completed BOOLEAN DEFAULT FALSE,
            priority VARCHAR(10) DEFAULT 'medium',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    cur.execute('''
        CREATE INDEX IF NOT EXISTS idx_todos_completed ON todos(completed)
    ''')
    
    sample_todos = [
        ('Learn Kubernetes', 'Complete the hands-on workshop', False, 'high'),
        ('Deploy StatefulSet', 'Configure PostgreSQL with persistent storage', False, 'high'),
        ('Implement RBAC', 'Set up service accounts and role bindings', False, 'medium'),
        ('Configure Monitoring', 'Add Prometheus metrics to the application', False, 'medium'),
        ('Write Documentation', 'Document the deployment process', False, 'low'),
    ]
    
    cur.executemany('''
        INSERT INTO todos (title, description, completed, priority) VALUES (%s, %s, %s, %s)
    ''', sample_todos)

conn.commit()
conn.close()
print("✅ Database initialized successfully")
EOF
```

**Restart backend deployment:**
```bash
kubectl rollout restart deployment/backend -n todo-app
```

Wait for backend pods to restart:
```bash
kubectl get pods -n todo-app -l app=backend -w
```

### Step 11: Set Up Port Forwarding

Forward the frontend and backend services to your local machine:

**Terminal 1 - Frontend:**
```bash
kubectl port-forward svc/frontend-service 8080:80 -n todo-app
```

**Terminal 2 - Backend (optional, for API testing):**
```bash
kubectl port-forward svc/backend-service 5000:5000 -n todo-app
```

### Step 12: Verify Deployment

**Test Frontend Health:**
```bash
curl http://localhost:8080/health
```

Expected: `healthy`

**Test Backend API:**
```bash
curl http://localhost:5000/api/todos | python3 -m json.tool
```

Expected: JSON array of todos with 5 sample items

### Step 13: Access the Application

Open your browser and navigate to:
```
http://localhost:8080
```

You should see the Todo application with all 5 sample todos listed.

## Troubleshooting

If you encounter any errors during deployment, refer to the [TROUBLESHOOTING_AND_ERRORS.md](./TROUBLESHOOTING_AND_ERRORS.md) guide for:

- ImagePullPolicy errors
- KIND image loading issues
- Frontend Nginx permission errors
- Backend service unreachable errors
- Complete deployment checklist

## Next Steps

Once the application is running:

1. **Test Functionality:**
   - Create a new todo
   - Edit an existing todo
   - Mark todos as complete
   - Delete a todo

2. **Test Data Persistence:**
   - Delete a backend pod: `kubectl delete pod <POD_NAME> -n todo-app`
   - Verify data still exists after pod restart

3. **Monitor Application:**
   - Check logs: `kubectl logs -n todo-app -l app=backend`
   - Monitor resources: `kubectl top pod -n todo-app`

## Cleanup

To remove the entire deployment:

```bash
# Delete the namespace (removes all resources)
kubectl delete namespace todo-app

# Delete Docker images (optional)
docker rmi todo-backend:latest
docker rmi todo-frontend:latest
```

## Additional Commands

### Useful kubectl Commands

```bash
# View all resources in the namespace
kubectl get all -n todo-app

# Get detailed pod information
kubectl describe pod <POD_NAME> -n todo-app

# View pod logs
kubectl logs <POD_NAME> -n todo-app
kubectl logs <POD_NAME> -n todo-app -f  # Follow logs

# Execute command in pod
kubectl exec -it <POD_NAME> -n todo-app -- /bin/sh

# Watch pod status in real-time
kubectl get pods -n todo-app -w

# View resource usage
kubectl top pod -n todo-app

# View events
kubectl get events -n todo-app
```

### Useful Docker Commands

```bash
# List images
docker images | grep todo

# Inspect an image
docker inspect todo-backend:latest

# Build with BuildKit (faster)
DOCKER_BUILDKIT=1 docker build -t todo-backend:latest ./todo-app/backend/
```

## Success Criteria

Your deployment is successful when:

✅ All 8 pods are running: `kubectl get pods -n todo-app`
✅ All services are created: `kubectl get svc -n todo-app`
✅ Frontend is accessible: `curl http://localhost:8080/health`
✅ Backend API responds: `curl http://localhost:5000/api/todos`
✅ Browser shows Todo application at `http://localhost:8080`
✅ Can create/edit/delete todos in the UI
✅ Data persists after pod restarts

When all criteria are met, your lab solution is fully operational! 🎉

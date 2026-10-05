# Troubleshooting and Common Errors

This guide documents all common issues encountered when deploying the Todo application to Kubernetes and the steps to resolve them.

## Table of Contents
1. [ImagePullPolicy Error](#imagepullpolicy-error)
2. [KIND Image Loading Issue](#kind-image-loading-issue)
3. [Frontend Nginx Permission Denied](#frontend-nginx-permission-denied)
4. [Backend Service Unreachable](#backend-service-unreachable)
5. [Deployment Checklist](#deployment-checklist)

---

## ImagePullPolicy Error

### Symptom
```
ErrImageNeverPull: repository does not exist
ImagePullBackOff: Failed to pull image 'todo-backend:latest'
```

### Root Cause
The `imagePullPolicy: Never` policy only looks for images already on the node. When images are not in the Kubernetes cluster's container runtime, pods fail with pull errors.

### Solution
Change `imagePullPolicy` from `Never` to `IfNotPresent` in all deployment manifests:

```yaml
# Before
imagePullPolicy: Never

# After
imagePullPolicy: IfNotPresent
```

**File to update:** `k8s-manifests/10-deployments.yaml`

**Steps:**
1. Open `k8s-manifests/10-deployments.yaml`
2. Find all instances of `imagePullPolicy: Never`
3. Replace with `imagePullPolicy: IfNotPresent`
4. Apply changes: `kubectl apply -f k8s-manifests/10-deployments.yaml`

---

## KIND Image Loading Issue

### Symptom
```
Images built locally but Kubernetes shows:
ErrImageNeverPull / ImagePullBackOff
Failed to pull image "todo-backend:latest"
```

### Root Cause
KIND runs its own containerd inside the cluster's Docker container - it has no visibility into your host's Docker image store. Building an image with `docker build` only puts it in your host's Docker, not in the KIND node. This issue doesn't apply on killercoda, since you build directly on the same VM the cluster runs on.

### Solution
Load the built images into the KIND cluster explicitly:

```bash
# Build backend and frontend images
docker build -t todo-backend:latest ./backend/
docker build -t todo-frontend:latest ./frontend/

# Load them into the KIND cluster's node
kind load docker-image todo-backend:latest --name workshop
kind load docker-image todo-frontend:latest --name workshop
```

**Why this works:**
- `kind load docker-image` copies the image directly into the KIND node's containerd store
- No registry push/pull is needed for local development
- The manifest's `imagePullPolicy` should be `IfNotPresent` or `Never` so Kubernetes uses the loaded image instead of trying a registry pull

**Verification:**
```bash
# Check images are present on the node
docker exec workshop-control-plane crictl images | grep todo
docker exec workshop-worker crictl images | grep todo

# Should show both images:
# todo-backend    latest    <IMAGE_ID>    <SIZE>
# todo-frontend   latest    <IMAGE_ID>    <SIZE>
```

---

## Frontend Nginx Permission Denied

### Symptom
```
2025/11/20 23:41:58 [emerg] 1#1: open() "/run/nginx.pid" failed (13: Permission denied)
nginx: [emerg] open() "/run/nginx.pid" failed (13: Permission denied)

Frontend pod status: CrashLoopBackOff
```

### Root Cause
The Dockerfile tried to run nginx as a non-root user (nginx user), but nginx's master process needs to run as root to create and manage the PID file in `/run/nginx.pid`. Running as non-root nginx user causes permission denied errors.

### Solution
Remove the unnecessary `USER nginx` directive and let nginx run as root (default):

**Original problematic Dockerfile:**
```dockerfile
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/

# This caused the permission denied error
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d

USER nginx  # ❌ This is the problem

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**Fixed Dockerfile:**
```dockerfile
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/

# Simple and correct - let nginx run as root (default)
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**Why the fix works:**
- nginx:alpine image has nginx already set up for root execution
- The nginx process manages its own user switching for worker processes
- No manual permission management needed

**Rebuild and redeploy:**
```bash
docker build -t todo-frontend:latest ./frontend/
kind load docker-image todo-frontend:latest --name workshop  # KIND only, skip on killercoda
kubectl rollout restart deployment/frontend -n todo-app
```

---

## Backend Service Unreachable

### Symptom
Frontend shows error when trying to call backend API
```
Failed to load todos. Please check if the backend service is running.
```

Backend pod logs show no errors, but frontend can't connect.

### Root Cause
Several possible causes:
1. Backend pod not ready (liveness/readiness probe failures)
2. Service not properly routing to backend pods
3. Network policy blocking communication
4. Environment variables not set correctly

### Troubleshooting Steps

**Step 1: Check pod status**
```bash
kubectl get pods -n todo-app -l app=backend
kubectl describe pod <BACKEND_POD> -n todo-app
```

Look for:
- Pod status should be `Running` and `Ready 1/1`
- Events should not show CrashLoopBackOff or ImagePullBackOff
- Readiness probe should be passing

**Step 2: Check service**
```bash
kubectl get svc -n todo-app backend-service
kubectl describe svc backend-service -n todo-app
```

Look for:
- Endpoints should show backend pod IPs
- Service IP should be assigned

**Step 3: Test connectivity from frontend pod**
```bash
# Get a frontend pod name
kubectl get pods -n todo-app -l app=frontend

# Test if frontend can reach backend service
kubectl exec -it <FRONTEND_POD> -n todo-app -- sh -c \
  "wget -O- http://backend-service:5000/health"
```

Should return: `{"status":"healthy",...}`

**Step 4: Check backend readiness probe**
```bash
kubectl logs <BACKEND_POD> -n todo-app | grep -i "readiness\|health"
```

Backend should log successful health checks if database is working.

---

## Deployment Checklist

Use this checklist when deploying the Todo application:

### Pre-Deployment
- [ ] Verify Docker is running: `docker ps`
- [ ] Verify Kubernetes is running: `kubectl cluster-info`
- [ ] Verify all source files exist: `ls todo-app/`

### Build Phase
- [ ] Build backend image:
  ```bash
  docker build -t todo-backend:latest ./todo-app/backend/
  ```
- [ ] Build frontend image:
  ```bash
  docker build -t todo-frontend:latest ./todo-app/frontend/
  ```
- [ ] Verify images exist:
  ```bash
  docker images | grep todo
  ```
- [ ] KIND only - load images into the cluster:
  ```bash
  kind load docker-image todo-backend:latest --name workshop
  kind load docker-image todo-frontend:latest --name workshop
  ```

### Deployment Phase
- [ ] Create namespace:
  ```bash
  kubectl create namespace todo-app
  ```
- [ ] Apply all manifests:
  ```bash
  kubectl apply -f k8s-manifests/
  ```
- [ ] Wait for pods to be ready (2-3 minutes):
  ```bash
  kubectl get all -n todo-app -w
  ```

### Initialization Phase
- [ ] Initialize database (if tables don't exist):
  ```bash
  # Follow "Database Table Not Found" section above
  ```
- [ ] Restart backend deployment:
  ```bash
  kubectl rollout restart deployment/backend -n todo-app
  ```

### Verification Phase
- [ ] Check all pods are running:
  ```bash
  kubectl get pods -n todo-app
  ```
  All should show `1/1 Running` or `3/3 Running`

- [ ] Set up port forwarding:
  ```bash
  kubectl port-forward svc/frontend-service 8080:80 -n todo-app &
  kubectl port-forward svc/backend-service 5000:5000 -n todo-app &
  ```

- [ ] Test frontend:
  ```bash
  curl http://localhost:8080/health
  ```

- [ ] Test backend API:
  ```bash
  curl http://localhost:5000/api/todos
  ```

- [ ] Test in browser:
  ```
  http://localhost:8080
  ```

### Post-Deployment Testing
- [ ] Create a new todo via UI
- [ ] Edit an existing todo
- [ ] Mark todo as complete
- [ ] Delete a todo
- [ ] Verify data persists after pod restart:
  ```bash
  kubectl delete pod <BACKEND_POD> -n todo-app
  # Wait for new pod to start
  curl http://localhost:5000/api/todos
  # Data should still be there
  ```

---

## Quick Recovery Commands

If something goes wrong, use these commands to recover:

```bash
# View all errors in the cluster
kubectl get events -n todo-app

# View detailed pod status
kubectl describe pod <POD_NAME> -n todo-app

# View logs from a specific pod
kubectl logs <POD_NAME> -n todo-app

# View logs from all pods of a deployment
kubectl logs -n todo-app -l app=backend --all-containers=true

# Restart a deployment
kubectl rollout restart deployment/<NAME> -n todo-app

# Delete and redeploy
kubectl delete namespace todo-app
kubectl create namespace todo-app
kubectl apply -f k8s-manifests/

# Get shell access to a pod
kubectl exec -it <POD_NAME> -n todo-app -- /bin/sh

# Port forward for debugging
kubectl port-forward svc/<SERVICE_NAME> <LOCAL_PORT>:<POD_PORT> -n todo-app

# Check resource usage
kubectl top pod -n todo-app
```

---

## Performance and Best Practices

### Resource Limits
The deployment includes resource limits to ensure stability:
- Backend: `cpu: 200m`, `memory: 256Mi`
- Frontend: `cpu: 100m`, `memory: 128Mi`
- PostgreSQL: `cpu: 500m`, `memory: 512Mi`

If pods are being OOMKilled, increase memory limits in the deployment manifests.

### Health Checks
All deployments include liveness and readiness probes:
- **Liveness**: Ensures pod restarts if application hangs
- **Readiness**: Ensures pod only receives traffic when ready to serve requests

### Logging
Monitor logs for these common patterns:
- `ERROR`: Indicates an issue that needs attention
- `WARN`: Indicates degraded but functional behavior
- `INFO`: Normal operational information

### Data Persistence
- PostgreSQL uses a StatefulSet with persistent volumes
- Data survives pod restarts and node failures
- Verify PersistentVolumeClaims (PVCs) are bound:
  ```bash
  kubectl get pvc -n todo-app
  ```

---

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [KIND Documentation](https://kind.sigs.k8s.io/)
- [killercoda.com](https://killercoda.com/)
- [PostgreSQL in Kubernetes](https://kubernetes.io/docs/tasks/run-application/run-replicated-stateful-application/)

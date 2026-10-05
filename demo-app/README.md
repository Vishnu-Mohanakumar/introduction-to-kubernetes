# Demo Application - Phase 4

This Python Flask web application demonstrates how Kubernetes resources work together in a real application.

## What This App Shows

This Flask web application demonstrates these Kubernetes concepts:

1. **Namespaces** - Isolated environment (`demo-app` namespace)
2. **ConfigMaps** - Application settings (app name, version, environment)
3. **Secrets** - Sensitive data (database passwords, API keys)
4. **ServiceAccounts** - Pod identity for API access
5. **RBAC** - What the app can and cannot do
6. **Deployments** - Running 3 copies of the app
7. **Services** - Load balancing between app instances
8. **Health Checks** - Kubernetes monitors app health

## Prerequisites

- killercoda.com Kubernetes Playground session, or a local KIND cluster running (`workshop`)
- Docker installed (if using KIND)
- kubectl configured

## Files

The app uses 8 numbered Kubernetes manifests, applied in this order:
- `01-namespace.yaml` - Creates isolated space for the app
- `02-configmap.yaml` - App settings (name, version, database URL)
- `03-secrets.yaml` - Sensitive data (usernames, passwords)
- `04-serviceaccount.yaml` - Identity for the app
- `05-roles.yaml` - What the app is allowed to do
- `06-rolebindings.yaml` - Connects identity to permissions
- `07-deployment.yaml` - Runs 3 copies of the app
- `08-service.yaml` - Load balances between the 3 copies

### Configuration Sources
- **ConfigMap** (`demo-app-config`): 12 application settings including feature flags
- **Secrets** (`demo-app-secrets`): Database credentials, API keys, application secrets
- **Environment Injection**: Pod metadata, service information, RBAC permissions

### Security Implementation
- **ServiceAccount**: `demo-app-sa` with specific permissions
- **RBAC Roles**: Namespace-scoped and cluster-wide permissions
- **Security Context**: Non-root execution, capability dropping

## Build and Load the Image

```bash
docker build -t k8s-demo-app:latest .

# On KIND: load into the cluster (copies to every node)
kind load docker-image k8s-demo-app:latest --name workshop  # KIND only
docker exec workshop-control-plane crictl images | grep k8s-demo-app
docker exec workshop-worker crictl images | grep k8s-demo-app

# On killercoda: docker build alone is NOT enough - see the top-level README's
# killercoda section for why (separate containerd image namespace, either node can be
# scheduled to). Shortcut once you understand why:
bash ../killercoda/load-image.sh k8s-demo-app:latest
```

## Deploy

Two ways to do this - pick whichever fits what you're doing right now.

### Fast path (just want it running)

```bash
kubectl apply -f k8s-manifests/
kubectl rollout status deployment/demo-app-deployment -n demo-app
kubectl get pods -n demo-app
```

### Guided walkthrough (~30-40 minutes, recommended for a live session)

Apply each manifest on its own so you can inspect the resource it creates before moving to the next one - this is what actually teaches the concepts, rather than just getting the app running.

**1. Namespace and Configuration (~5 min)**
```bash
kubectl apply -f k8s-manifests/01-namespace.yaml
kubectl get namespaces
kubectl describe namespace demo-app

kubectl apply -f k8s-manifests/02-configmap.yaml
kubectl get configmaps -n demo-app
kubectl describe configmap demo-app-config -n demo-app
```
Talking points: namespaces provide logical separation and resource organization; ConfigMaps store non-sensitive configuration as key-value pairs, decoupled from application code.

**2. Secrets (~5 min)**
```bash
kubectl apply -f k8s-manifests/03-secrets.yaml
kubectl get secrets -n demo-app
kubectl describe secret demo-app-secrets -n demo-app   # notice values aren't shown

# Decode a value (for demo purposes only)
kubectl get secret demo-app-secrets -n demo-app -o yaml
echo "ZGVtb3VzZXI=" | base64 -d
```
Talking points: Secrets are base64-encoded, not encrypted, by default; `kubectl describe` deliberately hides values; in production use a real secret manager (Vault, cloud KMS).

**3. RBAC - ServiceAccount, Roles, RoleBindings (~8 min)**
```bash
kubectl apply -f k8s-manifests/04-serviceaccount.yaml
kubectl describe serviceaccount demo-app-sa -n demo-app

kubectl apply -f k8s-manifests/05-roles.yaml
kubectl describe role demo-app-role -n demo-app
kubectl get clusterroles | grep demo-app

kubectl apply -f k8s-manifests/06-rolebindings.yaml
kubectl describe rolebinding demo-app-rolebinding -n demo-app
kubectl get clusterrolebindings | grep demo-app
```
Talking points: ServiceAccounts give pods an identity for talking to the Kubernetes API; Roles define permissions within a namespace, ClusterRoles cluster-wide; RoleBindings connect identity to permissions - this is the principle of least privilege in action.

**4. Deploy the application (~5 min)**
```bash
kubectl apply -f k8s-manifests/07-deployment.yaml
kubectl rollout status deployment/demo-app-deployment -n demo-app
kubectl get pods -n demo-app
kubectl describe pod <pod-name> -n demo-app
kubectl get replicasets -n demo-app
```
Talking points: Deployments manage ReplicaSets, which manage Pods; watch how ConfigMap/Secret values get injected as environment variables; the pods run under our custom ServiceAccount.

**5. Service and networking (~5 min)**
```bash
kubectl apply -f k8s-manifests/08-service.yaml
kubectl describe service demo-app-service -n demo-app
kubectl get endpoints -n demo-app

# Confirm DNS-based service discovery
kubectl run test-pod --image=busybox -n demo-app --rm -it -- nslookup demo-app-service
```
Talking points: Services provide stable networking for pods behind them; Endpoints are managed automatically; ClusterIP services are only reachable from inside the cluster.

**6. Access the application (~7 min)**
```bash
kubectl port-forward -n demo-app service/demo-app-service 8080:80 &
curl http://localhost:8080/health
curl http://localhost:8080/api/info
open http://localhost:8080
```

## What You'll See

### Web Dashboard
When you open the app in your browser, you'll see:

- **Pod Information** - Which pod you're connected to, its IP address, what node it's running on
- **Configuration** - Settings loaded from ConfigMaps (app name, version, environment)
- **Secrets** - Safely masked credentials (only the last few characters shown)
- **Permissions** - What this app can do in Kubernetes (check pods, read configs, create secrets)
- **Network** - Service details and how pods connect to each other

Tour it live: point out the pod name/IP/node assignment, the ConfigMap-sourced settings, the masked secret form, the RBAC permission checks, and the service/endpoint info - each maps directly to a manifest you just applied.

### API Endpoints
```bash
GET /health              # Health check (what Kubernetes uses to monitor the app)
GET /api/info             # All the app data as JSON
POST /store-secret        # Try storing a new secret
```

## Try These Experiments

### Change Configuration
```bash
kubectl patch configmap demo-app-config -n demo-app -p '{"data":{"APP_NAME":"My Custom App"}}'
kubectl rollout restart deployment/demo-app-deployment -n demo-app
# Refresh the browser - the new app name shows up
```

### Scale the App
```bash
kubectl scale deployment demo-app-deployment --replicas=5 -n demo-app
kubectl get pods -n demo-app -w
kubectl get endpoints demo-app-service -n demo-app   # endpoints update automatically

# Scale back down
kubectl scale deployment demo-app-deployment --replicas=3 -n demo-app
```
Scaling is just changing the replica count - Kubernetes handles endpoint updates and load balancing automatically.

### Check What the App Can Do
```bash
kubectl auth can-i --list --as=system:serviceaccount:demo-app:demo-app-sa -n demo-app
```

## Management Commands

`deploy.sh` automates the whole lifecycle (cluster create/delete, build, load, deploy, status, port-forward, cleanup) - useful as a fast reset between sessions or cohorts, but run the guided walkthrough above at least once yourself so you understand what each step actually does:

```bash
./deploy.sh setup          # Complete setup (cluster + app)
./deploy.sh all            # Build, deploy, and port forward
./deploy.sh build          # Build and load image only
./deploy.sh deploy         # Deploy application only
./deploy.sh status         # Check application status
./deploy.sh forward        # Start port forwarding
./deploy.sh clean          # Remove application resources
./deploy.sh teardown       # Complete cleanup (app + cluster)
```

## Troubleshooting

### Check Everything is Working
```bash
kubectl get all -n demo-app
kubectl logs -f deployment/demo-app-deployment -n demo-app
curl http://localhost:8080/health
```

### Image Pull Issues
```bash
# If the image isn't found on a node, reload it
kind load docker-image k8s-demo-app:latest --name workshop
```

### Pod Not Starting
```bash
kubectl describe pod <pod-name> -n demo-app
kubectl get events -n demo-app --sort-by='.lastTimestamp'
```

### Port Forward Issues
```bash
pkill -f "kubectl port-forward"
kubectl port-forward -n demo-app service/demo-app-service 8080:80
```

### RBAC Issues
```bash
kubectl get secrets -n demo-app | grep demo-app-sa
kubectl auth can-i --list --as=system:serviceaccount:demo-app:demo-app-sa -n demo-app
```

## Key Learning Outcomes

By the end of this, you should have seen:

1. **Namespace Organization** - Logical separation of resources
2. **Configuration Management** - ConfigMaps vs Secrets
3. **Security** - RBAC with ServiceAccounts, Roles, and RoleBindings
4. **Application Deployment** - Deployments, ReplicaSets, and Pods
5. **Networking** - Services, Endpoints, and port forwarding
6. **Scaling** - Horizontal scaling of applications
7. **Real-world Integration** - How applications consume Kubernetes resources

## Clean Up

```bash
kubectl delete namespace demo-app
# This deletes all the resources at once
```

---

**This app shows how all the Kubernetes pieces work together in a real application!**

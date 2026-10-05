# 📌 Lab Assignment - LOCAL ONLY

## ✅ This Assignment Works Entirely on Your Local Computer

**Important:** You do NOT need:
- ❌ Cloud provider account (AWS, GCP, Azure)
- ❌ External container registry (Docker Hub, Quay.io)
- ❌ External database service
- ❌ External cache service
- ❌ Any paid services
- ❌ Internet connection (after initial setup)

**You DO need:**
- ✅ killercoda.com's Kubernetes Playground (has Docker + kubectl pre-installed), or a local KIND cluster
- ✅ kubectl installed (if using KIND)
- ✅ This repository cloned locally

---

## 🎯 What You're Building

A complete microservices Todo application running on **your local Kubernetes cluster**:

```
killercoda.com Playground or Your Laptop (KIND)
├── Kubernetes
│   ├── PostgreSQL database (runs as pod)
│   ├── Redis cache (runs as pod)
│   ├── Flask backend API (runs as pod)
│   └── Nginx frontend (runs as pod)
└── Docker
    └── Builds your container images locally
```

**Everything runs on your machine. Period.**

---

## 📋 Assignment Overview

### Part 1: Understand the Application
- Review the provided code in `lab-solution/beginner/todo-app/`
- Understand the Flask backend API
- See how the Nginx frontend proxies requests
- Notice how the app connects to PostgreSQL and Redis

### Part 2: Write Kubernetes Manifests (Main Task)
Create the following files in a `k8s/` directory:

1. `01-namespace.yaml` - Application namespace
2. `02-configmaps.yaml` - Configuration for all services
3. `03-secrets.yaml` - Database passwords
4. `04-serviceaccounts.yaml` - RBAC service accounts
5. `05-roles.yaml` - RBAC role definitions
6. `06-rolebindings.yaml` - Bind roles to accounts
7. `07-postgres-statefulset.yaml` - PostgreSQL (3 replicas)
8. `08-redis-deployment.yaml` - Redis cache
9. `09-services.yaml` - All services (postgres, redis, backend, frontend)
10. `10-deployments.yaml` - Backend and frontend deployments

**Reference:** See the complete solution in `lab-solution/beginner/k8s-manifests/`

### Part 3: Deploy Locally
```bash
# Build images locally
docker build -t todo-backend:latest ./backend
docker build -t todo-frontend:latest ./frontend

# Load into local Kubernetes (KIND only)
kind load docker-image todo-backend:latest --name workshop
kind load docker-image todo-frontend:latest --name workshop

# Deploy
kubectl apply -f k8s/

# Access
kubectl port-forward service/frontend-service 8080:80
# Open: http://localhost:8080
```

### Part 4: Test Everything
- ✅ Frontend UI accessible at localhost:8080
- ✅ Create/read/update/delete todos
- ✅ Check statistics
- ✅ Delete pods and watch them recover
- ✅ Verify database data persists

---

## 🏗️ Architecture - All Local

```
Frontend (Nginx)
    ↓ (reverse proxy)
Backend API (Flask)
    ↓ (SQL queries)         ↓ (cache queries)
PostgreSQL                Redis
(3 replicas)            (1 replica)
(local storage)         (local storage)
```

**All components run as containers in your local Kubernetes cluster.**

---

## 🚀 Quick Start (15 minutes)

### 1. Setup Kubernetes (5 min)

**killercoda.com (recommended for quick iteration):**
- Start the Kubernetes Playground scenario at killercoda.com
- `kubectl` and `docker` are pre-installed
- Sessions reset when they time out - redeploy your manifests each time you resume

**KIND (if you want a cluster that stays up across the week):**
```bash
kind create cluster --config ../../kind/kind.config.yaml --name workshop
```

### 2. Build & Deploy Solution (5 min)
```bash
cd lab-solution/beginner
cd todo-app
docker build -t todo-backend:latest ./backend
docker build -t todo-frontend:latest ./frontend
cd ..
kind load docker-image todo-backend:latest --name workshop  # KIND only
kind load docker-image todo-frontend:latest --name workshop # KIND only
cd k8s-manifests
./deploy.sh
```

### 3. Access Application (5 min)
```bash
kubectl port-forward -n todo-app service/frontend-service 8080:80
# Open: http://localhost:8080
```

**That's it!** Your application is running locally.

---

## 📚 What You'll Learn

✅ **Kubernetes Concepts**
- StatefulSets for persistent databases
- Deployments for stateless services
- Services for networking
- ConfigMaps and Secrets
- RBAC security

✅ **Local Development Workflow**
- Building container images
- Running local Kubernetes
- Service discovery via DNS
- Persistent storage
- Debugging and troubleshooting

✅ **Microservices Patterns**
- Service-to-service communication
- Configuration management
- Secret handling
- Health checks
- Pod recovery

---

## 🔍 Key Differences: Local vs. Production

### Local Setup (This Assignment)
- ✅ All containers run on your laptop
- ✅ Local storage (no cloud volumes)
- ✅ Local DNS for service discovery
- ✅ No external authentication
- ✅ No registry authentication needed
- ✅ Complete control and visibility

### Production Setup (Future Learning)
- Will use: Cloud registries, managed databases, cloud storage, load balancers
- But: **Same Kubernetes manifests work!** Just point to cloud resources

**Your local knowledge transfers directly to production.**

---

## 💡 Important Concepts

### Service Discovery (Local DNS)
```yaml
# In your manifests, services are discovered by name:
env:
  - name: DB_HOST
    value: postgres-service  # Resolves via local DNS
  - name: REDIS_HOST
    value: redis-service     # Resolves via local DNS
```

### Image Handling (Local)
```bash
# Build locally
docker build -t todo-backend:latest ./backend

# Load into local cluster (KIND)
kind load docker-image todo-backend:latest --name workshop

# In manifests, use Never policy so K8s doesn't try to pull:
imagePullPolicy: Never
image: todo-backend:latest
```

### Storage (Local Volumes)
```yaml
# PersistentVolumeClaim for database
# Stored on your laptop
# Survives pod restarts
# NOT backed by cloud storage
volumeMounts:
  - name: postgres-storage
    mountPath: /var/lib/postgresql/data
```

---

## ✅ Success Criteria

### Your lab is complete when:

1. ✅ All 10 YAML files are created
2. ✅ Deployment succeeds: `kubectl apply -f k8s/` works
3. ✅ All pods Running: `kubectl get pods -n todo-app` shows all Running
4. ✅ Frontend accessible: http://localhost:8080 works
5. ✅ Can create todos via UI
6. ✅ Can view todos via API: `curl http://localhost:5000/api/todos`
7. ✅ Database persists data after pod restart
8. ✅ Deleted pods are automatically recovered

---

## 📝 Requirements

### Core (Must Have)
- [ ] Namespace with labels
- [ ] PostgreSQL StatefulSet (3 replicas, persistent storage)
- [ ] Backend Deployment (2 replicas)
- [ ] Frontend Deployment (2 replicas)
- [ ] Redis Deployment (1 replica)
- [ ] All services working (postgres, redis, backend, frontend)
- [ ] ConfigMaps for configuration
- [ ] Secrets for passwords (base64 encoded)
- [ ] ServiceAccounts for RBAC
- [ ] Roles and RoleBindings

### Production Features (Should Have)
- [ ] Resource limits (CPU, memory)
- [ ] Health checks (liveness, readiness probes)
- [ ] Proper labels and selectors
- [ ] Security contexts
- [ ] Correct image pull policies

### Bonus (Nice to Have)
- [ ] Network policies
- [ ] Horizontal Pod Autoscaler
- [ ] Deploy script
- [ ] Comprehensive README

---

## 🛠️ Tools You'll Use (All Free & Local)

| Tool | Purpose | Cost |
|------|---------|------|
| killercoda.com | Live Kubernetes Playground, no install | Free |
| Docker | Build container images | Free |
| KIND | Persistent local Kubernetes cluster | Free |
| kubectl | Kubernetes CLI | Free |
| PostgreSQL | Database | Free (containerized) |
| Redis | Cache | Free (containerized) |
| Nginx | Web server | Free (containerized) |

**Total cost of assignment: $0** (all open source, all local)

---

## 🎓 Reference Materials

### In This Repository
- `demo-manifests/` - Examples from the workshop
- `demo-manifests/components/` - Individual K8s resources
- `demo-manifests/database/` - StatefulSet example
- `lab-solution/beginner/k8s-manifests/` - Complete solution

### External Documentation
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [StatefulSets Guide](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Services Guide](https://kubernetes.io/docs/concepts/services-networking/service/)
- [RBAC Guide](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

---

## ❓ FAQ

### Q: Do I need to push images to Docker Hub?
**A:** No! Images stay on your local machine. KIND loads them directly.

### Q: Can I use killercoda.com instead of KIND?
**A:** Yes! You skip the `kind load` commands, but `docker build` alone isn't enough there either - see the top-level README's killercoda section for the `ctr` import steps needed on each node. Also remember sessions are time-limited and reset, so redeploy each time you resume.

### Q: What if I don't have an internet connection?
**A:** After initial Docker image downloads, you don't need internet. Everything runs locally.

### Q: Can I access the app from other computers?
**A:** Not easily with local Kubernetes. For sharing, you'd need Ingress or NodePort (bonus challenges).

### Q: What happens if I delete the entire namespace?
**A:** Everything is deleted, including PersistentVolumes and data. But you can redeploy from manifests.

### Q: How do I debug connectivity issues?
**A:** Use `kubectl exec` to run commands in pods and test service connectivity locally.

---

## 🎯 After You're Done

### Next Steps
1. ✅ Complete the lab locally
2. 📖 Read the `lab-solution/beginner/` for reference
3. 💭 Compare your manifests with the solution
4. 🔍 Understand why the solution works
5. 🚀 Experiment: modify replicas, add resources, change configs

### Beyond Lab
- Add Ingress for external access (no port-forward)
- Implement monitoring with Prometheus
- Add NetworkPolicies for security
- Explore GitOps deployment tools
- Learn about operators and custom resources

---

## 📞 Getting Help

### When Debugging
1. Check pod status: `kubectl describe pod <name> -n todo-app`
2. Check logs: `kubectl logs <pod> -n todo-app`
3. Compare with solution: `lab-solution/beginner/k8s-manifests/`
4. Test connectivity: `kubectl exec -it <pod> -n todo-app -- bash`

### Resources
- Workshop materials in `demo-manifests/`
- Solution in `lab-solution/beginner/`
- Kubernetes documentation online
- Ask instructors!

---

## ✨ Final Notes

**This assignment is designed to:**
- ✅ Teach you real Kubernetes concepts
- ✅ Work completely on your laptop
- ✅ Have zero external dependencies
- ✅ Be free and open source
- ✅ Be relevant to production work

**You're learning the same Kubernetes you'd use in production - just running locally first!**

Good luck! 🚀

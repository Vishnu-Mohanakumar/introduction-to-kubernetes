# Kubernetes Lab Assignment - Questions and Requirements

## Assignment Overview

This lab assignment requires you to implement a complete microservices Todo application on Kubernetes with **zero external dependencies**. All services (database, cache, backend, frontend) must run within the local Kubernetes cluster.

---

## Part 1: Architecture & Design (20 points)

### Question 1.1: System Architecture (5 points)
Design a complete microservices architecture for a Todo application with the following components:
- **Frontend**: Web UI served by Nginx
- **Backend**: REST API using Flask/Python
- **Database**: Persistent data storage (PostgreSQL)
- **Cache**: In-memory caching layer (Redis)

**Requirements:**
1. Draw or describe the architecture showing all services and their interactions
2. Identify which services are stateful vs stateless
3. Explain how services communicate within the cluster
4. Describe data flow from user action → frontend → backend → database

**Expected Answer Should Include:**
- Service dependencies (frontend depends on backend, backend depends on database and Redis)
- Communication protocol (HTTP/REST between frontend and backend, TCP to PostgreSQL/Redis)
- Data persistence strategy (PostgreSQL for persistent data, Redis for caching)
- Network isolation using Kubernetes services and namespaces

### Question 1.2: Kubernetes Resources (5 points)
Identify and explain the following Kubernetes resources needed for this deployment:
1. **Namespace** - Why is it needed?
2. **Deployment** - For which services and why?
3. **StatefulSet** - For which service and why?
4. **Service** - What types are needed (ClusterIP, NodePort, etc.)?
5. **PersistentVolume/PersistentVolumeClaim** - What data needs to persist?
6. **ConfigMap** - What configuration should be externalized?
7. **Secret** - What sensitive data needs protection?
8. **ServiceAccount & RBAC** - What permissions does each service need?

**Expected Answer Should Explain:**
- Why StatefulSet for PostgreSQL (ordered identity, stable hostname for replication)
- Why Deployment for stateless services (easy scaling)
- Why NodePort for frontend (external access), ClusterIP for internal services
- Security implications of RBAC configuration

### Question 1.3: High Availability (5 points)
How would you make this application highly available? Consider:
1. How many replicas should each service have?
2. What happens if a pod crashes?
3. How does Kubernetes handle service discovery when pods are recreated?
4. How do you ensure database consistency across multiple replicas?

**Expected Answer Should Include:**
- Replica counts: typically 2+ for stateless services, 3+ for StatefulSets
- Kubernetes automatically recreates failed pods via ReplicaSet
- Service abstraction provides consistent DNS names and load balancing
- Database replication strategies (streaming replication for PostgreSQL)

### Question 1.4: Zero External Dependencies (5 points)
The assignment states "zero external dependencies". Explain:
1. What does this mean in the context of Kubernetes?
2. What external services are typically required for web applications?
3. How do we eliminate them in this assignment?
4. What are the limitations of this approach for production?

**Expected Answer Should Include:**
- External dependencies: managed databases (AWS RDS, Cloud SQL), cloud storage, etc.
- This assignment uses self-managed PostgreSQL and Redis within the cluster
- Limitations: no automatic backups, no managed updates, manual scaling

---

## Part 2: Implementation (40 points)

### Question 2.1: Dockerfile for Backend (10 points)
Create a Dockerfile for the Flask backend API with the following requirements:
1. Use Python 3.11 slim base image
2. Install required dependencies
3. Copy application code
4. Expose port 5000
5. Set appropriate health check
6. Run as non-root user for security

**Grading Criteria:**
- Uses minimal base image (slim, alpine)
- Proper layer caching (dependencies before code)
- Correct port exposure (5000)
- Health check configured
- Non-root user for security
- No hardcoded secrets in Dockerfile

**Key Considerations:**
- Layer order matters for build cache efficiency
- Health checks help Kubernetes determine pod readiness
- Non-root users prevent container escape vulnerabilities

### Question 2.2: Dockerfile for Frontend (10 points)
Create a Dockerfile for the Nginx frontend with the following requirements:
1. Use nginx:alpine base image
2. Copy custom nginx configuration
3. Copy static files (HTML, CSS, JavaScript)
4. Properly configure for SPA (Single Page Application)
5. Set appropriate health check
6. Security best practices

**Grading Criteria:**
- Uses minimal base image
- Correct Nginx configuration for SPA
- Static files in correct location
- Health check endpoint configured
- Proper file permissions
- CORS or proxy configuration for API calls

**Key Considerations:**
- SPA requires proper routing configuration (all non-file requests to index.html)
- Must proxy API calls to backend service
- Health check should verify Nginx is responsive

### Question 2.3: Kubernetes Manifests (10 points)
Create YAML manifests for all Kubernetes resources:

**Manifests to Create:**
1. Namespace
2. ConfigMaps (configuration for each service)
3. Secrets (database password, API keys)
4. ServiceAccounts & RBAC (Role, RoleBinding)
5. PostgreSQL StatefulSet with PVC
6. Redis Deployment
7. Backend Deployment with ConfigMap, Secrets, Probes
8. Frontend Deployment with ConfigMap, Probes
9. Services (ClusterIP, NodePort, Headless)

**Grading Criteria:**
- All resources properly namespaced
- ConfigMaps used for non-sensitive configuration
- Secrets used for passwords and sensitive data
- Proper resource requests and limits
- Liveness and Readiness probes configured
- Service ports correctly mapped
- StatefulSet for stateful services

**Key Requirements:**
- Backend resources: `cpu: 200m, memory: 256Mi`
- Frontend resources: `cpu: 100m, memory: 128Mi`
- Readiness probe delay for database connection
- StatefulSet with 3 PostgreSQL replicas
- Persistent volume for PostgreSQL data

### Question 2.4: Application Code (10 points)
Implement the backend API with the following endpoints:

**Endpoints Required:**
1. `GET /health` - Basic health check
2. `GET /health/ready` - Readiness probe (database connectivity)
3. `GET /health/live` - Liveness probe (application alive)
4. `GET /api/todos` - List all todos with optional filtering
5. `POST /api/todos` - Create new todo
6. `GET /api/todos/<id>` - Get specific todo
7. `PUT /api/todos/<id>` - Update todo
8. `DELETE /api/todos/<id>` - Delete todo
9. `GET /api/stats` - Get statistics

**Grading Criteria:**
- All endpoints implemented and functional
- Proper HTTP status codes
- Database queries work correctly
- Error handling with meaningful messages
- Logging for debugging
- Redis caching for performance
- Environment variables for configuration

---

## Part 3: Deployment & Testing (25 points)

### Question 3.1: Local Deployment (10 points)
Deploy the complete application to a Kubernetes cluster: killercoda.com's Kubernetes Playground, or a local KIND cluster.

**Requirements:**
1. Build Docker images for frontend and backend
2. Push images to cluster (or ensure they're in correct Docker context)
3. Apply all Kubernetes manifests
4. Wait for all pods to reach Running state
5. Initialize database schema and sample data
6. Port forward services to localhost
7. Verify all components are operational

**Checklist:**
- [ ] All pods show `1/1 Running` or appropriate count
- [ ] Services show correct IP addresses and ports
- [ ] Frontend accessible on `http://localhost:8080`
- [ ] Backend API responding on `http://localhost:5000`
- [ ] Database initialized with sample todos
- [ ] No error logs in pod logs

### Question 3.2: Functionality Testing (10 points)
Test all application functionality:

**Test Cases:**
1. **Frontend loads**: Browser shows Todo UI at `http://localhost:8080`
2. **View todos**: Frontend displays all todos from backend
3. **Create todo**: Add new todo via UI, verify in database
4. **Update todo**: Edit todo, mark complete, verify changes persist
5. **Delete todo**: Remove todo, verify it's gone
6. **Data persistence**: Delete pod, verify data survives
7. **API direct calls**: Test backend endpoints with curl/Postman
8. **Health checks**: Verify all health check endpoints work
9. **Error handling**: Verify appropriate error messages
10. **Performance**: Verify caching is working (Redis)

**How to Verify Each:**
- Frontend: Visual inspection in browser
- API calls: `curl http://localhost:5000/api/todos`
- Database persistence: `kubectl get pvc` shows bound volumes
- Pod restart: `kubectl delete pod <NAME>` then check data
- Caching: Check redis-cli or backend logs for cache hits

### Question 3.3: Documentation (5 points)
Create documentation for deploying and maintaining the application:

**Documentation Should Include:**
1. **Prerequisites**: What needs to be installed
2. **Step-by-step deployment guide**: Command sequence to deploy
3. **Troubleshooting guide**: Common errors and solutions
4. **Architecture diagram**: Visual representation of services
5. **Configuration guide**: How to change settings
6. **Scaling guide**: How to scale individual services
7. **Backup/recovery**: How to backup and restore data
8. **Monitoring**: What to watch for in logs

---

## Part 4: Troubleshooting & Problem Solving (15 points)

### Question 4.1: Error Scenarios (5 points)
You encounter this error during deployment:
```
Failed to pull image "todo-backend:latest": rpc error: code = NotFound desc = failed to pull and unpack image
ImagePullBackOff
```

**Tasks:**
1. Identify the root cause
2. Explain why this happens with KIND specifically
3. Provide the solution with commands
4. Explain how to prevent this in future deployments

**Expected Answer:**
- Root cause: the image was built locally but never loaded into the KIND cluster's container runtime, and `imagePullPolicy: Never`/`IfNotPresent` means Kubernetes won't try to pull it from a registry
- Solution: `kind load docker-image todo-backend:latest --name workshop`, then verify with `docker exec workshop-control-plane crictl images | grep todo-backend`
- Prevention: on KIND, always run `kind load docker-image` right after building, before applying manifests. On killercoda, `docker build` alone is not enough either - the image also needs importing into containerd's `k8s.io` namespace via `ctr`, on every node pods can be scheduled to (see the top-level README's killercoda section)

### Question 4.2: Performance Issues (5 points)
The frontend works, but loading todos is slow. Investigate:

**Questions:**
1. What are potential bottlenecks?
2. How would you identify which service is slow?
3. What debugging commands would you use?
4. How would you optimize performance?

**Expected Answer Should Include:**
- Potential causes: slow database queries, no caching, network latency
- Debugging: check logs, use time curl commands, check database query performance
- Optimization: add database indexes, implement caching (Redis), optimize queries

### Question 4.3: Data Loss Scenario (5 points)
A PostgreSQL pod crashes and loses its data:

**Tasks:**
1. Explain what should happen (data should NOT be lost)
2. How does PersistentVolume prevent data loss?
3. What would you check to verify data is safe?
4. How would you recover from data loss if it occurred?

**Expected Answer Should Include:**
- With PersistentVolume, data survives pod restart
- PVC persists data even if pod is deleted
- Check: `kubectl get pvc`, `kubectl describe pvc`
- Recovery: database backup/restore, StatefulSet re-initialization

---

## Part 5: Advanced Topics (Bonus - 10 points)

### Question 5.1: Scaling (5 bonus points)
How would you scale this application for production?

**Consider:**
1. Frontend scaling: increase replicas, use CDN
2. Backend scaling: horizontal scaling, load balancing
3. Database scaling: read replicas, sharding
4. Cache scaling: Redis Cluster
5. Storage scaling: larger volumes, multi-zone persistence

### Question 5.2: Security (5 bonus points)
What security improvements would you make for production?

**Consider:**
1. Container security: image scanning, admission controllers
2. Network security: network policies, service mesh
3. Secret management: external secret stores
4. RBAC: principle of least privilege
5. Monitoring: audit logs, intrusion detection

---

## Submission Requirements

### What to Submit

1. **Complete Dockerfiles**
   - `backend/Dockerfile`
   - `frontend/Dockerfile`

2. **Kubernetes Manifests**
   - All YAML files for deployment

3. **Application Source Code**
   - Backend: Flask REST API
   - Frontend: HTML/CSS/JavaScript

4. **Documentation**
   - Architecture design document
   - Step-by-step deployment guide
   - Troubleshooting guide
   - README with overview

5. **Testing Results**
   - Screenshots or logs showing successful deployment
   - Test results for all functionality
   - Performance metrics (response times)

### Deliverable Structure

```
lab-solution/
├── README.md                           # Overview
├── DEPLOYMENT_STEPS.md                # Step-by-step guide
├── TROUBLESHOOTING_AND_ERRORS.md     # Error solutions
├── todo-app/
│   ├── backend/
│   │   ├── Dockerfile
│   │   ├── app.py
│   │   ├── requirements.txt
│   │   └── README.md
│   └── frontend/
│       ├── Dockerfile
│       ├── nginx.conf
│       ├── index.html
│       ├── style.css
│       ├── script.js
│       └── README.md
└── k8s-manifests/
    ├── 00-namespace.yaml
    ├── 01-configmaps.yaml
    ├── 02-secrets.yaml
    ├── 03-serviceaccount.yaml
    ├── 04-role.yaml
    ├── 05-rolebinding.yaml
    ├── 06-postgres-statefulset.yaml
    ├── 07-postgres-service.yaml
    ├── 08-redis-deployment.yaml
    ├── 09-redis-service.yaml
    ├── 10-deployments.yaml
    └── README.md
```

### Grading Rubric

| Category | Points | Criteria |
|----------|--------|----------|
| **Architecture & Design** | 20 | Understanding of microservices, k8s resources, HA, dependencies |
| **Implementation** | 40 | Dockerfiles, Manifests, Application Code quality |
| **Deployment & Testing** | 25 | Successful deployment, all tests passing, documentation |
| **Troubleshooting** | 15 | Problem analysis, debugging skills, error resolution |
| **Bonus: Advanced Topics** | 10 | Scaling, Security improvements, optimization |
| **TOTAL** | **100+** | Complete working solution |

---

## Getting Help

If you're stuck:

1. **Check the troubleshooting guide**: Most common issues are documented
2. **Review the deployment steps**: Ensure you followed each step
3. **Check pod logs**: `kubectl logs <POD> -n todo-app`
4. **Describe resources**: `kubectl describe pod <POD> -n todo-app`
5. **Check events**: `kubectl get events -n todo-app`

---

## Key Learning Outcomes

By completing this assignment, you should understand:

1. ✅ How to containerize applications with Docker
2. ✅ How to deploy multi-tier applications to Kubernetes
3. ✅ How to manage configuration and secrets
4. ✅ How Kubernetes provides high availability and resilience
5. ✅ How to troubleshoot and debug Kubernetes deployments
6. ✅ How microservices communicate within a cluster
7. ✅ How to persist data in Kubernetes
8. ✅ How to implement health checks and monitoring

---

## Important Notes

- **Time estimate**: 15-20 hours (depending on experience)
- **Cluster requirement**: killercoda.com's Kubernetes Playground, or a local KIND cluster
- **Resources needed**: 4+ GB RAM, 20+ GB disk space if using KIND
- **No managed cloud services allowed**: no managed database, cache, or storage - PostgreSQL and Redis must run as pods in your cluster. The cluster itself can be killercoda's remote sandbox or a local KIND cluster; either is fine, since neither is a managed service

Good luck! 🚀

# StatefulSet Deep Dive: Database Operations & Recovery

## 🏗️ How StatefulSets Work

### **StatefulSet vs Deployment - Key Differences**

#### Deployment (Stateless):
```bash
# Pods are interchangeable
webapp-deployment-abc123
webapp-deployment-def456
webapp-deployment-ghi789

# Any pod can be killed/replaced
# No persistent identity
# Random names and IPs
```

#### StatefulSet (Stateful):
```bash
# Pods have stable, predictable names
postgres-0  # Always the first pod
postgres-1  # Always the second pod  
postgres-2  # Always the third pod

# Ordered startup: 0 → 1 → 2
# Ordered shutdown: 2 → 1 → 0
# Each pod keeps its identity across restarts
```

## 🔄 StatefulSet Lifecycle Management

### **Pod Creation Process:**
```bash
# 1. Create postgres-0 first
# 2. Wait for postgres-0 to be Ready
# 3. Create postgres-1
# 4. Wait for postgres-1 to be Ready
# 5. Create postgres-2
```

### **Pod Deletion Process:**
```bash
# 1. Delete postgres-2 first (highest ordinal)
# 2. Wait for postgres-2 to be completely gone
# 3. Delete postgres-1  
# 4. Wait for postgres-1 to be completely gone
# 5. Delete postgres-0 (last)
```

### **What Happens When a Pod Dies:**

```yaml
# Before failure:
postgres-0: Running, PVC: postgres-storage-postgres-0
postgres-1: Running, PVC: postgres-storage-postgres-1  
postgres-2: Running, PVC: postgres-storage-postgres-2

# postgres-1 pod crashes or is deleted
postgres-0: Running, PVC: postgres-storage-postgres-0
postgres-1: Terminating/Pending
postgres-2: Running, PVC: postgres-storage-postgres-2

# Kubernetes recreates postgres-1
postgres-0: Running, PVC: postgres-storage-postgres-0
postgres-1: Running, PVC: postgres-storage-postgres-1 (SAME PVC!)
postgres-2: Running, PVC: postgres-storage-postgres-2
```

## 💾 Persistent Volume Claims (PVCs)

### **How PVCs Work with StatefulSets:**

```yaml
apiVersion: apps/v1
kind: StatefulSet
spec:
  serviceName: postgres-headless  # Required for stable network identity
  volumeClaimTemplates:           # Creates PVC for each pod
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
```

**This creates:**
```bash
# PVCs (automatically created)
postgres-storage-postgres-0  # For postgres-0 pod
postgres-storage-postgres-1  # For postgres-1 pod
postgres-storage-postgres-2  # For postgres-2 pod

# PVs (created by storage class)
pv-001  # Bound to postgres-storage-postgres-0
pv-002  # Bound to postgres-storage-postgres-1
pv-003  # Bound to postgres-storage-postgres-2
```

## 🏥 Database Recovery Scenarios

### **Scenario 1: Pod Crashes**
```bash
# What happens:
1. postgres-1 pod crashes
2. Kubernetes sees StatefulSet needs 3 replicas
3. Kubernetes creates new postgres-1 pod
4. New pod mounts SAME PVC (postgres-storage-postgres-1)
5. PostgreSQL starts with existing data intact

# Database perspective:
- Data files preserved on persistent volume
- PostgreSQL recovers from WAL (Write-Ahead Log)
- Database continues from last checkpoint
- No data loss!
```

### **Scenario 2: Node Failure**
```bash
# What happens:
1. Worker node goes down (postgres-1 was running there)
2. Kubernetes marks postgres-1 as "Unknown" 
3. After timeout, Kubernetes creates new postgres-1 on different node
4. PVC follows the pod (if storage supports it)
5. Database recovers on new node

# Requirements:
- Storage must be network-attached (not local)
- Storage class supports zone/node mobility
```

### **Scenario 3: Complete StatefulSet Deletion**
```bash
# Delete StatefulSet
kubectl delete statefulset postgres -n demo-database

# What survives:
✅ PVCs remain (postgres-storage-postgres-0, postgres-storage-postgres-1, postgres-storage-postgres-2)
✅ Data is preserved
✅ Can recreate StatefulSet and reconnect to same data

# Recreate StatefulSet
kubectl apply -f postgres-statefulset.yaml

# Pods reconnect to existing PVCs automatically!
```

## 🌐 Networking: Normal vs Headless Services

### **Normal Service (ClusterIP) - Load Balancer Pattern**

A normal service acts as a **load balancer** with its own virtual IP address.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP  # Default type
  # clusterIP: 10.96.1.100  # Kubernetes assigns automatically
```

**Normal Service Behavior:**
```bash
# Service gets a virtual ClusterIP
kubectl get service web-service
# NAME          TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
# web-service   ClusterIP   10.96.1.100   <none>        80/TCP    1m

# DNS resolves to service IP (load balancer)
nslookup web-service.default.svc.cluster.local
# Answer: 10.96.1.100

# Traffic flow: Client → Service IP → Random Pod
# Perfect for stateless applications (web servers, APIs)
```

### **Headless Service - Direct Pod Access Pattern**

A headless service has **no ClusterIP** and provides **direct access to pods**.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
spec:
  clusterIP: None  # This makes it "headless"
  selector:
    app: postgres
  ports:
  - port: 5432
```

**Headless Service Behavior:**
```bash
# Service shows "None" for ClusterIP
kubectl get service postgres-headless
# NAME                TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
# postgres-headless   ClusterIP   None         <none>        5432/TCP   1m

# DNS returns actual pod IPs (no load balancing)
nslookup postgres-headless.demo-database.svc.cluster.local
# Answer: 10.244.1.5, 10.244.2.8, 10.244.3.12  # All pod IPs

# Each StatefulSet pod gets stable DNS name
postgres-0.postgres-headless.demo-database.svc.cluster.local  # Always postgres-0
postgres-1.postgres-headless.demo-database.svc.cluster.local  # Always postgres-1
postgres-2.postgres-headless.demo-database.svc.cluster.local  # Always postgres-2

# Traffic flow: Client → Specific Pod IP (no load balancing)
```

### **When to Use Each Type**

#### **Normal Service - Use For:**
```bash
✅ Stateless applications (web servers, APIs)
✅ Load balancing across identical pods  
✅ Simple request distribution
✅ When you don't care which pod handles the request

# Examples:
- Web applications
- REST APIs  
- Microservices
- Load-balanced workloads
```

#### **Headless Service - Use For:**
```bash
✅ StatefulSets with persistent identity
✅ Database clusters (primary/replica)
✅ Peer-to-peer applications
✅ When you need to connect to specific pods

# Examples:
- Database replication (connect to specific primary/replica)
- Elasticsearch clusters (master/data nodes)
- Kafka brokers (specific partition leaders)  
- Redis clusters (specific shards)
```

### **Database Example: Why Headless?**

**Problem with Normal Service:**
```bash
# Normal service load balances randomly
Client → Service → Random DB Pod (postgres-0, postgres-1, or postgres-2)

# Issues:
❌ Can't connect to specific database role (primary vs replica)
❌ Connection state not preserved
❌ Can't implement master-slave replication properly
```

**Solution with Headless Service:**
```bash
# Connect to specific database roles
App → postgres-0.postgres-headless... (Primary - writes)
App → postgres-1.postgres-headless... (Replica - reads)
App → postgres-2.postgres-headless... (Replica - reads)

# Benefits:
✅ Applications can choose primary for writes, replicas for reads
✅ Database replication works correctly
✅ Stable connections to specific database instances
✅ Supports leader election and failover patterns
```

## 🔧 Database Operators (Advanced Concept)

### **What is a Database Operator?**

An operator is a **custom controller** that knows how to manage complex applications like databases.

```bash
# Basic StatefulSet (what we're doing):
- Creates pods with persistent storage
- Handles basic restart and recovery
- No application-specific logic

# Database Operator (production approach):
- Creates and manages StatefulSets
- Handles database initialization
- Manages backups and restores  
- Performs rolling upgrades
- Configures replication and failover
- Monitors database health
```

### **Popular Database Operators:**
```bash
# PostgreSQL
- postgres-operator (by Zalando)
- postgresql-operator (by Crunchy Data)

# MySQL  
- mysql-operator (by Oracle)

# MongoDB
- mongodb-enterprise-operator

# Redis
- redis-operator
```

### **Operator vs StatefulSet Comparison:**

#### Our Workshop StatefulSet:
```yaml
# Basic PostgreSQL StatefulSet
- Starts PostgreSQL pods
- Provides persistent storage
- Basic restart on failure
- Manual configuration required
```

#### Production PostgreSQL Operator:
```yaml
# Advanced PostgreSQL management
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-cluster
spec:
  instances: 3
  postgresql:
    parameters:
      max_connections: "100"
      shared_buffers: "256MB"
  bootstrap:
    initdb:
      database: myapp
      user: myuser
  backup:
    retentionPolicy: "30d"
    schedule: "0 0 0 * * *"
  monitoring:
    enabled: true
```

## 📊 Workshop Demo Commands

### **Show StatefulSet Behavior:**
```bash
# Watch ordered startup
kubectl apply -f postgres-statefulset.yaml
kubectl get pods -n demo-database --watch

# Show stable names and PVCs
kubectl get pods,pvc -n demo-database

# Test pod recovery
kubectl delete pod postgres-1 -n demo-database
kubectl get pods -n demo-database --watch

# Show data persistence
kubectl exec -it postgres-1 -n demo-database -- psql -U todouser -d todoapp -c "CREATE TABLE test (id INT);"
kubectl delete pod postgres-1 -n demo-database
# Wait for restart
kubectl exec -it postgres-1 -n demo-database -- psql -U todouser -d todoapp -c "\\dt"
```

### **Compare Normal vs Headless Services:**
```bash
# Create a normal service for comparison
kubectl expose deployment nginx-deployment --port=80 --name=normal-service -n demo

# Compare service types
kubectl get services -n demo
kubectl get services -n demo-database

# Test normal service DNS (returns service IP)
kubectl run debug --image=busybox -it --rm --restart=Never -- nslookup normal-service.demo.svc.cluster.local

# Test headless service DNS (returns pod IPs)
kubectl run debug --image=busybox -it --rm --restart=Never -- nslookup postgres-headless.demo-database.svc.cluster.local

# Test individual pod DNS (only works with headless)
kubectl run debug --image=busybox -it --rm --restart=Never -- nslookup postgres-0.postgres-headless.demo-database.svc.cluster.local
```

### **Demonstrate Service Behavior:**
```bash
# Show endpoints for both service types
kubectl get endpoints normal-service -n demo
kubectl get endpoints postgres-headless -n demo-database

# Show how traffic routing differs
kubectl describe service normal-service -n demo
kubectl describe service postgres-headless -n demo-database
```

## 🎯 Key Teaching Points

1. **Predictable Identity**: StatefulSets provide stable names and network identities
2. **Persistent Storage**: Each pod gets its own PVC that survives pod restarts  
3. **Ordered Management**: Pods start/stop in predictable order
4. **Data Durability**: Database data survives pod crashes and recreations
5. **Network Stability**: Headless services provide stable DNS names
6. **Operator Pattern**: Production databases use operators for advanced management

## ⚡ Delete vs Scale Operations

### **kubectl delete vs kubectl scale - Critical Difference**

#### **kubectl scale (Safe for data):**
```bash
# Scale down from 3 to 1 replica
kubectl scale statefulset postgres --replicas=1 -n demo-database

# What happens:
1. Deletes postgres-2 (highest ordinal first)
2. Waits for postgres-2 to terminate completely  
3. Deletes postgres-1
4. Waits for postgres-1 to terminate
5. Leaves postgres-0 running
6. PVCs remain: postgres-storage-postgres-0, postgres-storage-postgres-1, postgres-storage-postgres-2

# Scale back up to 3
kubectl scale statefulset postgres --replicas=3 -n demo-database

# What happens:
1. Creates postgres-1 (reconnects to existing postgres-storage-postgres-1)
2. Creates postgres-2 (reconnects to existing postgres-storage-postgres-2)  
3. All data is preserved! 🎉
```

#### **kubectl delete (Dangerous for PVCs):**
```bash
# Delete entire StatefulSet
kubectl delete statefulset postgres -n demo-database

# What happens:
1. All pods are deleted (postgres-0, postgres-1, postgres-2)
2. PVCs remain by default (data preserved)
3. StatefulSet object is removed

# Recreate StatefulSet
kubectl apply -f postgres-statefulset.yaml

# Pods reconnect to existing PVCs automatically
```

#### **kubectl delete with cascade (VERY DANGEROUS):**
```bash
# ⚠️  DANGER: This deletes PVCs too!
kubectl delete statefulset postgres --cascade=orphan -n demo-database
kubectl delete pvc postgres-storage-postgres-0 postgres-storage-postgres-1 postgres-storage-postgres-2 -n demo-database

# Result: All data is lost permanently! 💥
```

### **Best Practices:**
```bash
# ✅ Safe scaling (preserves data)
kubectl scale statefulset postgres --replicas=1 -n demo-database
kubectl scale statefulset postgres --replicas=3 -n demo-database

# ✅ Safe StatefulSet recreation (preserves PVCs)  
kubectl delete statefulset postgres -n demo-database
kubectl apply -f postgres-statefulset.yaml

# ⚠️  Only delete PVCs when you're sure
kubectl get pvc -n demo-database  # Check what will be deleted
kubectl delete pvc postgres-storage-postgres-2 -n demo-database  # Only if sure

# 🔍 Always verify before destructive operations
kubectl describe pvc postgres-storage-postgres-0 -n demo-database
```

## 🤔 Common Questions

**Q: What if the persistent volume fails?**
A: Data is lost unless you have backups. This is why production uses:
- Replicated storage (multiple copies)
- Regular backups to external storage
- Database operators with automated backup

**Q: How does the database handle multiple replicas?**
A: Depends on database configuration:
- **Primary-Replica**: One writer, multiple readers
- **Cluster Mode**: Distributed writes (complex)
- **Our Workshop**: Independent instances (not clustered)

**Q: When should I use StatefulSets vs Deployments?**
A: Use StatefulSets when you need:
- Persistent storage per pod
- Stable network identities  
- Ordered startup/shutdown
- Databases, message queues, etc.

Use Deployments for stateless applications like web servers, APIs, etc.

**Q: If I scale down and then up, do I lose data?**
A: No! Scaling preserves PVCs. When you scale back up, pods reconnect to their existing storage with all data intact.

**Q: What's the difference between deleting a pod vs scaling down?**
A: 
- **Delete pod**: Pod is recreated immediately (data preserved)
- **Scale down**: Pod is removed permanently until you scale back up (PVC preserved)
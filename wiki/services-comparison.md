# Kubernetes Services: Normal vs Headless Quick Reference

## 🔄 Normal Service (ClusterIP)

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   Client    │───▶│    Service   │───▶│    Pod 1    │
│             │    │  10.96.1.100 │    │10.244.1.5   │
└─────────────┘    │              │    └─────────────┘
                   │ Load Balancer│    ┌─────────────┐
                   │              │───▶│    Pod 2    │
                   └──────────────┘    │10.244.2.8   │
                                       └─────────────┘
```

**Characteristics:**
- ✅ **Load balancing** across pods
- ✅ **Single virtual IP** (ClusterIP)  
- ✅ **Random pod selection**
- ✅ **Perfect for stateless apps**

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
  type: ClusterIP  # Default
```

## 🎯 Headless Service

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   Client    │───▶│   Headless   │───▶│ postgres-0  │
│             │    │   Service    │    │10.244.1.5   │
└─────────────┘    │ (No ClusterIP)│    └─────────────┘
                   │              │    ┌─────────────┐
                   │   DNS Only   │───▶│ postgres-1  │
                   │              │    │10.244.2.8   │
                   └──────────────┘    └─────────────┘
```

**Characteristics:**
- ✅ **No load balancing** (direct pod access)
- ✅ **No virtual IP** (clusterIP: None)
- ✅ **DNS returns pod IPs**
- ✅ **Perfect for StatefulSets**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
spec:
  clusterIP: None  # Makes it headless
  selector:
    app: postgres
  ports:
  - port: 5432
```

## 🔍 DNS Resolution Comparison

### Normal Service DNS
```bash
# DNS query
nslookup web-service.default.svc.cluster.local

# Response
web-service.default.svc.cluster.local = 10.96.1.100  # Service IP

# Traffic: Client → Service IP → Random Pod
```

### Headless Service DNS
```bash
# DNS query for service
nslookup postgres-headless.default.svc.cluster.local

# Response (multiple A records)
postgres-headless.default.svc.cluster.local = 10.244.1.5  # postgres-0
postgres-headless.default.svc.cluster.local = 10.244.2.8  # postgres-1
postgres-headless.default.svc.cluster.local = 10.244.3.12 # postgres-2

# DNS query for specific pod
nslookup postgres-0.postgres-headless.default.svc.cluster.local

# Response (single A record)
postgres-0.postgres-headless.default.svc.cluster.local = 10.244.1.5
```

## 🎯 Use Cases

| Scenario | Normal Service | Headless Service |
|----------|---------------|------------------|
| **Web Application** | ✅ Perfect | ❌ Unnecessary |
| **REST API** | ✅ Perfect | ❌ Unnecessary |
| **Database Primary/Replica** | ❌ Can't distinguish roles | ✅ Perfect |
| **StatefulSet Pods** | ❌ Loses pod identity | ✅ Perfect |
| **Load Balancing** | ✅ Built-in | ❌ Not provided |
| **Pod-specific Connection** | ❌ Random routing | ✅ Direct access |
| **Service Discovery** | ✅ Single endpoint | ✅ All endpoints |

## 🔧 Quick Commands

### Check Service Type
```bash
kubectl get services
# Look for ClusterIP column:
# - IP address = Normal service
# - None = Headless service
```

### Test DNS Resolution
```bash
# Test normal service (returns service IP)
kubectl run test --image=busybox --rm -it --restart=Never -- nslookup normal-service

# Test headless service (returns pod IPs)  
kubectl run test --image=busybox --rm -it --restart=Never -- nslookup headless-service

# Test specific pod (only works with headless)
kubectl run test --image=busybox --rm -it --restart=Never -- nslookup pod-0.headless-service
```

### View Endpoints
```bash
# Both service types create endpoints
kubectl get endpoints

# Normal service: endpoints point to service IP  
kubectl describe service normal-service

# Headless service: endpoints point directly to pods
kubectl describe service headless-service  
```

## 💡 Key Takeaway

**Normal Service** = **Load Balancer** (stateless apps)  
**Headless Service** = **Service Discovery** (stateful apps)

Choose based on whether you need **load balancing** (normal) or **direct pod access** (headless)!
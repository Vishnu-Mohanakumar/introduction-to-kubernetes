# Demo Manifests

Hands-on exercises to learn Kubernetes step by step. `components/` and `database/` are Phase 2
and Phase 3 of the main workshop flow (see the top-level README) - `nginx/` is a standalone bonus

## Workshop Phases

### Phase 2: Individual Components (`components/`)
Learn the building blocks:
- Namespaces, ConfigMaps, Secrets
- ServiceAccounts and RBAC  
- Deployments

### Phase 3: Database with StatefulSets (`database/`)
Learn persistent storage:
- PostgreSQL database cluster
- Persistent volumes that survive pod restarts
- Ordered deployment and scaling

## Bonus Example

### Simple Web App (`nginx/`)
A minimal deployment example, useful as a quick reference outside the main workshop flow:
- Web server deployment
- Service networking
- External access

## Namespaces

Each phase uses a different namespace:
- `components/` → `demo`
- `database/` → `demo-database`
- `nginx/` → `demo-nginx`

Add `-n <namespace>` to your `kubectl get` commands, and double check which one you're in when switching between phases.

## Quick Start

### Check Your Cluster
```bash
# Make sure Kubernetes is running
kubectl cluster-info
kubectl get nodes

# Should see 1 ready node
```

### Run the Tutorials

**Start with Phase 2:**
```bash
cd components/
# Follow the README.md step by step
```

**Then Phase 3:**
```bash
cd ../database/
# Follow the README.md for databases
```

**Bonus, anytime:**
```bash
cd ../nginx/
# Follow the README.md for web apps
```

## Clean Up
```bash
# Remove everything when done
kubectl delete -f components/
kubectl delete -f database/  
kubectl delete -f nginx/
```

---

**Start with the `components/` folder and follow the README!**
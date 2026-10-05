# Introduction to Kubernetes Workshop (CR9)

Welcome to the CR9 Kubernetes workshop! This repository contains everything you need for two hands-on sessions covering practical deployment and real-world scenarios.

## 🗓️ Session Schedule

### **Day 1: October 6, 2026** - Presentation & Prerequisites
- Theoretical presentation on Kubernetes architecture and concepts
- Environment setup: killercoda.com account, kubectl, Docker
- Repository walkthrough and pre-workshop checklist

### **Day 2: October 8, 2026** - Hands-on Workshop + Lab Assignment
- **Apply** Kubernetes concepts through hands-on deployment
- **Demonstrate** StatefulSets for database persistence
- **Practice** RBAC and security configurations
- **Experience** real-world application deployment patterns
- **Build** confidence with kubectl and troubleshooting
- Lab assignment handed out at the end of the session

### Prerequisites (From Day 1)
- Basic understanding of Kubernetes architecture
- Familiarity with containers and Docker concepts
- YAML syntax knowledge
- Command line experience
- Laptop with Docker and kubectl installed

## 🚀 Quick Start

### **Recommended: killercoda.com Kubernetes Playground**
1. Go to [killercoda.com](https://killercoda.com/) and start the Kubernetes Playground scenario
2. You get a live cluster with `kubectl` and `docker` pre-installed - no local install needed
3. Test: `kubectl get nodes` - as of writing this is 2 nodes, `controlplane` and `node01`, both k8s v1.36.1

**Only `controlplane` has a working kubeconfig.** `node01` has the `kubectl` binary but no cluster access configured - run all `kubectl` commands from `controlplane`. `node01` is reachable via `ssh node01` from `controlplane` (used below to get images there).

**Custom-built images (`demo-app`, `labs/beginner`, `lab-solution/beginner`) need extra steps on killercoda - `docker build` alone is not enough.** Two things bite you:
1. Pods can be scheduled on **either** node (`controlplane` isn't tainted against scheduling here), so the image needs to exist on both, not just the one you built on.
2. `docker build`/`docker load` only populate Docker's own image store - **not** the separate containerd `k8s.io` namespace that kubelet/CRI actually reads from. Even with `imagePullPolicy: IfNotPresent` and the image visible in `docker images`, kubelet will still try (and fail) to pull it from a registry unless it's also imported into containerd's `k8s.io` namespace via `ctr`.

For every custom image you build, after `docker build -t <image> .`, run:
```bash
# Import into containerd's k8s.io namespace on controlplane (where you land by default)
docker save <image> -o /tmp/<image>.tar
ctr -n k8s.io images import /tmp/<image>.tar

# Ship it to node01 and import it there too, in one line, no docker load needed
docker save <image> | ssh node01 "ctr -n k8s.io images import -"
```
Then `kubectl apply` as normal, from `controlplane`.

Once you understand what those commands are doing, `bash killercoda/load-image.sh <image>` does the same thing in one line (discovers nodes automatically, one image per call) - see `killercoda/README.md`.

### **Fallback: KIND**
If killercoda isn't reachable (e.g. network restrictions), use a local KIND cluster instead. See `kind/README.md` for setup, registry/certificate troubleshooting, and the `kind/setup-workshop-cluster.sh` script.

```bash
cd kind/
kind create cluster --config kind.config.yaml --name workshop
kubectl cluster-info --context kind-workshop
```

### **Deploy Workshop Demos**
```bash
# Clone repository
git clone <repository-url>
cd introduction-to-kubernetes

# Deploy components demo (files are numbered, directory apply is safe here)
kubectl apply -f demo-manifests/components/
kubectl get pods -n demo

# Deploy PostgreSQL StatefulSet demo (files are numbered, directory apply is safe here)
kubectl apply -f demo-manifests/database/
kubectl get statefulset -n demo-database

# ✅ Both should show Running/Ready status
```

## 🕐 Workshop Structure (Day 2, 1.5 Hours Total)

### **Phase 1**: Environment Setup (15 minutes)
- killercoda.com Kubernetes Playground (or KIND fallback)
- kubectl context verification and basic commands
- Repository structure and demo overview walkthrough

### **Phase 2**: Demo Manifests Tutorial (30 minutes)
- **Real container image** deployment (nginx:alpine)
- Individual Kubernetes resource deep-dive
- Deployment → Service → ConfigMap → Secret → RBAC flow
- Live environment variable injection demonstration
- Interactive kubectl commands and verification

### **Phase 3**: StatefulSet Deep Dive (20 minutes)
- **Production PostgreSQL 15** cluster deployment
- 3-replica StatefulSet with individual persistent volumes
- Headless services and stable network identities
- Live data persistence testing and pod recovery demonstration

### **Phase 4**: Complete Application Demo (30 minutes)
- Full-stack application deployment (`demo-app/`)
- Service-to-service communication
- Live scaling and self-healing demonstration
- Real-time troubleshooting scenarios

> **Note on namespaces**: each phase uses a different namespace - `demo` (components), `demo-database` (database), `demo-nginx` (nginx), `demo-app` (full app demo). If `kubectl get pods` looks empty, check you're in the right namespace for the phase you're on.

## 📚 Labs

Three tiers under `labs/`: `beginner` (the graded capstone assignment, handed out on Day 2), `intermediate`, and `advanced` (optional self-paced practice, independent of the capstone).

### Beginner (capstone assignment)

See `labs/beginner/LAB_QUESTIONS.md` for full requirements and grading rubric, and `labs/beginner/LOCAL_ASSIGNMENT.md` for setup.

**Objective**: Deploy a complete full-stack Todo application to Kubernetes with:
- PostgreSQL StatefulSet (3 replicas)
- Redis Deployment
- Backend (Flask API) Deployment
- Frontend (React + Nginx) Deployment
- All security, configuration, and networking manifests

**Cluster**: killercoda.com or KIND. Note that killercoda sessions are time-limited and reset - your deliverable is the manifests/code, so redeploy fresh each time you resume work. If you want an environment that stays up across the week without re-deploying every session, use KIND locally instead.

```bash
cd labs/beginner
cat LAB_QUESTIONS.md      # Read assignment requirements
cat LOCAL_ASSIGNMENT.md   # Follow setup instructions
# Work on the assignment!
```

Reference solution (when stuck) is in `lab-solution/beginner/` - see its `README.md`, `DEPLOYMENT_STEPS.md`, and `TROUBLESHOOTING_AND_ERRORS.md`.

### Intermediate and Advanced

Optional, self-paced practice exercises - see `labs/intermediate/` and `labs/advanced/`. Not part of the graded capstone, no dependency on finishing it first. Try them yourself first - reference solutions are in `lab-solution/intermediate/` and `lab-solution/advanced/`.

## 📁 Repository Structure

```
introduction-to-kubernetes/
├── README.md                      # This overview
├── kind/
│   ├── kind.config.yaml           # 2-node cluster configuration
│   ├── setup-workshop-cluster.sh  # Automated KIND fallback setup
│   └── README.md                  # KIND setup + troubleshooting
├── killercoda/
│   ├── load-image.sh              # Get a custom-built image onto every node's containerd
│   └── README.md
├── demo-manifests/
│   ├── README.md                  # Demo overview
│   ├── components/                # Individual K8s resources tutorial (Phase 2)
│   │   ├── 01-namespace.yaml
│   │   ├── 02-configmaps.yaml
│   │   ├── 03-secrets.yaml
│   │   ├── 04-serviceaccount.yaml
│   │   ├── 05-role.yaml
│   │   ├── 06-rolebinding.yaml
│   │   ├── 07-clusterrole.yaml
│   │   ├── 08-clusterrolebinding.yaml
│   │   ├── 09-deployment.yaml
│   │   └── README.md              # Step-by-step tutorial
│   ├── database/                  # StatefulSet deep-dive (Phase 3)
│   │   ├── README.md
│   │   ├── 01-namespace.yaml
│   │   ├── 02-configmap.yaml
│   │   ├── 03-secret.yaml
│   │   ├── 04-service.yaml         # Headless service
│   │   ├── 05-postgres-scripts.yaml # Primary/replica entrypoint + replication setup
│   │   └── 06-statefulset.yaml     # PostgreSQL cluster: 1 primary + 2 streaming replicas
│   └── nginx/                     # Simple deployment example
│       ├── README.md
│       ├── 01-namespace.yaml
│       ├── 02-deploy.yaml
│       └── 03-service.yaml
├── demo-app/                      # Complete application demo (Phase 4)
│   ├── README.md                  # Application architecture + guided walkthrough
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py                     # Flask application with K8s integration
│   ├── deploy.sh                  # Deployment automation
│   └── k8s-manifests/             # Application K8s resources (numbered, apply order-safe)
├── labs/                       # beginner (capstone, graded) + intermediate + advanced
│   ├── beginner/
│   ├── intermediate/
│   └── advanced/
└── lab-solution/               # answer keys
    ├── beginner/
    ├── intermediate/
    └── advanced/
```

## 🐳 Images & Registry

For this workshop, we use pre-built images from public registries - no need to set up your own registry.

All demo applications use standard public images: `nginx`, `postgres`, `busybox`. No personal or private registries.

If you want to build your own images later, check the lab examples in `lab-solution/beginner/` folder.

## 📚 Learning Resources & Documentation

### **Wiki - Comprehensive Learning Materials**

The `wiki/` folder contains detailed guides and resources for deeper understanding:

#### **🔧 Technical Deep Dives**
- **[kubectl Explain Guide](wiki/kubectl-explain-guide.md)** - Master kubectl's documentation features
- **[StatefulSet Deep Dive](wiki/statefulset-deep-dive.md)** - Complete guide to persistent workloads
- **[Services Comparison](wiki/services-comparison.md)** - ClusterIP vs NodePort vs LoadBalancer vs Ingress

#### **🌐 Networking & Architecture**
- **[Networking Guide](wiki/networking-guide.md)** - DNS, Services, Network Policies, Service Mesh
- **[Demo Features Guide](wiki/demo-features-guide.md)** - Interactive application capabilities

#### **📖 Additional Learning**
- **[Extra Resources](wiki/extra-resources.md)** - Tools, certifications, and learning platforms

### **Quick Navigation**
```bash
# Browse learning materials
ls wiki/

# Read a specific guide
cat wiki/kubectl-explain-guide.md

# Follow structured learning path
1. Start with kubectl-explain-guide.md (essential kubectl skills)
2. Explore statefulset-deep-dive.md (persistent applications)
3. Study services-comparison.md (networking patterns)
4. Review networking-guide.md (advanced concepts)
5. Check extra-resources.md (continued learning)
```

# KIND Setup (Fallback)

For CR9, **killercoda.com's Kubernetes Playground is the primary cluster** for both the workshop and lab - no local install needed. Use this doc if killercoda isn't reachable (e.g. network restrictions) and you need a local cluster instead.

## What You Need
- Docker (must be running)
- kubectl
- KIND

## Docker Setup by Platform

Trainees are on a mix of macOS, Windows, WSL2, and Linux laptops. Pick the option for your platform - all of these are free/unlicensed runtimes, which matters on corporate-managed laptops where Docker Desktop's subscription terms can apply:

| Platform | Recommended | Why |
|---|---|---|
| **macOS** | Colima | Lightweight, scriptable, no Docker Desktop license concern |
| **Linux** | Native Docker Engine | No VM layer needed - containers run natively |
| **WSL2** | Native Docker Engine inside the WSL2 distro | Avoids Docker Desktop entirely, same idea as Colima on Mac |
| **Windows (no WSL2)** | Docker Desktop (WSL2 backend) | Only real option without a WSL2 shell; has licensing terms for larger orgs |

### macOS: Colima
```bash
brew install colima docker
colima start --cpu 4 --memory 8
docker version
```

**Already using Colima for other work?** Don't run `colima start` on your `default` profile - you
can't resize an existing VM's CPU/memory without deleting it, and you don't want to touch a
profile that already has real work images/data on it. Create a separate named profile instead:

```bash
colima start cr9-kind --cpus 4 --memory 8 --activate=false
```

`--activate=false` keeps this profile from becoming your default Docker context - your existing
setup keeps working normally. Point Docker/kind at the new profile explicitly when you want to use
it, in whichever shell you're running the workshop commands from:

```bash
export DOCKER_HOST="unix:///Users/<you>/.colima/cr9-kind/docker.sock"
docker version   # confirm it's talking to the isolated profile, not your default one
```

If your real `~/.docker/config.json` has `credsStore` set (common with Docker Desktop), the
`docker` CLI will try to run a credential helper that may not be on your `PATH` in this context and
error out - even for plain public image pulls. You'll see something like this when the setup script
tries to pull the KIND node image:

```
ERROR: failed to create cluster: failed to pull image "kindest/node:v1.36.1": command "docker pull kindest/node:v1.36.1" failed with error: exit status 1
Command Output: error getting credentials - err: exec: "docker-credential-desktop": executable file not found in $PATH, out: ``
```

Workaround: use a scoped config with no `credsStore` just for this profile:

```bash
mkdir -p /tmp/cr9-docker-config
echo '{}' > /tmp/cr9-docker-config/config.json
export DOCKER_CONFIG=/tmp/cr9-docker-config
```

With both `DOCKER_HOST` and `DOCKER_CONFIG` exported in that shell, `kind create cluster` and
everything downstream (`docker build`, `kind load docker-image`, etc.) targets the isolated profile
only. To go back to normal, open a new terminal or `unset DOCKER_HOST DOCKER_CONFIG`.

To clean up the isolated profile entirely when you're done:
```bash
colima delete cr9-kind -f
```

### Linux: Native Docker Engine
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
docker version
```

### WSL2: Native Docker Engine (inside your WSL2 distro)
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
sudo service docker start   # if systemd isn't available in your distro
docker version
```

### Windows (no WSL2): Docker Desktop
- Download from [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/)
- During install, enable the WSL2-based engine if offered (falls back to Hyper-V otherwise)
- Verify: `docker version`

If you're behind a corporate proxy (Zscaler etc.), see the [Corporate Network / Zscaler Certificate Issues](#corporate-network--zscaler-certificate-issues) section below - it applies regardless of which runtime you picked above.

> This section only applies to the **KIND fallback**. On killercoda.com (the primary path for CR9), Docker and kubectl are already installed on the remote VM - trainees don't need any of this.

## Install KIND
```bash
# macOS
brew install kind kubectl

# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

# Windows
choco install kind
```

### Verify Installation
```bash
kind version
docker version
kubectl version --client
```

## Cluster Creation

The `kind.config.yaml` file defines a 2-node cluster (1 control-plane + 1 worker) - this is the standard setup for CR9, so all node-count references in this doc and the wiki assume 2 nodes. A 3rd node measurably increases the odds of a containerd startup race under nested virtualization (colima/Docker Desktop VMs), so we deliberately kept it at 2.

```bash
kind create cluster --config kind.config.yaml --name workshop

# Expected output:
# Creating cluster "workshop" ...
# ✓ Ensuring node image (kindest/node:v1.36.1) 🖼
# ✓ Preparing nodes 📦 📦
# ✓ Writing configuration 📜
# ✓ Starting control-plane 🕹️
# ✓ Installing CNI 🔌
# ✓ Installing StorageClass 💾
# ✓ Joining worker node 🚜
# Set kubectl context to "kind-workshop"
```

Verify:
```bash
kubectl get nodes
# You should see 2 nodes ready
```

## Automated Setup

`setup-workshop-cluster.sh` creates the cluster, pre-loads workshop images, and pre-creates the workshop namespaces in one go:

```bash
cd kind/
./setup-workshop-cluster.sh
```

## Cluster Management

```bash
# List clusters
kind get clusters

# Switch context
kubectl config use-context kind-workshop
kubectl config current-context

# Cluster info
kubectl cluster-info
kubectl config view --minify
kubectl get pods -n kube-system

# Delete cluster
kind delete cluster --name workshop
```

## Working with Images

### Load Images into KIND
```bash
# Build an image locally
docker build -t my-app:latest .

# Load image into KIND cluster
kind load docker-image my-app:latest --name workshop

# Verify image is available
kubectl run test-pod --image=my-app:latest --image-pull-policy=Never --rm -it
```

### Pre-load Workshop Images
```bash
docker pull nginx:alpine
docker pull postgres:16-alpine
docker pull busybox:latest

kind load docker-image nginx:alpine --name workshop
kind load docker-image postgres:16-alpine --name workshop
kind load docker-image busybox:latest --name workshop

# Verify images are loaded
docker exec workshop-control-plane crictl images | grep -E "(nginx|postgres|busybox)"
docker exec workshop-worker crictl images | grep -E "(nginx|postgres|busybox)"
```

### Container Registry Issues

KIND clusters sometimes have certificate issues with external registries. Solutions:

```bash
# Method 1: Use alpine-based images (smaller, more reliable)
# Method 2: Pre-load images during cluster creation (setup-workshop-cluster.sh does this)
# Method 3: Use imagePullPolicy: Never for pre-loaded images
```

## Workshop Namespace Setup

```bash
kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace demo-nginx --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace demo-database --dry-run=client -o yaml | kubectl apply -f -

kubectl run test-pod --image=nginx:alpine --restart=Never -n demo
kubectl get pods -n demo
kubectl delete pod test-pod -n demo --ignore-not-found=true
```

### Pre-Workshop Checklist
- [ ] Docker is running
- [ ] KIND cluster "workshop" is created
- [ ] kubectl context is set to "kind-workshop"
- [ ] Both nodes are Ready
- [ ] `kubectl get pods -A` shows system pods running

### Demo Deployment Order

`demo-manifests/components/` files are numbered, so a plain directory apply deploys everything in the right order:

```bash
kubectl apply -f demo-manifests/components/
```

## Image Registry Troubleshooting

If you see `ErrImagePull` or `ImagePullBackOff`:

```bash
# Use basic images that work reliably in KIND
# nginx:1.21 -> nginx:alpine
# postgres:16 -> postgres:16-alpine

# Or use pre-loaded images with Never pull policy (only if image is pre-loaded):
imagePullPolicy: Never
```

### Certificate Issues Fix

```bash
# If you see "x509: certificate signed by unknown authority"
# Solution 1: Delete and recreate cluster
kind delete cluster --name workshop
kind create cluster --config kind.config.yaml --name workshop

# Solution 2: Use different image tags - alpine images tend to work better
```

### Corporate Network / Zscaler Certificate Issues

If you're behind a corporate proxy (like Zscaler) that intercepts TLS traffic:

```bash
# Add this function to your shell profile (~/.zshrc or ~/.bashrc)
function colima-certificate() {
    local CERTS="${HOME}/.ca-certificates"
    mkdir -p ${CERTS}

    # Extract corporate root CA (adjust certificate name as needed)
    security find-certificate -c "Zscaler Root CA" -p /Library/Keychains/System.keychain > ${CERTS}/certs-roots.crt

    # Download certificates from container registries
    openssl s_client -showcerts -connect registry-1.docker.io:443 </dev/null 2>/dev/null|openssl x509 -outform PEM >${CERTS}/docker-io.crt
    openssl s_client -showcerts -connect ghcr.io:443 </dev/null 2>/dev/null|openssl x509 -outform PEM >${CERTS}/ghcr.io.crt
    openssl s_client -showcerts -connect registry.k8s.io:443 </dev/null 2>/dev/null|openssl x509 -outform PEM >${CERTS}/registry.k8s.io.crt
    openssl s_client -showcerts -connect quay.io:443 </dev/null 2>/dev/null|openssl x509 -outform PEM >${CERTS}/quay.io.crt

    colima ssh -- sudo cp ${CERTS}/* /usr/local/share/ca-certificates/
    colima ssh -- sudo update-ca-certificates
    colima ssh -- sudo service docker restart
}

# For Docker Desktop users with corporate certificates:
function docker-desktop-certificates() {
    local CERTS="${HOME}/.ca-certificates"
    mkdir -p ${CERTS}

    security find-certificate -c "Zscaler Root CA" -p /Library/Keychains/System.keychain > ${CERTS}/corporate-ca.crt
    cp ${CERTS}/corporate-ca.crt ~/.docker/certs.d/
    echo "Please restart Docker Desktop to apply certificate changes"
}
```

This is exactly the class of friction killercoda avoids (it's a remote sandbox, so no corporate proxy/certificate interaction on your laptop) - it's the main reason killercoda is primary and KIND is the fallback for CR9.

### KIND-Specific Registry Configuration

`kind.config.yaml` deliberately does **not** patch containerd's registry config - public image pulls (docker.io, quay.io) work fine without one on a normal network. If you're behind a corporate proxy that intercepts TLS (Zscaler etc.) and hit registry pull errors, use the certificate-installation steps below rather than adding a containerd patch.

### Image Pull Policy Best Practices

```bash
# For pre-loaded images:
imagePullPolicy: IfNotPresent  # or Never if you're sure image exists

# For images that need to be pulled:
imagePullPolicy: Always
```

### Troubleshooting Image Pull Failures

```bash
# Check if image was loaded correctly
docker exec workshop-control-plane crictl images | grep nginx
docker exec workshop-worker crictl images | grep nginx

# For an official/public image, pull it directly on each node instead of
# `kind load docker-image` - see "KIND-Specific Registry Configuration" above
for NODE in $(kind get nodes --name workshop); do
  docker exec "$NODE" crictl pull nginx:alpine
done

# For a locally-built image, kind load docker-image works fine - re-run it explicitly:
kind load docker-image my-app:latest --name workshop
```

---

For more information, visit the [official KIND documentation](https://kind.sigs.k8s.io/).

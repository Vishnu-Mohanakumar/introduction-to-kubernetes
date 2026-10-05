#!/bin/bash
# setup-workshop-cluster.sh
# KIND fallback setup - use this if killercoda.com isn't available

set -e

echo "🚀 Setting up workshop cluster..."

# Create cluster
kind create cluster --config kind.config.yaml --name workshop

# Verify cluster
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Pre-load essential images directly on each node via crictl, to avoid registry issues later.
echo "📦 Pre-loading workshop images on each node..."
NODES=$(kind get nodes --name workshop)
for IMAGE in nginx:alpine postgres:16-alpine busybox:latest neilpeterson/azure-vote-front:v1 neilpeterson/azure-vote-front:v2 redis:7-alpine; do
  for NODE in $NODES; do
    echo "Pulling $IMAGE on $NODE..."
    docker exec "$NODE" crictl pull "$IMAGE" || echo "⚠️  $IMAGE pull failed on $NODE, pods will pull it on demand instead"
  done
done

# Pre-create workshop namespaces to avoid timing issues
echo "📝 Pre-creating workshop namespaces..."
kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace demo-nginx --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace demo-database --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Workshop cluster ready!"
kubectl get nodes

# Test basic deployment to verify cluster works
echo "🧪 Testing cluster with basic deployment..."
kubectl run test-nginx --image=nginx:alpine --restart=Never -n demo || true
sleep 5
kubectl get pod test-nginx -n demo || echo "⚠️  Basic test failed - check network/registry access"
kubectl delete pod test-nginx -n demo --ignore-not-found=true

echo "🎯 Workshop environment is ready for use!"

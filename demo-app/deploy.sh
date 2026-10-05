#!/bin/bash

# Kubernetes Demo App Quick Deploy Script
# Usage: ./deploy.sh [cluster-create|cluster-delete|build|deploy|clean|all]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="k8s-demo-app:latest"
CLUSTER_NAME="workshop"
NAMESPACE="demo-app"
KIND_CONFIG="../kind/kind.config.yaml"

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        echo "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Check if KIND is installed
    if ! command -v kind &> /dev/null; then
        error "KIND is not installed. Please install KIND first."
        echo "Visit: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed. Please install kubectl first."
        echo "Visit: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    success "All prerequisites are installed"
}

check_cluster_exists() {
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        return 0
    else
        return 1
    fi
}

create_cluster() {
    log "Creating KIND cluster: $CLUSTER_NAME"
    
    if check_cluster_exists; then
        warn "Cluster '$CLUSTER_NAME' already exists"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            delete_cluster
        else
            log "Using existing cluster"
            return 0
        fi
    fi
    
    # Check if config file exists
    if [[ ! -f "$KIND_CONFIG" ]]; then
        error "KIND config file not found: $KIND_CONFIG"
        log "Creating basic KIND config..."
        mkdir -p "$(dirname "$KIND_CONFIG")"
        cat > "$KIND_CONFIG" << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    image: kindest/node:v1.36.1
  - role: worker
    image: kindest/node:v1.36.1
EOF
        success "Created KIND config at: $KIND_CONFIG"
    fi
    
    log "Creating cluster with config: $KIND_CONFIG"
    kind create cluster --config "$KIND_CONFIG" --name "$CLUSTER_NAME"
    
    log "Waiting for cluster to be ready..."
    kubectl cluster-info --context "kind-$CLUSTER_NAME"
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    success "KIND cluster '$CLUSTER_NAME' created successfully"
    
    # Show cluster info
    echo ""
    log "Cluster Information:"
    kubectl get nodes
    echo ""
    kubectl cluster-info
}

delete_cluster() {
    log "Deleting KIND cluster: $CLUSTER_NAME"
    
    if check_cluster_exists; then
        kind delete cluster --name "$CLUSTER_NAME"
        success "Cluster '$CLUSTER_NAME' deleted successfully"
    else
        warn "Cluster '$CLUSTER_NAME' does not exist"
    fi
}

verify_cluster() {
    log "Verifying cluster connectivity..."
    
    if ! check_cluster_exists; then
        error "KIND cluster '$CLUSTER_NAME' does not exist"
        log "Create the cluster first with: $0 cluster-create"
        exit 1
    fi
    
    # Set kubectl context
    kubectl config use-context "kind-$CLUSTER_NAME" > /dev/null
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
        log "Try recreating the cluster with: $0 cluster-create"
        exit 1
    fi
    
    success "Cluster is accessible"
}

build_image() {
    log "Building Docker image..."
    docker build -t $IMAGE_NAME .
    success "Docker image built successfully"
}

load_image() {
    log "Loading image into KIND cluster..."
    kind load docker-image $IMAGE_NAME --name $CLUSTER_NAME
    success "Image loaded into KIND cluster"
}

deploy_app() {
    log "Deploying application to Kubernetes..."
    
    # Verify cluster connectivity first
    verify_cluster
    
    # Apply manifests in order
    log "Applying namespace..."
    kubectl apply -f k8s-manifests/01-namespace.yaml
    
    log "Applying ConfigMap..."
    kubectl apply -f k8s-manifests/02-configmap.yaml
    
    log "Applying Secrets..."
    kubectl apply -f k8s-manifests/03-secrets.yaml
    
    log "Applying ServiceAccount..."
    kubectl apply -f k8s-manifests/04-serviceaccount.yaml
    
    log "Applying Roles..."
    kubectl apply -f k8s-manifests/05-roles.yaml
    
    log "Applying RoleBindings..."
    kubectl apply -f k8s-manifests/06-rolebindings.yaml
    
    log "Applying Deployment..."
    kubectl apply -f k8s-manifests/07-deployment.yaml
    
    log "Applying Service..."
    kubectl apply -f k8s-manifests/08-service.yaml
    
    log "Waiting for deployment to be ready..."
    kubectl rollout status deployment/demo-app-deployment -n $NAMESPACE --timeout=300s
    
    success "Application deployed successfully"
}

check_status() {
    log "Checking application status..."
    
    echo ""
    echo "=== NAMESPACE ==="
    kubectl get namespace $NAMESPACE
    
    echo ""
    echo "=== PODS ==="
    kubectl get pods -n $NAMESPACE
    
    echo ""
    echo "=== SERVICES ==="
    kubectl get services -n $NAMESPACE
    
    echo ""
    echo "=== ENDPOINTS ==="
    kubectl get endpoints -n $NAMESPACE
}

start_port_forward() {
    log "Starting port forward..."
    log "Access the application at: http://localhost:8080"
    kubectl port-forward -n $NAMESPACE service/demo-app-service 8080:80
}

cleanup() {
    log "Cleaning up resources..."
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    success "Cleanup completed"
}

show_help() {
    echo "Kubernetes Demo App Deployment Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Cluster Management:"
    echo "  cluster-create  - Create KIND cluster"
    echo "  cluster-delete  - Delete KIND cluster"
    echo "  cluster-status  - Show cluster information"
    echo ""
    echo "Application Management:"
    echo "  build          - Build Docker image"
    echo "  deploy         - Deploy application to Kubernetes"
    echo "  status         - Check application status"
    echo "  forward        - Start port forwarding"
    echo "  clean          - Remove all deployed resources"
    echo ""
    echo "Complete Workflows:"
    echo "  setup          - Create cluster + build + deploy"
    echo "  all            - Build, deploy, and start port forwarding"
    echo "  teardown       - Clean app + delete cluster"
    echo ""
    echo "Utility:"
    echo "  prereqs        - Check prerequisites"
    echo "  help           - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 setup       # Complete setup (cluster + app)"
    echo "  $0 all         # Deploy app and port forward"
    echo "  $0 teardown    # Complete cleanup"
    echo "  $0 cluster-create  # Just create the cluster"
}

# Main script logic
case "${1:-help}" in
    "prereqs")
        check_prerequisites
        ;;
    "cluster-create")
        check_prerequisites
        create_cluster
        ;;
    "cluster-delete")
        delete_cluster
        ;;
    "cluster-status")
        if check_cluster_exists; then
            log "Cluster '$CLUSTER_NAME' exists"
            kubectl config use-context "kind-$CLUSTER_NAME"
            kubectl cluster-info
            echo ""
            kubectl get nodes
        else
            warn "Cluster '$CLUSTER_NAME' does not exist"
        fi
        ;;
    "setup")
        check_prerequisites
        create_cluster
        build_image
        load_image
        deploy_app
        check_status
        echo ""
        log "Setup completed! To access the application, run:"
        echo "  $0 forward"
        ;;
    "teardown")
        cleanup
        delete_cluster
        ;;
    "build")
        verify_cluster
        build_image
        load_image
        ;;
    "deploy")
        verify_cluster
        deploy_app
        check_status
        echo ""
        log "To access the application, run:"
        echo "  $0 forward"
        ;;
    "status")
        verify_cluster
        check_status
        ;;
    "forward")
        verify_cluster
        start_port_forward
        ;;
    "clean")
        verify_cluster
        cleanup
        ;;
    "all")
        verify_cluster
        build_image
        load_image
        deploy_app
        check_status
        echo ""
        log "Starting port forward in 5 seconds..."
        sleep 5
        start_port_forward
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
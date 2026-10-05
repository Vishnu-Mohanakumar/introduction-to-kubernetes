#!/bin/bash

# Todo App Kubernetes Deployment Script
# This script demonstrates the complete deployment of the todo application

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="todo-app"
CONTEXT="kind-workshop"
IMAGE_TAG="latest"

# Registry configuration (optional)
# Set REGISTRY_URL to use external registry instead of KIND loading
# Examples:
# REGISTRY_URL="localhost:5001"                    # Local registry
# REGISTRY_URL="gcr.io/your-project"              # Google Container Registry  
# REGISTRY_URL="your-account.dkr.ecr.region.amazonaws.com"  # AWS ECR
# REGISTRY_URL="your-registry.azurecr.io"         # Azure Container Registry
REGISTRY_URL="${REGISTRY_URL:-}"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if kind is available
    if ! command -v kind &> /dev/null; then
        log_error "kind is not installed or not in PATH"
        exit 1
    fi
    
    # Check if docker is available
    if ! command -v docker &> /dev/null; then
        log_error "docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if cluster exists
    if ! kubectl cluster-info --context=$CONTEXT &> /dev/null; then
        log_error "KIND cluster '$CONTEXT' is not running"
        log_info "Please create the cluster first: kind create cluster --config ../../kind/kind.config.yaml --name workshop"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

build_images() {
    log_info "Building Docker images..."
    
    cd ../todo-app
    
    # Build backend image
    log_info "Building backend image..."
    docker build -t todo-backend:$IMAGE_TAG ./backend
    
    # Build frontend image  
    log_info "Building frontend image..."
    docker build -t todo-frontend:$IMAGE_TAG ./frontend
    
    # Check for registry configuration
    if [[ -n "${REGISTRY_URL:-}" ]]; then
        log_info "Using registry: $REGISTRY_URL"
        
        # Tag for registry
        docker tag todo-backend:$IMAGE_TAG $REGISTRY_URL/todo-backend:$IMAGE_TAG
        docker tag todo-frontend:$IMAGE_TAG $REGISTRY_URL/todo-frontend:$IMAGE_TAG
        
        # Push to registry
        log_info "Pushing images to registry..."
        docker push $REGISTRY_URL/todo-backend:$IMAGE_TAG
        docker push $REGISTRY_URL/todo-frontend:$IMAGE_TAG
        
        log_success "Images pushed to registry: $REGISTRY_URL"
    else
        # Load images into KIND cluster (default behavior)
        log_info "Loading images into KIND cluster..."
        kind load docker-image todo-backend:$IMAGE_TAG --name workshop
        kind load docker-image todo-frontend:$IMAGE_TAG --name workshop
        
        log_success "Images loaded into KIND cluster"
    fi
    
    cd -
}

deploy_application() {
    log_info "Deploying application to Kubernetes..."
    
    # Set kubectl context
    kubectl config use-context $CONTEXT
    
    # Apply manifests in order
    log_info "Creating namespace..."
    kubectl apply -f 01-namespace.yaml
    
    log_info "Creating ConfigMaps..."
    kubectl apply -f 02-configmaps.yaml
    
    log_info "Creating Secrets..."
    kubectl apply -f 03-secrets.yaml
    
    log_info "Creating ServiceAccounts..."
    kubectl apply -f 04-serviceaccounts.yaml
    
    log_info "Creating Roles..."
    kubectl apply -f 05-roles.yaml
    
    log_info "Creating RoleBindings..."
    kubectl apply -f 06-rolebindings.yaml
    
    log_info "Creating Services..."
    kubectl apply -f 09-services.yaml
    
    log_info "Deploying PostgreSQL StatefulSet..."
    kubectl apply -f 07-postgres-statefulset.yaml
    
    log_info "Deploying Redis..."
    kubectl apply -f 08-redis-deployment.yaml
    
    # Wait for database to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=300s
    
    log_info "Waiting for Redis to be ready..."  
    kubectl wait --for=condition=ready pod -l app=redis -n $NAMESPACE --timeout=120s
    
    log_info "Deploying Backend and Frontend..."
    kubectl apply -f 10-deployments.yaml
    
    # Wait for deployments to be ready
    log_info "Waiting for Backend deployment..."
    kubectl wait --for=condition=available deployment/backend -n $NAMESPACE --timeout=300s
    
    log_info "Waiting for Frontend deployment..."
    kubectl wait --for=condition=available deployment/frontend -n $NAMESPACE --timeout=180s
    
    log_success "Application deployed successfully"
}

check_deployment() {
    log_info "Checking deployment status..."
    
    echo -e "\n${BLUE}=== Namespace Status ===${NC}"
    kubectl get namespace $NAMESPACE
    
    echo -e "\n${BLUE}=== Pods Status ===${NC}"
    kubectl get pods -n $NAMESPACE -o wide
    
    echo -e "\n${BLUE}=== Services Status ===${NC}"
    kubectl get services -n $NAMESPACE
    
    echo -e "\n${BLUE}=== StatefulSet Status ===${NC}"
    kubectl get statefulsets -n $NAMESPACE
    
    echo -e "\n${BLUE}=== Deployments Status ===${NC}"
    kubectl get deployments -n $NAMESPACE
    
    echo -e "\n${BLUE}=== PersistentVolumeClaims Status ===${NC}"
    kubectl get pvc -n $NAMESPACE
    
    # Check pod readiness
    echo -e "\n${BLUE}=== Pod Health Check ===${NC}"
    if kubectl get pods -n $NAMESPACE | grep -v Running | grep -v Completed | tail -n +2 | grep -q .; then
        log_warning "Some pods are not in Running state"
        kubectl get pods -n $NAMESPACE | grep -v Running | grep -v Completed
    else
        log_success "All pods are running"
    fi
}

test_application() {
    log_info "Testing application functionality..."
    
    # Port forward to frontend service
    log_info "Setting up port forwarding..."
    kubectl port-forward -n $NAMESPACE service/frontend-service 8080:80 &
    PORT_FORWARD_PID=$!
    
    # Wait a moment for port forwarding to establish
    sleep 3
    
    # Test frontend accessibility
    if curl -s http://localhost:8080/health > /dev/null; then
        log_success "Frontend is accessible"
    else
        log_error "Frontend is not accessible"
        kill $PORT_FORWARD_PID 2>/dev/null || true
        return 1
    fi
    
    if curl -s http://localhost:8080/api/stats > /dev/null; then
        log_success "Backend API is accessible through frontend"
    else
        log_error "Backend API is not accessible"
    fi
    
    # Test todos endpoint
    if curl -s http://localhost:8080/api/todos | jq . > /dev/null 2>&1; then
        log_success "Todos API is working"
    else
        log_warning "Todos API test failed (jq might not be installed)"
    fi
    
    # Clean up port forward
    kill $PORT_FORWARD_PID 2>/dev/null || true
    
    log_success "Application testing completed"
}

show_access_info() {
    echo -e "\n${GREEN}=== Access Information ===${NC}"
    echo -e "${BLUE}Frontend Access:${NC}"
    echo "  kubectl port-forward -n $NAMESPACE service/frontend-service 8080:80"
    echo "  Then open: http://localhost:8080"
    echo ""
    echo -e "${BLUE}Backend API Direct Access:${NC}"
    echo "  kubectl port-forward -n $NAMESPACE service/backend-service 5000:5000"
    echo "  Then access: http://localhost:5000/api/"
    echo ""
    echo -e "${BLUE}Database Access:${NC}"
    echo "  kubectl port-forward -n $NAMESPACE service/postgres-service 5432:5432"
    echo "  Connection: postgresql://todouser:todopass@localhost:5432/todoapp"
    echo ""
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  kubectl get all -n $NAMESPACE"
    echo "  kubectl logs -f deployment/backend -n $NAMESPACE"
    echo "  kubectl logs -f deployment/frontend -n $NAMESPACE"
    echo "  kubectl exec -it postgres-0 -n $NAMESPACE -- psql -U todouser -d todoapp"
}

cleanup() {
    log_info "Cleaning up deployment..."
    
    # Delete all resources in the namespace
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    
    # Wait for namespace to be deleted
    log_info "Waiting for namespace deletion..."
    kubectl wait --for=delete namespace/$NAMESPACE --timeout=120s || true
    
    log_success "Cleanup completed"
}

# Main execution
case "${1:-deploy}" in
    "check")
        check_prerequisites
        ;;
    "build")
        check_prerequisites
        build_images
        ;;
    "deploy")
        check_prerequisites
        build_images
        deploy_application
        check_deployment
        test_application
        show_access_info
        ;;
    "status")
        check_deployment
        ;;
    "test")
        test_application
        ;;
    "cleanup")
        cleanup
        ;;
    "help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  check    - Check prerequisites"
        echo "  build    - Build Docker images"
        echo "  deploy   - Full deployment (default)"
        echo "  status   - Check deployment status"
        echo "  test     - Test application functionality"
        echo "  cleanup  - Remove all resources"
        echo "  help     - Show this help"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
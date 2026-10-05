# Kubernetes Networking Deep Dive

## 🌐 Networking Overview

Kubernetes networking enables pods to communicate with each other, services, and external resources. Understanding these concepts is crucial for building production-ready applications.

## 📋 Core Networking Concepts

### **1. Pod Networking**
Every pod gets its own IP address and can communicate with other pods directly.

### **2. Service Discovery**
Services provide stable network identities and load balancing for dynamic pods.

### **3. DNS Resolution**
CoreDNS enables service discovery through friendly names instead of IP addresses.

### **4. Network Policies**
Control traffic flow between pods and namespaces for security.

### **5. Ingress**
Manage external access to services within the cluster.

### **6. Service Mesh**
Advanced networking with observability, security, and traffic management.

---

## 🔗 1. Services & Service Discovery

### **ClusterIP Service (Default)**
Provides internal cluster communication with load balancing.

```yaml
# clusterip-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: default
spec:
  type: ClusterIP  # Default type
  selector:
    app: web
  ports:
  - port: 80        # Service port
    targetPort: 8080 # Pod port
    protocol: TCP
```

#### **Demonstration:**
```bash
# Create a test deployment
kubectl create deployment web --image=nginx:1.21 --replicas=3

# Expose it with ClusterIP service
kubectl expose deployment web --port=80 --target-port=80 --name=web-service

# Check service details
kubectl get services web-service
kubectl describe service web-service

# Test internal connectivity
kubectl run test-pod --image=busybox --rm -it -- wget -qO- web-service
```

### **NodePort Service**
Exposes service on each node's IP at a static port.

```yaml
# nodeport-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080  # Optional: Kubernetes assigns if not specified
```

#### **Demonstration:**
```bash
# Create NodePort service
kubectl apply -f nodeport-service.yaml

# Check assigned node port
kubectl get service web-nodeport

# Access from outside cluster (if using KIND)
kubectl port-forward service/web-nodeport 8080:80
```

### **LoadBalancer Service**
Requests external load balancer from cloud provider.

```yaml
# loadbalancer-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-loadbalancer
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 8080
```

#### **Demonstration:**
```bash
# Create LoadBalancer service (cloud environments only)
kubectl apply -f loadbalancer-service.yaml

# Check external IP assignment
kubectl get service web-loadbalancer

# Note: In KIND/local clusters, external IP will show <pending>
```

### **Headless Service**
Provides direct pod access without load balancing.

```yaml
# headless-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-headless
spec:
  clusterIP: None  # This makes it headless
  selector:
    app: web
  ports:
  - port: 80
```

#### **Demonstration:**
```bash
# Create headless service
kubectl apply -f headless-service.yaml

# Test DNS resolution - returns pod IPs, not service IP
kubectl run test-pod --image=busybox --rm -it -- nslookup web-headless
```

---

## 🎯 2. Endpoints

Endpoints connect services to pods automatically. Understanding them helps troubleshoot connectivity issues.

### **Understanding Endpoints**
```bash
# View service endpoints
kubectl get endpoints

# Detailed endpoint information
kubectl describe endpoints web-service

# Show endpoint-pod relationship
kubectl get endpoints web-service -o yaml
```

### **Endpoint Demonstration**
```yaml
# endpoint-demo.yaml
apiVersion: v1
kind: Service
metadata:
  name: endpoint-demo
spec:
  selector:
    app: demo-app
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
      - name: web
        image: nginx:1.21
        ports:
        - containerPort: 80
```

#### **Interactive Demo:**
```bash
# Deploy the demo
kubectl apply -f endpoint-demo.yaml

# Watch endpoints as pods come online
kubectl get endpoints endpoint-demo --watch

# Scale deployment and observe endpoint changes
kubectl scale deployment demo-deployment --replicas=5
kubectl get endpoints endpoint-demo

# Kill a pod and watch endpoint update
kubectl delete pod <pod-name>
kubectl get endpoints endpoint-demo
```

### **Manual Endpoint Creation**
```yaml
# manual-endpoints.yaml
apiVersion: v1
kind: Service
metadata:
  name: external-service
spec:
  ports:
  - port: 80
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-service  # Must match service name
subsets:
- addresses:
  - ip: 1.1.1.1  # External IP
  - ip: 8.8.8.8  # Another external IP
  ports:
  - port: 80
```

---

## 🏷️ 3. CoreDNS & Service Discovery

CoreDNS provides DNS resolution for services and pods within the cluster.

### **DNS Resolution Pattern**
```
<service-name>.<namespace>.svc.cluster.local
```

### **DNS Demonstration**
```bash
# Create test namespace and service
kubectl create namespace test-dns
kubectl create deployment web --image=nginx -n test-dns
kubectl expose deployment web --port=80 -n test-dns

# Test DNS resolution from different namespaces
kubectl run dns-test --image=busybox --rm -it -- nslookup web.test-dns.svc.cluster.local

# Short name resolution (same namespace)
kubectl run dns-test -n test-dns --image=busybox --rm -it -- nslookup web

# Test FQDN resolution
kubectl run dns-test --image=busybox --rm -it -- nslookup web.test-dns.svc.cluster.local
```

### **CoreDNS Configuration**
```bash
# View CoreDNS configuration
kubectl get configmap coredns -n kube-system -o yaml

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Test DNS from pod
kubectl exec -it <pod-name> -- nslookup kubernetes.default.svc.cluster.local
```

### **Custom DNS Configuration**
```yaml
# custom-dns-policy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-dns-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: custom-dns
  template:
    metadata:
      labels:
        app: custom-dns
    spec:
      dnsPolicy: "None"  # Custom DNS configuration
      dnsConfig:
        nameservers:
        - 8.8.8.8
        - 1.1.1.1
        searches:
        - example.com
      containers:
      - name: app
        image: busybox
        command: ["sleep", "3600"]
```

---

## 🔒 4. Network Policies

Network Policies control traffic flow between pods, providing micro-segmentation for security.

### **Default Deny Policy**
```yaml
# default-deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: secure-namespace
spec:
  podSelector: {}  # Applies to all pods in namespace
  policyTypes:
  - Ingress
  - Egress
```

### **Allow Specific Traffic**
```yaml
# allow-web-traffic.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-traffic
  namespace: secure-namespace
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
```

### **Namespace-Based Policy**
```yaml
# namespace-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-namespace
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
    ports:
    - protocol: TCP
      port: 8080
```

#### **Network Policy Demonstration:**
```bash
# Create test namespaces
kubectl create namespace secure-app
kubectl create namespace allowed-client
kubectl create namespace blocked-client

# Label namespaces
kubectl label namespace allowed-client access=allowed
kubectl label namespace blocked-client access=blocked

# Deploy test applications
kubectl create deployment web -n secure-app --image=nginx
kubectl expose deployment web -n secure-app --port=80

kubectl run client-allowed -n allowed-client --image=busybox --command -- sleep 3600
kubectl run client-blocked -n blocked-client --image=busybox --command -- sleep 3600

# Test connectivity before policy
kubectl exec -n allowed-client client-allowed -- wget -qO- web.secure-app.svc.cluster.local
kubectl exec -n blocked-client client-blocked -- wget -qO- web.secure-app.svc.cluster.local

# Apply network policy
kubectl apply -f namespace-policy.yaml

# Test connectivity after policy
kubectl exec -n allowed-client client-allowed -- wget -qO- web.secure-app.svc.cluster.local  # Should work
kubectl exec -n blocked-client client-blocked -- wget -qO- web.secure-app.svc.cluster.local   # Should fail
```

---

## 🌉 5. Ingress

Ingress manages external HTTP/HTTPS access to services, providing features like SSL termination, path-based routing, and virtual hosting.

### **Basic Ingress**
```yaml
# basic-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

### **Path-Based Routing**
```yaml
# path-routing-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-routing
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /api(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /web(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

### **TLS/SSL Ingress**
```yaml
# tls-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  tls:
  - hosts:
    - secure.example.com
    secretName: tls-secret
  rules:
  - host: secure.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

#### **Ingress Controller Setup (NGINX)**
```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/kind/deploy.yaml

# Wait for controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Create test ingress
kubectl apply -f basic-ingress.yaml

# Test ingress (update /etc/hosts first)
curl -H "Host: myapp.example.com" http://localhost
```

---

## 🕸️ 6. Service Mesh (Istio Basics)

Service mesh provides advanced networking features like traffic management, security, and observability.

### **Istio Installation**
```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio
istioctl install --set values.defaultRevision=default

# Enable sidecar injection
kubectl label namespace default istio-injection=enabled
```

### **Virtual Service**
```yaml
# virtual-service.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: web-virtual-service
spec:
  http:
  - match:
    - headers:
        version:
          exact: v2
    route:
    - destination:
        host: web-service
        subset: v2
  - route:
    - destination:
        host: web-service
        subset: v1
```

### **Destination Rule**
```yaml
# destination-rule.yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: web-destination-rule
spec:
  host: web-service
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

### **Gateway**
```yaml
# istio-gateway.yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: web-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
```

---

## 🛠️ Practical Demonstrations

### **Complete Networking Lab**
```yaml
# networking-lab.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: networking-demo
  labels:
    environment: demo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: networking-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      tier: web
  template:
    metadata:
      labels:
        app: frontend
        tier: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: networking-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
      tier: api
  template:
    metadata:
      labels:
        app: backend
        tier: api
    spec:
      containers:
      - name: api
        image: httpd:2.4
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: networking-demo
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: networking-demo
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 80
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-netpol
  namespace: networking-demo
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
```

#### **Lab Exercises:**
```bash
# Deploy the networking lab
kubectl apply -f networking-lab.yaml

# Test service discovery
kubectl run test-pod -n networking-demo --image=busybox --rm -it -- nslookup frontend-service
kubectl run test-pod -n networking-demo --image=busybox --rm -it -- nslookup backend-service.networking-demo.svc.cluster.local

# Test connectivity
kubectl run test-pod -n networking-demo --image=busybox --rm -it -- wget -qO- frontend-service
kubectl run test-pod -n networking-demo --image=busybox --rm -it -- wget -qO- backend-service:8080

# View endpoints
kubectl get endpoints -n networking-demo

# Test network policy
kubectl run external-pod --image=busybox --rm -it -- wget -qO- backend-service.networking-demo:8080
# Should fail due to network policy

# Scale and observe endpoint changes
kubectl scale deployment frontend -n networking-demo --replicas=5
kubectl get endpoints frontend-service -n networking-demo
```

---

## 🔍 Troubleshooting Network Issues

### **Common Debugging Commands**
```bash
# Check service configuration
kubectl get services
kubectl describe service <service-name>

# Verify endpoints
kubectl get endpoints
kubectl describe endpoints <service-name>

# Test DNS resolution
kubectl run dns-test --image=busybox --rm -it -- nslookup <service-name>

# Check network policies
kubectl get networkpolicies
kubectl describe networkpolicy <policy-name>

# View ingress status
kubectl get ingress
kubectl describe ingress <ingress-name>

# Check CoreDNS
kubectl logs -n kube-system -l k8s-app=kube-dns

# Pod network connectivity
kubectl exec -it <pod-name> -- netstat -tulpn
kubectl exec -it <pod-name> -- ping <target-ip>
```

### **Network Policy Testing**
```bash
# Create test pod for connectivity testing
kubectl run netshoot --image=nicolaka/netshoot --rm -it

# Inside the pod, test connectivity
curl -v telnet://target-service:port
nc -zv target-service port
nslookup target-service
```

---

## 🎯 Key Takeaways

### **Service Types Summary**
| Type | Use Case | External Access | Load Balancing |
|------|----------|----------------|----------------|
| ClusterIP | Internal communication | No | Yes |
| NodePort | Development/testing | Yes (via node ports) | Yes |
| LoadBalancer | Production external access | Yes (cloud LB) | Yes |
| Headless | Direct pod access | No | No |

### **When to Use What**
- **ClusterIP**: Default for internal service-to-service communication
- **NodePort**: Testing and development environments
- **LoadBalancer**: Production external access with cloud providers
- **Headless**: StatefulSets, databases, when you need direct pod access
- **Ingress**: HTTP/HTTPS routing with advanced features
- **Network Policies**: Security and traffic segmentation
- **Service Mesh**: Complex microservices with advanced requirements

### **Production Best Practices**
1. **Always use Network Policies** for security
2. **Implement proper DNS naming** for service discovery
3. **Use Ingress for HTTP traffic** instead of LoadBalancer when possible
4. **Monitor network performance** and connectivity
5. **Plan IP address ranges** to avoid conflicts
6. **Use service mesh** for complex microservices architectures

---

**Understanding Kubernetes networking is essential for building scalable, secure, and maintainable applications! 🌐🚀**

*This guide provides the foundation for mastering Kubernetes networking concepts and implementing them in production environments.*
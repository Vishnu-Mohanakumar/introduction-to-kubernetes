# Simple Nginx Example

Basic web server deployment to learn Kubernetes fundamentals.

## Deploy

```bash
# Files are numbered, so a directory apply deploys everything in the right order
kubectl apply -f demo-manifests/nginx/

# Check it's running
kubectl get pods -n demo-nginx
kubectl get service -n demo-nginx
```

## Test

```bash
# Access the web server
kubectl port-forward -n demo-nginx service/nginx-service 8080:80

# Open browser to http://localhost:8080
# You should see the Nginx welcome page
```

## Clean up

```bash
# Remove everything
kubectl delete -f demo-manifests/nginx/
```

---

**This simple example demonstrates the foundation of Kubernetes application deployment! 🚀**
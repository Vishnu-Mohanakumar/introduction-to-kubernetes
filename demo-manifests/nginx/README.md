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

On KIND (the cluster runs on your own machine):

```bash
# Access the web server
kubectl port-forward -n demo-nginx service/nginx-service 8080:80

# Open browser to http://localhost:8080
# You should see the Nginx welcome page
```

On killercoda (the cluster runs on a remote VM, so `localhost` is not your laptop):

```bash
# Listen on all interfaces so killercoda can reach it, and run it in the background
kubectl port-forward --address 0.0.0.0 -n demo-nginx service/nginx-service 8080:80
```

Open the printed URL (or use the Traffic / Ports menu in the terminal's top-right navigation and
enter `8080`). You should see the Nginx welcome page. More detail in `../../killercoda/README.md`.

## Clean up

```bash
# Remove everything
kubectl delete -f demo-manifests/nginx/
```

---

**This simple example demonstrates the foundation of Kubernetes application deployment! 🚀**
# Killercoda Helpers

Killercoda.com's Kubernetes Playground needs no setup - `kubectl` and `docker` are pre-installed
on a live cluster the moment you start the scenario. The one thing it doesn't handle for you:
getting a **custom-built** image (anything you `docker build` yourself, as opposed to a public
image like `nginx:alpine`) onto every node so kubelet can actually run it.

## Why this is needed

`docker build` only populates Docker's own image store (containerd's `moby` namespace).
Kubelet reads from a separate containerd namespace, `k8s.io`, which never sees images built
this way - even with `imagePullPolicy: IfNotPresent`, kubelet will still try to pull from a
registry and fail. KIND has `kind load docker-image` as a built-in shortcut for this; killercoda
doesn't, so `load-image.sh` does the equivalent by hand: `docker save` the image, then
`ctr -n k8s.io images import` it into containerd on every node (discovered via `kubectl get
nodes`, not hardcoded - works even if killercoda's topology changes).

See the top-level `README.md`'s killercoda section for the full manual walkthrough if you want
to understand what this script is actually doing before using it as a shortcut.

## Usage

Run this from `controlplane` (the only node with a working kubeconfig) after every
`docker build`:

```bash
docker build -t k8s-demo-app:latest .
bash killercoda/load-image.sh k8s-demo-app:latest
```

One image per invocation. For `lab-solution/beginner`'s two images, just call it twice:
```bash
docker build -t todo-backend:latest ./backend
docker build -t todo-frontend:latest ./frontend
bash ../../killercoda/load-image.sh todo-backend:latest
bash ../../killercoda/load-image.sh todo-frontend:latest
```

## Opening a web app in your browser

On KIND, `kubectl port-forward` plus `http://localhost:8080` just works because the cluster runs on
your own machine. On killercoda the cluster is on a remote VM, so `localhost` is not your laptop.
Killercoda gives you a URL for a port on the VM instead:

```bash
# listen on all interfaces, not just localhost, so killercoda's proxy can reach it
kubectl port-forward --address 0.0.0.0 -n demo-app service/demo-app-service 8080:80 &

# print the URL for port 8080
sed 's/PORT/8080/g' /etc/killercoda/host
```

Open the URL it prints, or use the Traffic / Ports menu in the top-right navigation of the
terminal and enter `8080`.

- The service must listen on `0.0.0.0` (hence `--address 0.0.0.0`) and be served over HTTP, not HTTPS.
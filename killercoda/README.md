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

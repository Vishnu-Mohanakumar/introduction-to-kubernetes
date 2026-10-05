#!/bin/bash
# load-image.sh
#
# Get a locally-built Docker image onto every node's containerd, so kubelet can actually
# use it. `docker build` only populates Docker's own image store (containerd's "moby"
# namespace) - kubelet reads from a separate "k8s.io" namespace, which never sees images
# built this way unless explicitly imported. See the top-level README's killercoda section
# for the full explanation. Run this from `controlplane` (the only node with a working
# kubeconfig) after every `docker build`.
#
# Usage: ./load-image.sh <image>[:tag]

set -e

IMAGE="$1"
if [ -z "$IMAGE" ]; then
  echo "Usage: $0 <image>[:tag]"
  exit 1
fi

if ! kubectl get nodes >/dev/null 2>&1; then
  echo "kubectl isn't working here - run this from the node with a configured kubeconfig (controlplane)."
  exit 1
fi

TARFILE="/tmp/$(echo "$IMAGE" | tr '/:' '__').tar"
LOCAL_NODE=$(hostname)

echo "Saving $IMAGE to $TARFILE..."
docker save "$IMAGE" -o "$TARFILE"

for NODE in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  if [ "$NODE" = "$LOCAL_NODE" ]; then
    echo "Importing into containerd on $NODE (local)..."
    ctr -n k8s.io images import "$TARFILE"
  else
    echo "Importing into containerd on $NODE (via ssh)..."
    ssh "$NODE" "ctr -n k8s.io images import -" < "$TARFILE"
  fi
done

rm -f "$TARFILE"
echo "Done - $IMAGE is now available to kubelet on every node."

# Intermediate Lab: Fix the Voting App — Solution

This is the **answer key** for `labs/intermediate/` in the `introduction-to-kubernetes`
repo. It contains the fully fixed manifests for the Azure Voting App (frontend +
Redis), plus the RBAC `Role` and `RoleBinding` the lab asks you to author yourself
in Part 2.

It is intentionally kept outside the `introduction-to-kubernetes` repo so that
learners working through `labs/intermediate/` on their own aren't tempted to peek
before attempting the 5 planted bugs themselves.

## What this solves

`labs/intermediate/manifests/` ships 8 files with 5 deliberately planted bugs
(a Service `targetPort` mismatch, a missing env var, a wrong ConfigMap key
reference, inverted resource requests/limits, and a Service selector mismatch).
This directory contains the same 8 manifests with all 5 bugs fixed, plus 2
additional files (`04-rolebinding.yaml`, `04b-role.yaml`) adding the RoleBinding
and `configmap-reader` Role that the lab's Part 2 Task 1 asks you to write — the
ServiceAccount they bind to (`frontend-sa`) is created in Part 1, but is granted
no permissions until Part 2.

See `SOLUTION_GUIDE.md` for the symptom, root cause, and exact fix for each bug,
plus verified commands/output for all three Part 2 tasks (RBAC, rolling
update/rollback, scaling).

## Directory layout

```
intermediate/
├── manifests/
│   ├── 00-namespace.yaml
│   ├── 01-configmap.yaml
│   ├── 02-secret.yaml
│   ├── 03-serviceaccount.yaml
│   ├── 04-rolebinding.yaml      # new: binds configmap-reader to frontend-sa (Part 2 Task 1)
│   ├── 04b-role.yaml           # new: configmap-reader Role (Part 2 Task 1)
│   ├── 05-redis-deployment.yaml
│   ├── 06-redis-service.yaml
│   ├── 07-frontend-deployment.yaml
│   └── 08-frontend-service.yaml
├── README.md                   # this file
└── SOLUTION_GUIDE.md           # bug-by-bug and Part 2 walkthrough
```

## How to deploy

Runs on killercoda.com's Kubernetes Playground or a local KIND cluster — only
public images (`neilpeterson/azure-vote-front`, `redis`), no custom builds.

```bash
kubectl apply -f manifests/
kubectl wait --for=condition=available deployment --all -n voting-app --timeout=90s
kubectl get all -n voting-app
```

Verify it actually works end-to-end:

```bash
kubectl port-forward -n voting-app svc/azure-vote-front 8080:80 &
curl -s http://localhost:8080 | grep -i "Cats\|Dogs"
```

Tear down:

```bash
kubectl delete namespace voting-app
```

# Advanced Lab: Harden the Voting App — Solution

This is the **answer key** for `labs/advanced/` in the `introduction-to-kubernetes`
repo. It contains the fully fixed manifests for the Azure Voting App running Redis
as a StatefulSet with a full set of operational guardrails (NetworkPolicy, HPA,
PodDisruptionBudget, ResourceQuota/LimitRange), plus the extra ClusterRole the lab
asks you to author yourself in Part 2.

It is intentionally kept outside the `introduction-to-kubernetes` repo so that
learners working through `labs/advanced/` on their own aren't tempted to peek
before attempting the 6 planted bugs themselves.

## What this solves

`labs/advanced/manifests/` ships 14 files with 6 deliberately planted bugs across
the StatefulSet/headless-Service/NetworkPolicy/HPA/PDB/ResourceQuota layer this
tier introduces (the namespace/ConfigMap/Secret/RBAC layer is given working). This
directory contains the same 14 manifests with all 6 bugs fixed, plus a 15th file
(`14-monitoring-clusterrole.yaml`) adding the `monitoring-sa` ServiceAccount +
ClusterRole + ClusterRoleBinding that the lab's Part 2 Task 1 asks you to write.

See `SOLUTION_GUIDE.md` for the symptom, root cause, and exact fix for each bug,
plus verified commands/output for all four Part 2 tasks (RBAC escalation, HPA load
test, PDB drain, NetworkPolicy verification).

**Note on `kubectl run` flags:** the lab README's Part 2 commands use
`kubectl run ... --requests=... --limits=...`. Those flags have been removed from
current `kubectl` (verified absent on v1.36.2). This solution's verified commands
use `kubectl run ... --overrides='{"apiVersion":"v1","spec":{"containers":[{...,
"resources":{"requests":{...},"limits":{...}}}]}}'` instead, which still works and
achieves the same result — see `SOLUTION_GUIDE.md` for the exact commands used.

**Note on `REDIS` targeting:** not one of the 6 planted bugs, but load-bearing —
`08-frontend-deployment.yaml` sets `REDIS=redis-0.redis-headless....`, a specific
Pod, not the bare `redis-headless` Service name. The 3 Redis Pods are independent,
unreplicated stores; a headless Service's DNS fans out to all 3, so different app
workers resolving the bare Service name land on different, out-of-sync backends —
reproduces as non-deterministic HTTP 500s regardless of whether all 6 bugs are
fixed. See `SOLUTION_GUIDE.md`'s "Architecture note" (after Bug 2) for the full
live-reproduced writeup.

**Prerequisite: metrics-server.** Required for Bug 3 and the HPA Part 2 task to be
verifiable at all — neither killercoda nor a plain KIND cluster ships one. See
`SOLUTION_GUIDE.md`'s intro for the install command.

## Directory layout

```
advanced/
├── manifests/
│   ├── 00-namespace.yaml
│   ├── 01-configmap.yaml
│   ├── 02-secret.yaml
│   ├── 03-serviceaccount.yaml
│   ├── 04-role.yaml
│   ├── 05-rolebinding.yaml
│   ├── 06-redis-statefulset.yaml       # fixed: accessModes RWO
│   ├── 07-redis-headless-service.yaml  # fixed: clusterIP: None
│   ├── 08-frontend-deployment.yaml     # fixed: resources block added; REDIS targets redis-0 specifically
│   ├── 09-frontend-service.yaml
│   ├── 10-networkpolicy.yaml           # fixed: ingress podSelector
│   ├── 11-hpa.yaml
│   ├── 12-pdb.yaml                     # fixed: maxUnavailable: 1
│   ├── 13-resourcequota-limitrange.yaml # fixed: all 4 hard values raised
│   └── 14-monitoring-clusterrole.yaml  # new: Part 2 Task 1 ClusterRole
├── README.md                           # this file
└── SOLUTION_GUIDE.md                   # bug-by-bug and Part 2 walkthrough
```

## How to deploy

Runs on killercoda.com's Kubernetes Playground or a local KIND cluster — only
public images (`neilpeterson/azure-vote-front`, `redis:7-alpine`), no custom
builds. Requires a cluster with the metrics-server installed for the HPA to report
real percentages.

```bash
kubectl apply -f manifests/
kubectl wait --for=condition=ready pod -l app=redis -n voting-app --timeout=120s
kubectl wait --for=condition=available deployment/azure-vote-front -n voting-app --timeout=90s
kubectl get all -n voting-app
kubectl get pvc,networkpolicy,hpa,pdb,resourcequota -n voting-app
```

Verify it actually works end-to-end:

```bash
kubectl port-forward -n voting-app svc/azure-vote-front 8080:80 &
curl -s -X POST http://localhost:8080 -d "vote=Cats" -H "Content-Type: application/x-www-form-urlencoded"
curl -s http://localhost:8080 | grep -i "results"
```

A vote tally that actually increments (not just a page that renders) proves the
frontend reached Redis through the headless Service.

Tear down:

```bash
kubectl delete namespace voting-app
```

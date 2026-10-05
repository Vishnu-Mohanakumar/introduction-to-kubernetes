# Solution Guide: Advanced Lab

This guide covers each one — symptom, root cause, exact
fix — followed by verified commands/output for the four Part 2 extension tasks.

---

## Bug 1: Redis StatefulSet PVC access mode

**File:** `06-redis-statefulset.yaml`

**Symptom:** `kubectl get pods -n voting-app` shows `redis-0` stuck `Pending`
indefinitely (and `redis-1`/`redis-2` never even get created, since StatefulSets
roll out ordinally and wait for each predecessor to be `Ready` first).
`kubectl get pvc -n voting-app` shows `redis-data-redis-0` stuck in `Pending`, not
`Bound`. `kubectl describe pvc redis-data-redis-0 -n voting-app` shows:
```
Warning  ProvisioningFailed  persistentvolume-controller  storageclass.storage.k8s.io "standard": only ReadWriteOnce is supported
```
(wording varies by provisioner, but the gist is the same on any CSI driver that
only supports block storage — including KIND's default `rancher.io/local-path`.)

**Root cause:** `volumeClaimTemplates[].spec.accessModes` is `["ReadWriteMany"]`.
Most default StorageClasses (including the one KIND and killercoda ship) are
backed by node-local or block storage, which only supports `ReadWriteOnce` — one
node can mount it read-write, but not many at once. Redis doesn't need shared
read-write storage per node anyway; each replica gets its own PVC.

**Fix:**
```diff
       spec:
-        accessModes: ["ReadWriteMany"]
+        accessModes: ["ReadWriteOnce"]
         resources:
           requests:
             storage: 1Gi
```

**Important — editing the YAML and reapplying is NOT enough on its own.**
`accessModes` is immutable on an existing PVC, and a StatefulSet reuses whatever
PVC already exists for each ordinal (`redis-data-redis-0`, `-1`, `-2`) by name —
it does not create a fresh one just because you deleted and recreated the
StatefulSet. If you only `kubectl delete statefulset redis -n voting-app` and
reapply, the Pods come back but bind to the *same old* `ReadWriteMany` PVCs,
and you'll see the identical `ProvisioningFailed` error as before, now
seemingly "despite the fix." The PVCs themselves must be deleted so the
StatefulSet creates new ones from the corrected template:

```bash
kubectl delete statefulset redis -n voting-app
kubectl delete pvc -n voting-app -l app=redis
kubectl apply -f manifests/06-redis-statefulset.yaml
```

Confirm with `kubectl get pvc -n voting-app` — all three `redis-data-redis-*`
should reach `Bound` (one at a time, since StatefulSets roll out ordinally),
and `kubectl get pods -n voting-app -l app=redis` should show `redis-0/1/2`
all `Running`/`1/1`.

---

## Bug 2: Redis headless Service missing `clusterIP: None`

**File:** `07-redis-headless-service.yaml`

**Symptom:** The Service applies without error and gets a normal `ClusterIP`
(e.g. `10.96.x.x`) instead of `None`. `kubectl get svc redis-headless -n
voting-app` doesn't show the mismatch until you check it specifically — on the
surface it looks like a working Service, DNS resolves, basic connectivity even
works, because a Service without `clusterIP: None` still load-balances to one of
the backing Pods. The real breakage shows up for anything that depends on the
*headless* contract specifically: `nslookup redis-headless.voting-app.svc.cluster.local`
from inside the cluster should return three A records (one per Redis Pod), but
with a normal ClusterIP it returns just the one virtual IP, defeating
StatefulSet DNS discovery (`redis-0.redis-headless`, `redis-1.redis-headless`, etc.
rely on the headless Service's per-Pod DNS entries, which only exist when
`clusterIP: None`).

**Root cause:** The `spec` never sets `clusterIP: None` — the field required to
tell Kubernetes "don't allocate a virtual IP or load-balance, just publish Pod
DNS records directly."

**Fix:**
```diff
 spec:
+  clusterIP: None
   selector:
     app: redis
```

**Important — editing the YAML and reapplying is NOT enough on its own.**
`clusterIP` is immutable on an existing Service once set. If you only edit
`07-redis-headless-service.yaml` and `kubectl apply` it, you get:
```
The Service "redis-headless" is invalid: spec.clusterIPs[0]: Invalid value: ["None"]: may not change once set
```
The Service object itself must be deleted so it gets recreated fresh with
`clusterIP: None`. This does NOT affect the Redis Pods — only the Service is
deleted, not the StatefulSet, so `redis-0/1/2` stay `Running` throughout:

```bash
kubectl delete service redis-headless -n voting-app
kubectl apply -f manifests/07-redis-headless-service.yaml
```

Confirm with `kubectl get svc redis-headless -n voting-app -o jsonpath='{.spec.clusterIP}'`
— should print `None` (literally the word, not blank).

---

## Note: `REDIS` points at one specific Pod, not the headless Service name

Not one of the 6 planted bugs — just worth knowing why `REDIS` is set the way
it is, so you don't "fix" it by mistake.

The 3 Redis Pods are separate, disconnected databases — none of them know
about the other two. The headless Service's DNS name (`redis-headless`)
resolves to *all three* Pod IPs at once, so if the frontend used that generic
name, different votes could land on different Redis Pods at random — the
tally would never add up.

**Fix:** point `REDIS` at one specific Pod's own stable DNS name instead,
which is exactly what a headless Service is for:
```diff
             - name: REDIS
-              value: redis-headless
+              value: redis-0.redis-headless.voting-app.svc.cluster.local
```
Already set this way in the committed `08-frontend-deployment.yaml` — nothing
to change here, just don't "simplify" it back to `redis-headless`.

---

## Bug 3: Frontend Deployment missing `resources` block entirely

**File:** `08-frontend-deployment.yaml`

**Symptom:** The Pods come up fine — `kubectl get pods -n voting-app` shows
`Running`/`1/1`. Nothing looks wrong until you check the HPA: `kubectl describe
hpa azure-vote-front -n voting-app` shows:
```
Warning  FailedGetResourceMetric  horizontal-pod-autoscaler  failed to get cpu utilization: unable to get metrics for resource cpu: no metrics returned from resource metrics API
```
and `kubectl get hpa` shows `TARGETS: <unknown>/50%` forever, never a real
percentage. HPA computes CPU utilization as a *percentage of the Pod's own
`requests.cpu`* — with no request set at all, there's nothing to compute a
percentage against, so the metric is permanently unavailable regardless of how
much CPU the Pod actually uses.

**Root cause:** The container spec has no `resources` field at all — not even a
`limits`-only block (which Kubernetes would auto-copy into `requests`). This is a
different, more complete omission than "limits without requests."

**Fix:**
```diff
           ports:
             - containerPort: 80
+          resources:
+            requests:
+              cpu: 100m
+              memory: 128Mi
+            limits:
+              cpu: 200m
+              memory: 256Mi
           env:
```

**Important — this fix will appear to silently fail if Bug 6 (ResourceQuota)
is still unfixed.** `kubectl apply`-ing this file succeeds, but the Deployment's
rolling update needs to create a new Pod with the added `requests` before it
retires an old one. If the namespace's ResourceQuota is still at its original
(too-low) values, that new Pod is rejected (`exceeded quota: ...
requests.memory=128Mi, used: ..., limited: 256Mi`) — check `kubectl describe rs
-n voting-app -l app=azure-vote-front` for `FailedCreate` events to confirm.
The **old, still-bugged** Pods (no `resources` at all) stay running
indefinitely, so `kubectl get pods` looks healthy and `kubectl describe hpa`
still shows `<unknown>` — looking exactly like the fix didn't take, when
really the rollout is just stuck behind Bug 6. Fix Bug 6 first (or go fix it
now and come back), then nudge the stalled rollout — the ReplicaSet controller
does not automatically retry a `FailedCreate` just because the quota changed:
```bash
kubectl rollout restart deployment/azure-vote-front -n voting-app
kubectl rollout status deployment/azure-vote-front -n voting-app
```

---

## Bug 4: NetworkPolicy ingress selector doesn't match the real frontend label

**File:** `10-networkpolicy.yaml`

**Symptom:** The NetworkPolicy applies cleanly and `kubectl describe
networkpolicy redis-allow-frontend -n voting-app` looks superficially correct —
it has a `podSelector` for `app: redis` and an `ingress.from` rule. But once a
NetworkPolicy selects a Pod, *all* ingress to that Pod is denied by default
except what explicitly matches a rule. The rule's `podSelector.matchLabels` is
`app: frontend`, but the actual frontend Deployment's Pods are labeled
`app: azure-vote-front` (set in `08-frontend-deployment.yaml`) — so the rule
matches *no real Pod in the cluster*, including the legitimate frontend. The
practical symptom: voting stops working entirely (not just "unauthorized Pods are
blocked" — the frontend itself is blocked too, because its own label never
matches the rule). A debug Pod labeled `app: azure-vote-front` running
`redis-cli -h redis-headless -p 6379 ping` times out, exactly like one labeled
`app: debug` would.

**Root cause:** `ingress[0].from[0].podSelector.matchLabels.app` is `frontend`
instead of `azure-vote-front`.

**Fix:**
```diff
   ingress:
     - from:
         - podSelector:
             matchLabels:
-              app: frontend
+              app: azure-vote-front
       ports:
         - protocol: TCP
           port: 6379
```

---

## Bug 5: PodDisruptionBudget `maxUnavailable` too permissive

**File:** `12-pdb.yaml`

**Symptom:** `kubectl get pdb redis-pdb -n voting-app` shows `ALLOWED
DISRUPTIONS: 3` — with only 3 Redis replicas total, that means a voluntary
disruption (node drain, descheduler, cluster-autoscaler scale-down) could legally
evict *all three* Redis Pods at once, which defeats the entire purpose of having
a PDB on a stateful 3-replica StatefulSet (Redis would go fully unavailable
during the drain instead of staying up with 2/3 replicas).

**Root cause:** `maxUnavailable: 3` instead of `1`.

**Fix:**
```diff
   selector:
     matchLabels:
       app: redis
-  maxUnavailable: 3
+  maxUnavailable: 1
```

---

## Bug 6: ResourceQuota hard limits set below what the workload genuinely needs

**File:** `13-resourcequota-limitrange.yaml`

**Symptom:** Even with all other bugs fixed, deploying `manifests/` doesn't fully
come up — `kubectl get events -n voting-app --field-selector reason=FailedCreate`
shows the last Pod(s) in the rollout rejected:
```
Error creating: pods "..." is forbidden: exceeded quota: voting-app-quota, requested: requests.cpu=50m, used: requests.cpu=300m, limited: requests.cpu=300m
```
`kubectl describe resourcequota -n voting-app` shows `requests.cpu` and
`requests.memory` already fully consumed by the steady-state fleet (2 frontend +
3 Redis replicas) with no headroom left, and `limits.cpu`/`limits.memory` nearly
maxed out too.

**Root cause — more subtle than it first looks:** the planted bug narrative
suggests fixing the two `requests.*` fields, but the arithmetic shows all **four**
fields are under-provisioned, and not just for the baseline fleet:

- **Baseline usage** (2 frontend + 3 Redis, at the resource values fixed in Bug 3
  and the StatefulSet's original values): `requests.cpu` 350m, `requests.memory`
  448Mi, `limits.cpu` 1000m, `limits.memory` 896Mi. The original hard caps
  (`requests.cpu: 300m`, `requests.memory: 256Mi`, `limits.cpu: 900m`,
  `limits.memory: 900Mi`) are all below or barely at this baseline — the fleet
  can't even reach steady state without hitting the quota wall.
- **Live-verified gap beyond baseline:** Part 2 Task 2 asks the learner to drive
  the HPA from `minReplicas: 2` up toward `maxReplicas: 5` under load. At max
  scale (5 frontend + 3 Redis): `requests.cpu` 650m, `requests.memory` 832Mi,
  `limits.cpu` 1600m, `limits.memory` 1664Mi — all already past a quota sized
  only for baseline-plus-a-little. We proved this live: with the quota's four
  values set to `600m / 600Mi / 1200m / 1024Mi` (a first-pass fix that covers
  baseline plus a small ad-hoc debug Pod, but not full HPA headroom), running the
  Part 2 Task 2 load generator caused the HPA to correctly decide to scale to 3
  replicas, but the 3rd frontend Pod's creation was then rejected:
  ```
  Error creating: pods "azure-vote-front-d876b4ccc-ppvzf" is forbidden: exceeded quota: voting-app-quota,
  requested: limits.memory=256Mi, used: limits.memory=896Mi, limited: limits.memory=1Gi
  ```
  This reproduced even with no debug Pods present — baseline alone (896Mi) left
  only 128Mi of headroom under a 1024Mi cap, but one more frontend replica needs
  256Mi. The HPA's desired replica count got stuck above its actual available
  count indefinitely.

**Fix — sized for full HPA range (`minReplicas: 2` to `maxReplicas: 5`) plus
headroom for one small ad-hoc debug Pod** (Part 2 Tasks 2 and 4 both create
short-lived debug Pods against this same quota):
```diff
   hard:
-    requests.cpu: "300m"
-    requests.memory: "256Mi"
-    limits.cpu: "900m"
-    limits.memory: "900Mi"
+    requests.cpu: "750m"
+    requests.memory: "900Mi"
+    limits.cpu: "1800m"
+    limits.memory: "1750Mi"
```

Verified headroom at max scale (5 frontend + 3 Redis) plus one 10m/16Mi-request,
50m/32Mi-limit debug Pod: `requests.cpu` 660m/750m, `requests.memory` 848Mi/900Mi,
`limits.cpu` 1650m/1800m, `limits.memory` 1696Mi/1750Mi — all four comfortably
under the hard cap with the debug Pod included.

We re-ran the Part 2 Task 2 load test against these corrected numbers: the HPA
scaled 2→3 replicas with **zero** `FailedCreate` events this time, and scaled
back 3→2 once load stopped (see Part 2 Task 2 below for the full before/after).

**Lesson for anyone fixing this bug by hand:** don't just raise the two
`requests.*` fields the narrative hints at — compute the actual ceiling (max
replicas × per-Pod resources, across every workload the quota covers) before
picking a number, and remember a ResourceQuota caps the *whole namespace*, so an
HPA that can scale a Deployment must have quota headroom for its `maxReplicas`,
not just its steady-state replica count.

**If you already fixed Bug 3 and its rollout looked stuck** (old, no-`resources`
Pods still running, HPA still `<unknown>`), fixing this quota does not
automatically unstick it — nudge the rollout afterward:
```bash
kubectl rollout restart deployment/azure-vote-front -n voting-app
kubectl rollout status deployment/azure-vote-front -n voting-app
```

---

## Part 2 verification

### Task 1 — RBAC: `monitoring-sa` ClusterRole/ClusterRoleBinding (new file `14-monitoring-clusterrole.yaml`)

```
$ kubectl auth can-i list pods -n default --as=system:serviceaccount:voting-app:monitoring-sa
yes

$ kubectl auth can-i list pods -n kube-system --as=system:serviceaccount:voting-app:monitoring-sa
yes

$ kubectl auth can-i get configmaps -n voting-app --as=system:serviceaccount:voting-app:monitoring-sa
no
```

The ClusterRole grants `list` on `pods` cluster-wide (via a ClusterRoleBinding,
not a namespaced RoleBinding), so it works identically in `default` and
`kube-system` — proving it isn't scoped to `voting-app`. It grants nothing else:
`get configmaps` is correctly denied, confirming the grant is as narrow as
specified ("list Pods in every namespace, and nothing else").

### Task 2 — HPA load test

**Note on `kubectl run` flags:** `--requests`/`--limits` have been removed from
current `kubectl` (confirmed absent on client v1.36.2). Use `--overrides` with an
inline Pod spec patch instead:

```bash
kubectl run load-gen --rm -i --image=busybox --restart=Never -n voting-app \
  --overrides='{"apiVersion":"v1","spec":{"containers":[{"name":"load-gen","image":"busybox","command":["/bin/sh","-c","while true; do wget -q -O- http://azure-vote-front > /dev/null; done"],"resources":{"requests":{"cpu":"10m","memory":"16Mi"},"limits":{"cpu":"50m","memory":"32Mi"}}}]}}'
# in another terminal:
kubectl get hpa azure-vote-front -n voting-app -w
```

Verified run (polled every 10s against the corrected ResourceQuota from Bug 6):

```
t=10s   cpu: 1%/50%    replicas: 2   pods: 2
t=20s   cpu: 47%/50%   replicas: 2   pods: 2
t=30s   cpu: 47%/50%   replicas: 2   pods: 2
t=40s   cpu: 58%/50%   replicas: 2   pods: 3   <- 3rd Pod created, HPA hasn't caught up to it in this column yet
t=50s   cpu: 52%/50%   replicas: 3   pods: 3
t=60s   cpu: 52%/50%   replicas: 3   pods: 3
t=70s   cpu: 38%/50%   replicas: 3   pods: 3
t=80s   cpu: 38%/50%   replicas: 3   pods: 3
t=90s   cpu: 38%/50%   replicas: 3   pods: 3
```

```
$ kubectl get events -n voting-app --field-selector reason=FailedCreate
<none — zero quota rejections this run, unlike the first attempt against the uncorrected quota, see Bug 6>
```

Stopped the load generator (`kubectl delete pod load-gen -n voting-app`), then
observed the scale-down (HPA's default downscale stabilization window is 5
minutes, so this takes longer than the scale-up):

```
$ kubectl get events -n voting-app --field-selector reason=SuccessfulRescale
Normal   SuccessfulRescale   horizontalpodautoscaler/azure-vote-front   New size: 3; reason: cpu resource utilization (percentage of request) above target
Normal   SuccessfulRescale   horizontalpodautoscaler/azure-vote-front   New size: 2; reason: All metrics below target

$ kubectl get hpa azure-vote-front -n voting-app
NAME               REFERENCE                     TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
azure-vote-front   Deployment/azure-vote-front   cpu: 1%/50%   2         5         2          40m
```

Confirms the full cycle: scale out under load, scale back in once load stops,
with no ResourceQuota interference.

### Task 3 — PDB drain test

**Run live** on `kind-workshop`, now a 3-node cluster (1 control-plane + 2
workers, `workshop-worker`/`workshop-worker2`; the control-plane stays
unschedulable via its `NoSchedule` taint). With `redis-pdb` fixed to
`maxUnavailable: 1` (Bug 5) and 3 Redis replicas:
```
$ kubectl get pdb redis-pdb -n voting-app
NAME        MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
redis-pdb   N/A             1                 1
```

```bash
kubectl get pod -n voting-app -l app=redis -o wide   # confirm which node(s)
kubectl drain workshop-worker --ignore-daemonsets --delete-emptydir-data --pod-selector='app=redis'
```

In this run, `redis-0` and `redis-2` happened to land on `workshop-worker`,
`redis-1` on `workshop-worker2`.

**Important caveat — this is NOT a 1-worker-cluster quirk, it reproduces on
this 2-worker cluster too.** The real cause is the default `rancher.io/local-path`
StorageClass: it provisions each PVC as a `hostPath`-backed volume on whichever
node the Pod first lands on, and bakes that into the resulting PV as a hard
node affinity rule. A Pod using that PVC can only ever schedule back onto that
exact node — forever, regardless of how many other workers the cluster has.
`kubectl drain` cordons the node *before* evicting, so once a Redis Pod is
evicted its StatefulSet replacement can't schedule anywhere (its PVC says "this
node or nothing"), and the drain stalls after the first eviction. Confirmed via
`kubectl describe pod redis-2 -n voting-app` on the stalled replacement:
```
Warning  FailedScheduling  default-scheduler  0/3 nodes are available: 1 node(s)
didn't match PersistentVolume's node affinity, 1 node(s) had untolerated
taint(s), 1 node(s) were unschedulable.
```
This is NOT a PDB bug — the PDB is doing exactly its job (`ALLOWED DISRUPTIONS: 0`
once one Pod is down), it's just waiting on a Pod that structurally cannot come
back without its original node. Uncordon the node *while the drain is still
running* so the replacement can land and the drain can proceed to the next Pod:
```bash
kubectl uncordon workshop-worker   # run this in a second terminal, right after the first eviction
```

Verified full cycle, confirmed via `kubectl get pods -n voting-app -l app=redis`
polled throughout — READY count never dropped by more than 1 Pod at a time:
```
node/workshop-worker cordoned
evicting pod voting-app/redis-2
evicting pod voting-app/redis-0
error when evicting pods/"redis-0" ...: Cannot evict pod as it would violate the pod's disruption budget.
pod/redis-2 evicted
error when evicting pods/"redis-0" ...: Cannot evict pod as it would violate the pod's disruption budget.
  ... (retries every 5s while redis-2's replacement sits Pending, FailedScheduling on PV node affinity) ...
pod/redis-0 evicted
node/workshop-worker drained
```
`redis-1` on `workshop-worker2` was never touched — `kubectl drain` only acts on
`--pod-selector='app=redis'` Pods on the node actually being drained, confirming
the PDB and the drain both respected per-Pod placement correctly. Had the Bug 5
typo (`maxUnavailable: 3`) still been in place, the same drain command would
have been permitted to evict both `redis-0` and `redis-2` on `workshop-worker`
at once, since `ALLOWED DISRUPTIONS` would have shown `3` — fully defeating the
PDB's purpose.

Afterward: `kubectl uncordon workshop-worker` again if the drain finished with
the node still cordoned (a successful `kubectl drain` leaves the node cordoned
by design, for you to uncordon once real maintenance is done) — confirm with
`kubectl get nodes` and `kubectl get pods -n voting-app -l app=redis` showing
all 3 `Running`/`1/1` again.

### Task 4 — NetworkPolicy verification

Same `--overrides` substitution as Task 2 (no `--requests`/`--limits` on current
`kubectl`), and `--command` is dropped in favor of putting the command directly
in the override JSON's `command` array:

```bash
kubectl run allowed --rm -i --image=redis:7-alpine --restart=Never -n voting-app --labels="app=azure-vote-front" \
  --overrides='{"apiVersion":"v1","spec":{"containers":[{"name":"allowed","image":"redis:7-alpine","command":["redis-cli","-h","redis-headless","-p","6379","-t","5","ping"],"resources":{"requests":{"cpu":"10m","memory":"16Mi"},"limits":{"cpu":"50m","memory":"32Mi"}}}]}}'
```
```
PONG
pod "allowed" deleted from voting-app namespace
```

```bash
kubectl run denied --rm -i --image=redis:7-alpine --restart=Never -n voting-app --labels="app=debug" \
  --overrides='{"apiVersion":"v1","spec":{"containers":[{"name":"denied","image":"redis:7-alpine","command":["redis-cli","-h","redis-headless","-p","6379","-t","5","ping"],"resources":{"requests":{"cpu":"10m","memory":"16Mi"},"limits":{"cpu":"50m","memory":"32Mi"}}}]}}'
```
```
Could not connect to Redis at redis-headless:6379: Operation timed out
pod "denied" deleted from voting-app namespace
pod voting-app/denied terminated (Error)
```

Confirms the fixed NetworkPolicy (Bug 4) is scoped correctly in both directions:
a Pod with the real frontend label (`app=azure-vote-front`) reaches Redis, one
without it (`app=debug`) is blocked.

### End-to-end functional check (Part 1)

```
$ kubectl get pvc -n voting-app
NAME                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
redis-data-redis-0   Bound    pvc-543dcde8-b586-410c-b491-bd803ba67cfc   1Gi        RWO            standard       17s
redis-data-redis-1   Bound    pvc-7a513611-e297-408a-852b-6b78619600dd   1Gi        RWO            standard       12s
redis-data-redis-2   Bound    pvc-c694fa78-6619-4f4c-910e-88bc3de071d0   1Gi        RWO            standard       9s

$ kubectl describe hpa azure-vote-front -n voting-app | grep -i "resource cpu"
  resource cpu on pods  (as a percentage of request):  1% (1m) / 50%

$ kubectl get pdb redis-pdb -n voting-app
NAME        MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
redis-pdb   N/A             1                 1                     37s

$ kubectl port-forward -n voting-app svc/azure-vote-front 18080:80 &
$ curl -s http://localhost:18080 | grep -i "results"
        <div id="results"> Cats - 0 | Dogs - 0 </div>

$ curl -s -X POST http://localhost:18080 -d "vote=Cats" -H "Content-Type: application/x-www-form-urlencoded" -o /dev/null
$ curl -s http://localhost:18080 | grep -i "results"
        <div id="results"> Cats - 1 | Dogs - 0 </div>
```

All PVCs `Bound`, HPA reporting a real percentage, PDB capping disruptions at 1,
and the vote tally actually incrementing (1 vote cast via POST, tally moved
0→1) — proving the frontend genuinely read and wrote through Redis via the
headless Service, not just that the page rendered.

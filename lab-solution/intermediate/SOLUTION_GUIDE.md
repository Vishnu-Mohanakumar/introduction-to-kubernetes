# Solution Guide: Intermediate Lab

This guide covers the solution for each bug — symptom, root cause, exact fix — followed by verified commands/output for the three Part 2 extension tasks.

---

## Bug 1: Redis Service targetPort mismatch

**File:** `06-redis-service.yaml`

**Symptom:** The Redis Deployment and Pod are healthy (`Running`, `1/1`). The
Service also looks fine at a glance. But `kubectl get endpoints redis -n
voting-app` shows `10.244.0.7:6380` — port 6380, not 6379. A debug pod running
`redis-cli -h redis -p 6379 ping` gets `Connection refused`, because the Service
forwards traffic to port 6380, where nothing listens (the container only listens on
6379). Once the `REDIS` env var is also set (Bug 2), `kubectl logs` on the
`azure-vote-front` Pod shows:
```
Failed to connect to Redis, terminating.
```

**Root cause:** `targetPort: 6380` instead of `6379` — the container's actual
`containerPort`.

**Fix:**
```diff
   ports:
     - port: 6379
-      targetPort: 6380
+      targetPort: 6379
```

---

## Bug 2: Missing REDIS env var

**File:** `07-frontend-deployment.yaml`

**Symptom:** Once the other frontend bugs are peeled back, the Pod reports
`Running`/`1/1` (nginx/uwsgi stays up), but `kubectl logs` shows the Python app
itself crashing on startup:
```
Traceback (most recent call last):
  File "./main.py", line 17, in <module>
    redis_server = os.environ['REDIS']
KeyError: 'REDIS'
```
The Pod looking healthy while the app underneath is dead is the trap — `kubectl get
pods` alone doesn't catch this.

**Root cause:** The `env` list never defines a `REDIS` variable at all. The app
reads `os.environ['REDIS']` to find the Redis Service's hostname.

**Fix:** add an entry to `env` (the value is the Redis Service name from
`06-redis-service.yaml`, resolvable via cluster DNS):
```diff
             - name: RELEASE_CHANNEL
               valueFrom:
                 configMapKeyRef:
                   name: frontend-config
                   key: release-channel
+            - name: REDIS
+              value: redis
```

---

## Bug 3: Wrong ConfigMap key reference

**File:** `07-frontend-deployment.yaml`

**Symptom:** `kubectl get pods` shows `CreateContainerConfigError`.
`kubectl describe pod` shows:
```
Warning  Failed  kubelet  Error: couldn't find key release_channel in ConfigMap voting-app/frontend-config
```
The container never even starts.

**Root cause:** `RELEASE_CHANNEL`'s `configMapKeyRef.key` is `release_channel`
(underscore), but the actual key in `01-configmap.yaml` is `release-channel`
(hyphen).

**Fix:**
```diff
             - name: RELEASE_CHANNEL
               valueFrom:
                 configMapKeyRef:
                   name: frontend-config
-                  key: release_channel
+                  key: release-channel
```

---

## Bug 4: Resource limits lower than requests

**File:** `07-frontend-deployment.yaml`

**Symptom:** The most upstream failure — `kubectl apply -f
07-frontend-deployment.yaml` is rejected outright by the API server:
```
The Deployment "azure-vote-front" is invalid:
* spec.template.spec.containers[0].resources.requests: Invalid value: "500m": must be less than or equal to cpu limit of 250m
* spec.template.spec.containers[0].resources.requests: Invalid value: "256Mi": must be less than or equal to memory limit of 128Mi
```
No Deployment, ReplicaSet, or Pod object is ever created — `kubectl get deployment
azure-vote-front` returns `NotFound`. On current Kubernetes this is caught at
admission time, before anything downstream (bugs 2/3/5) is even reachable.

**Root cause:** `limits` (cpu 250m / memory 128Mi) are lower than `requests` (cpu
500m / memory 256Mi). Limits must be ≥ requests.

**Fix:**
```diff
           resources:
             requests:
               cpu: 500m
               memory: 256Mi
             limits:
-              cpu: 250m
-              memory: 128Mi
+              cpu: 500m
+              memory: 256Mi
```

---

## Bug 5: Frontend Service selector mismatch

**File:** `08-frontend-service.yaml`

**Symptom:** The frontend Pod is `Running`/`1/1` with label
`app=azure-vote-front`, but `kubectl get endpoints azure-vote-front -n voting-app`
shows `<none>`. The Service exists, the Pod exists, but they're never connected —
`curl`/port-forward against the Service gets nothing.

**Root cause:** The Service selects `app: frontend`, but the Deployment's Pod
template label is `app: azure-vote-front` (set in `07-frontend-deployment.yaml`).

**Fix:**
```diff
   selector:
-    app: frontend
+    app: azure-vote-front
```

---


### End-to-end functional check (Part 1)

```
$ kubectl get endpoints -n voting-app
NAME               ENDPOINTS          AGE
azure-vote-front   10.244.0.16:80      3s
redis              10.244.0.15:6379    3s

$ kubectl port-forward -n voting-app svc/azure-vote-front 18080:80 &
$ curl -s http://localhost:18080 | grep -i "Cats\|Dogs\|Azure Voting App"
    <title>Azure Voting App</title>
        <div id="logo">Azure Voting App</div>
        <button name="vote" value="Cats" onclick="send()" class="button button1">Cats</button>
        <button name="vote" value="Dogs" onclick="send()" class="button button2">Dogs</button>
        <div id="results"> Cats - 0 | Dogs - 0 </div>
```

The live vote tally (`Cats - 0 | Dogs - 0`) proves the frontend actually reached
Redis — not just that the Pod reports `Running`.

---

## Part 2 - Extending the Architecture

All commands below were run against this solution's manifests deployed on the
`kind-labs-verify` scratch cluster.

### Task 1 — RBAC: `configmap-reader` Role + RoleBinding (new files `04-rolebinding.yaml`, `04b-role.yaml`)

`03-serviceaccount.yaml` creates `frontend-sa` but grants it nothing — neither a
Role nor a RoleBinding exists in the shipped Part 1 manifests. This task is
authoring both from scratch, not fixing a planted bug.

`manifests/04b-role.yaml`:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: configmap-reader
  namespace: voting-app
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
```

`manifests/04-rolebinding.yaml`:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: frontend-rolebinding
  namespace: voting-app
subjects:
  - kind: ServiceAccount
    name: frontend-sa
    namespace: voting-app
roleRef:
  kind: Role
  name: configmap-reader
  apiGroup: rbac.authorization.k8s.io
```

```
$ kubectl apply -f manifests/04b-role.yaml -f manifests/04-rolebinding.yaml
role.rbac.authorization.k8s.io/configmap-reader created
rolebinding.rbac.authorization.k8s.io/frontend-rolebinding created

$ kubectl auth can-i get configmaps -n voting-app --as=system:serviceaccount:voting-app:frontend-sa
yes

$ kubectl auth can-i get secrets -n voting-app --as=system:serviceaccount:voting-app:frontend-sa
no
```

The grant works (the new RoleBinding binds `configmap-reader` to `frontend-sa`) and
the restriction holds (the Role only grants `configmaps`, so `secrets` is denied).

### Task 2 — Rolling update and rollback

```
$ kubectl set image deployment/azure-vote-front azure-vote-front=neilpeterson/azure-vote-front:v2 -n voting-app
deployment.apps/azure-vote-front image updated

$ kubectl rollout status deployment/azure-vote-front -n voting-app
Waiting for deployment "azure-vote-front" rollout to finish: 1 old replicas are pending termination...
deployment "azure-vote-front" successfully rolled out

$ kubectl rollout undo deployment/azure-vote-front -n voting-app
deployment.apps/azure-vote-front rolled back

$ kubectl rollout status deployment/azure-vote-front -n voting-app
Waiting for deployment "azure-vote-front" rollout to finish: 1 old replicas are pending termination...
deployment "azure-vote-front" successfully rolled out
```

Confirmed the image reverted to `v1` after undo:
```
$ kubectl get deployment azure-vote-front -n voting-app -o jsonpath='{.spec.template.spec.containers[0].image}'
neilpeterson/azure-vote-front:v1
```

### Task 3 — Scaling

```
$ kubectl scale deployment/azure-vote-front -n voting-app --replicas=3
deployment.apps/azure-vote-front scaled

$ kubectl wait --for=condition=available deployment/azure-vote-front -n voting-app --timeout=60s
deployment.apps/azure-vote-front condition met

$ kubectl get deployment azure-vote-front -n voting-app
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
azure-vote-front   3/3     3            3           2m19s
```

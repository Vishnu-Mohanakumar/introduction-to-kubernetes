# PostgreSQL StatefulSet Demo

Learn how databases work in Kubernetes with persistent storage - and see real Postgres streaming replication in action, not just 3 unrelated copies.

`postgres-statefulset-0` is the primary. `-1` and `-2` clone from it via `pg_basebackup` on first start (using the stable per-pod DNS name from the headless service) and then stream changes continuously as hot standbys - real replication, not just 3 independent databases sharing a Service.

## Deploy the Database

```bash
# Create PostgreSQL cluster: 1 primary + 2 streaming replicas
kubectl apply -f demo-manifests/database/

# Watch pods start (they start one by one - the primary first, then replicas clone from it)
kubectl get pods -n demo-database -w
```

## Create Test Data (on the Primary)

```bash
kubectl exec -it postgres-statefulset-0 -n demo-database -- psql -U workshop_user -d workshop_db

CREATE TABLE test (id SERIAL, message TEXT);
INSERT INTO test (message) VALUES ('My data should survive!');
SELECT * FROM test;
\q
```

## Confirm Replication Is Working

```bash
# On the primary: who's streaming from it, and are they caught up?
kubectl exec -it postgres-statefulset-0 -n demo-database -- psql -U workshop_user -d workshop_db -c \
  "SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;"
```
Expect 2 rows, `state = streaming`.

```bash
# The data you just wrote on the primary should already be on both replicas
kubectl exec -it postgres-statefulset-1 -n demo-database -- psql -U workshop_user -d workshop_db -c "SELECT * FROM test;"
kubectl exec -it postgres-statefulset-2 -n demo-database -- psql -U workshop_user -d workshop_db -c "SELECT * FROM test;"
```

## Test Primary Failure and Recovery

Now that replication is confirmed working, kill the primary and see what happens:

```bash
# Delete the primary - StatefulSet will recreate it
kubectl delete pod postgres-statefulset-0 -n demo-database
kubectl wait --for=condition=Ready pod/postgres-statefulset-0 -n demo-database

# Data survived, and it's still the primary (not in recovery)
kubectl exec -it postgres-statefulset-0 -n demo-database -- psql -U workshop_user -d workshop_db -c "SELECT * FROM test;"
kubectl exec -it postgres-statefulset-0 -n demo-database -- psql -U workshop_user -d workshop_db -c "SELECT pg_is_in_recovery();"

# Replicas reconnect automatically within a few seconds - recheck from the primary
kubectl exec -it postgres-statefulset-0 -n demo-database -- psql -U workshop_user -d workshop_db -c \
  "SELECT application_name, state FROM pg_stat_replication;"
```

## Confirm Replicas Are Read-Only

```bash
kubectl exec -it postgres-statefulset-1 -n demo-database -- psql -U workshop_user -d workshop_db -c "SELECT pg_is_in_recovery();"
kubectl exec -it postgres-statefulset-2 -n demo-database -- psql -U workshop_user -d workshop_db -c "SELECT pg_is_in_recovery();"

# Try writing directly to each replica - both should fail
kubectl exec -it postgres-statefulset-1 -n demo-database -- psql -U workshop_user -d workshop_db -c \
  "INSERT INTO test (message) VALUES ('this should fail');"
kubectl exec -it postgres-statefulset-2 -n demo-database -- psql -U workshop_user -d workshop_db -c \
  "INSERT INTO test (message) VALUES ('this should also fail');"
```

## What You'll See

- 3 PostgreSQL pods: `postgres-statefulset-0` (primary, read/write) and `-1`/`-2` (replicas, read-only, streaming from the primary)
- Each pod gets its own persistent storage
- Data survives when any pod is deleted - including the primary; on restart it just resumes as primary, and replicas automatically reconnect and keep streaming
- Replicas can't accept writes - `pg_is_in_recovery()` returns true on them

## Clean Up

```bash
kubectl delete -f demo-manifests/database/
```
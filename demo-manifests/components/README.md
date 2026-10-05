# Components Tutorial - Phase 2

Learn how individual Kubernetes resources work by deploying them step-by-step.

## What You'll Learn

- How to organize resources with namespaces
- How to manage app settings with ConfigMaps
- How to handle secrets securely  
- How to give pods identity and permissions (RBAC)
- How to deploy and scale applications

## Step-by-Step Tutorial

### Step 1: Create a Namespace

Namespaces are like folders - they keep your resources organized and separate from other projects.

```bash
# Create the namespace
kubectl apply -f demo-manifests/components/01-namespace.yaml

# Check it was created
kubectl get namespaces

# Look at the details
kubectl describe namespace demo
```

You should see:
```
namespace/demo created
```

**What happened**: Kubernetes created an isolated space called `demo` where all our demo resources will live.

### Step 2: Add Configuration

ConfigMaps store settings for your app (like app name, database URL, feature flags).

```bash
# Create the ConfigMap
kubectl apply -f demo-manifests/components/02-configmaps.yaml

# See the ConfigMap
kubectl get configmaps -n demo

# Look at what's inside
kubectl describe configmap demo-config -n demo
```

You should see:
```
configmap/demo-config created
```

**What happened**: Kubernetes stored some config settings (`config-key` and `another-key`) that our app can use. These are stored as plain text since they're not sensitive.

### Step 3: Add Secrets

Secrets store sensitive stuff like passwords and API keys.

```bash
# Create the Secret
kubectl apply -f demo-manifests/components/03-secrets.yaml

# See the Secret (notice data is hidden)
kubectl get secrets -n demo

# Look at the details
kubectl describe secret demo-secret -n demo
```

You should see:
```
secret/demo-secret created
```

**What happened**: Kubernetes stored a username and password, but encoded them so they're not visible in plain text. Notice that `kubectl describe` doesn't show the actual values - that's for security.

**Try this** (just to see how it works):
```bash
# See the encoded values
kubectl get secret demo-secret -n demo -o yaml

# Decode them (just for learning - don't do this in production!)
echo "dXNlcm5hbWU=" | base64 -d  # Shows: username
echo "cGFzc3dvcmQ=" | base64 -d  # Shows: password
```

### Step 4: Set Up Identity and Permissions (RBAC)

Give your app an identity and control what it can do in Kubernetes.

```bash
# Create an identity for the app
kubectl apply -f demo-manifests/components/04-serviceaccount.yaml

# Define what the app is allowed to do
kubectl apply -f demo-manifests/components/05-role.yaml
kubectl apply -f demo-manifests/components/06-rolebinding.yaml

# Some cluster-wide permissions
kubectl apply -f demo-manifests/components/07-clusterrole.yaml
kubectl apply -f demo-manifests/components/08-clusterrolebinding.yaml

# Check everything was created
kubectl get serviceaccount -n demo
kubectl get roles -n demo
```

**What happened**: 
- **ServiceAccount** = Identity card for your app
- **Role** = List of what actions are allowed (read pods, create secrets, etc.)
- **RoleBinding** = Connects the identity to the permissions

This follows the "principle of least privilege" - only give the minimum permissions needed.

### Step 5: Deploy the Application

Now deploy the actual app that uses all the pieces we just created.

```bash
# Deploy the app
kubectl apply -f demo-manifests/components/09-deployment.yaml

# Watch it start up
kubectl rollout status deployment/demo-deployment -n demo

# Check the pods are running
kubectl get pods -n demo

# Look at one pod's details
kubectl describe pod <pod-name> -n demo
```

You should see:
```
deployment.apps/demo-deployment created
```

**What happened**: 
- Kubernetes started 2 copies of your app (replicas)
- Each pod got the ServiceAccount identity we created
- The ConfigMap and Secret data got injected as environment variables
- Kubernetes pulled the app image (`nginx:alpine`) and started it

### Step 6: Verify Everything Works Together

Check that all the pieces are connected properly.

```bash
# See everything in your namespace
kubectl get all -n demo

# Check that config was injected into the pod
kubectl exec -it <pod-name> -n demo -- env | grep -E "(CONFIG_KEY|USERNAME)"

# See the service account token (Kubernetes does this automatically)
kubectl exec -it <pod-name> -n demo -- ls -la /var/run/secrets/kubernetes.io/serviceaccount/

# Check the app logs
kubectl logs <pod-name> -n demo
```

**What you should see:**
- ConfigMap values show up as environment variables in the pod
- Secret values are there too (but Kubernetes keeps them secure)
- The app is running and logging output
- Kubernetes automatically mounted the ServiceAccount token

## How Resources Connect

Here's how everything flows together:
```
Namespace → ConfigMap + Secret → ServiceAccount + RBAC → Deployment
```

- The **Deployment** uses the **ServiceAccount** for identity
- Pods get **ConfigMap** data as environment variables  
- Pods get **Secret** data as environment variables
- Everything lives in the **Namespace**

## Try These Experiments

### Change the Configuration
```bash
# Update a config value
kubectl patch configmap demo-config -n demo -p '{"data":{"config-key":"My New Value"}}'

# Restart the app to see the change
kubectl rollout restart deployment/demo-deployment -n demo
```

### Scale the App
```bash
# Run 3 copies instead of 2
kubectl scale deployment demo-deployment --replicas=3 -n demo

# Watch them start
kubectl get pods -n demo -w
```

### Check Permissions
```bash
# See what the app is allowed to do
kubectl auth can-i --list --as=system:serviceaccount:demo:demo-service-account -n demo
```

## Clean Up

When you're done, remove everything:
```bash
# Delete all the demo resources
kubectl delete -f demo-manifests/components/

# Check everything is gone
kubectl get all -n demo
```

You should see all resources deleted:
```
configmap "demo-config" deleted
deployment.apps "demo-deployment" deleted  
namespace "demo" deleted
secret "demo-secret" deleted
serviceaccount "demo-service-account" deleted
```

## What You Learned

You now know how to:
- **Organize** resources with namespaces
- **Configure** apps with ConfigMaps
- **Secure** sensitive data with Secrets  
- **Control** app permissions with RBAC
- **Deploy** apps with Deployments
- **Connect** everything together

**Key insight**: Resources depend on each other - create them in the right order!

## Troubleshooting

### Pod Not Starting
If pods show `ErrImagePull`:
```bash
# Check what's wrong
kubectl describe pod <pod-name> -n demo

# Usually means image can't be pulled - check your internet connection
```

### Quick Fix for Everything
Files are numbered, so `kubectl apply -f demo-manifests/components/` applies everything in the
right order in one go - no need to re-run the individual steps above.

---

**Great job! You've learned how Kubernetes resources work together! 🚀**
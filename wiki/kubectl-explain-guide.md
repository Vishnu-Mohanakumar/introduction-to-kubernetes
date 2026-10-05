# kubectl explain - Resource Field Discovery Guide

## 🔍 Basic Usage

### Discover available fields for any resource:
```bash
# Top-level resource structure
kubectl explain pod
kubectl explain deployment
kubectl explain statefulset
kubectl explain service
kubectl explain configmap
kubectl explain secret

# Get all possible fields (verbose)
kubectl explain pod --recursive
kubectl explain statefulset --recursive
```

### Drill down into specific fields:
```bash
# Container specifications
kubectl explain pod.spec.containers
kubectl explain pod.spec.containers.resources
kubectl explain pod.spec.containers.livenessProbe

# StatefulSet specifics
kubectl explain statefulset.spec
kubectl explain statefulset.spec.volumeClaimTemplates
kubectl explain statefulset.spec.serviceName

# Deployment strategy
kubectl explain deployment.spec.strategy
kubectl explain deployment.spec.strategy.rollingUpdate
```

## 📋 Common Examples for Workshop

### Pod Resources:
```bash
# See what you can configure for pods
kubectl explain pod.spec
kubectl explain pod.spec.containers.resources.limits
kubectl explain pod.spec.securityContext
kubectl explain pod.spec.volumes
```

### StatefulSet Fields:
```bash
# StatefulSet-specific configuration
kubectl explain statefulset.spec.serviceName
kubectl explain statefulset.spec.volumeClaimTemplates
kubectl explain statefulset.spec.podManagementPolicy
kubectl explain statefulset.spec.updateStrategy
```

### Service Options:
```bash
# Service types and configuration
kubectl explain service.spec.type
kubectl explain service.spec.selector
kubectl explain service.spec.ports
kubectl explain service.spec.clusterIP
```

### ConfigMap and Secret:
```bash
# Configuration management
kubectl explain configmap.data
kubectl explain secret.type
kubectl explain secret.stringData
```

## 🎯 Workshop Teaching Moments

### Show students how to discover fields:
```bash
# "Let's see what options we have for containers"
kubectl explain pod.spec.containers

# "What can we configure for resources?"
kubectl explain pod.spec.containers.resources

# "How do we set up health checks?"
kubectl explain pod.spec.containers.livenessProbe
kubectl explain pod.spec.containers.readinessProbe
```

### Real-time problem solving:
```bash
# Student asks: "How do I set CPU limits?"
kubectl explain pod.spec.containers.resources.limits

# Student asks: "What StatefulSet options are there?"
kubectl explain statefulset.spec --recursive | grep -A5 -B5 volumeClaim
```

## 🔧 Advanced Usage

### Get API versions:
```bash
# See API version and kind info
kubectl explain pod --api-version=v1
kubectl explain deployment --api-version=apps/v1
```

### Format output:
```bash
# Get shorter descriptions
kubectl explain pod.spec --recursive=false

# Find specific fields
kubectl explain deployment --recursive | grep -i strategy
```

### Example Workshop Flow:
```bash
# "I want to add health checks but can't remember the syntax"
kubectl explain pod.spec.containers.livenessProbe

# "Let's see what we need for the StatefulSet"
kubectl explain statefulset.spec.volumeClaimTemplates

# "What service types are available?"
kubectl explain service.spec.type
```
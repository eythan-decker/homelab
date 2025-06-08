# Loki + Alloy Integration Testing Guide

## Current Issues Analysis

### 1. DNS Resolution Error (CRITICAL)
**Error:** `no such host: loki-gateway.monitoring.svc.cluster.local`
**Root Cause:** Loki service name mismatch

**Check Loki Service Name:**
```bash
kubectl get svc -n monitoring | grep loki
kubectl describe svc -n monitoring loki
```

**Expected Service Names:**
- `loki` (main service, single binary mode)
- NOT `loki-gateway` (only exists in microservices mode)

**Fix Required:** Update Alloy config to use correct service name

### 2. Structured Metadata Errors (MINOR)
**Error:** `negative structured metadata bytes received`
**Impact:** Cosmetic warnings, doesn't affect functionality
**Cause:** Version compatibility issue between Alloy and Loki v13 schema

## Validation Steps

### Phase 1: Service Discovery Verification

1. **Check Loki Service:**
```bash
kubectl get svc -n monitoring -l app.kubernetes.io/name=loki
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki
```

2. **Test DNS Resolution from Alloy Pod:**
```bash
# Get an Alloy pod name
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy

# Test DNS resolution
kubectl exec -n monitoring <alloy-pod-name> -- nslookup loki.monitoring.svc.cluster.local
kubectl exec -n monitoring <alloy-pod-name> -- nslookup loki-gateway.monitoring.svc.cluster.local
```

3. **Check Loki Endpoint Accessibility:**
```bash
# From within cluster
kubectl exec -n monitoring <alloy-pod-name> -- curl -I http://loki:3100/ready
```

### Phase 2: Log Flow Verification

1. **Check Alloy Log Collection:**
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy --tail=50
```

2. **Check Loki Ingestion:**
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=loki --tail=20
```

3. **Test Log Query (via Loki API):**
```bash
# Port-forward to Loki
kubectl port-forward -n monitoring svc/loki 3100:3100

# Query logs (in another terminal)
curl -G "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={namespace="monitoring"}' \
  --data-urlencode 'limit=10'
```

### Phase 3: Grafana Integration

1. **Access Grafana:**
   - URL: `grafana.moria-lab.com`
   - Add Loki datasource manually

2. **Loki Datasource Configuration:**
   - **URL:** `http://loki:3100`
   - **Access:** Server (proxy)
   - **Test Connection**

3. **Basic Log Query Test:**
```logql
{namespace="monitoring"}
{pod=~"alloy-.*"}
{app="loki"} |= "error"
```

### Phase 4: End-to-End Validation

1. **Generate Test Logs:**
```bash
# Create a test pod that generates logs
kubectl run test-logger --image=busybox --restart=Never -- sh -c 'while true; do echo "Test log entry $(date)"; sleep 5; done'
```

2. **Verify in Grafana:**
   - Query: `{pod="test-logger"}`
   - Should see test log entries

3. **Cleanup:**
```bash
kubectl delete pod test-logger
```

## Loki UI Information

**Loki UI Status:** Loki does have a basic web UI at port 3100, but it's minimal:
- `/ready` - Health check
- `/metrics` - Prometheus metrics  
- `/config` - Configuration view
- Basic query interface (limited)

**Primary Interface:** Grafana is the intended UI for log visualization and querying.

**IngressRoute Purpose:** 
- Administrative access to Loki directly
- Health monitoring
- Debug/troubleshooting

## Troubleshooting Commands

### Check All Components Status:
```bash
# Loki
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki
kubectl describe pod -n monitoring -l app.kubernetes.io/name=loki

# Alloy
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy
kubectl describe pod -n monitoring -l app.kubernetes.io/name=alloy

# Services
kubectl get svc -n monitoring | grep -E "(loki|alloy)"
```

### View Component Configurations:
```bash
# Loki config
kubectl get configmap -n monitoring loki -o yaml

# Alloy config  
kubectl get configmap -n monitoring alloy -o yaml
```

### Network Connectivity Tests:
```bash
# Test from any pod in monitoring namespace
kubectl run debug --image=busybox --rm -it --restart=Never -n monitoring -- sh

# Inside the debug pod:
nslookup loki.monitoring.svc.cluster.local
wget -qO- http://loki:3100/ready
```

## Expected Success Indicators

1. ✅ **Alloy:** No DNS resolution errors
2. ✅ **Loki:** Ready status, no schema errors  
3. ✅ **Logs:** Visible in Grafana with proper labels
4. ✅ **Performance:** Sub-second query responses
5. ✅ **Retention:** Old logs automatically cleaned up

## Next Steps After Validation

1. **Configure Grafana Dashboards:**
   - Import Loki dashboard templates
   - Create custom views for home automation logs

2. **Set Up Alerting:**
   - Error rate alerts
   - Log volume monitoring

3. **Optimize Performance:**
   - Adjust retention policies
   - Configure log sampling if needed
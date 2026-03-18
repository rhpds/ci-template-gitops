# Hello World - Value Passing Demonstration

This app demonstrates **three different methods** of passing and displaying values from the catalog through GitOps to the deployed application.

## Three Methods Demonstrated

### METHOD 1: Environment Variables ✅
**Best for:** Configuration, simple values, credentials (from Secrets)

**How it works:**
1. Catalog passes `message` value to bootstrap
2. Bootstrap passes to hello-world chart
3. Chart creates Deployment with env var `GREETING_MESSAGE`

**How to verify:**
```bash
# Find the pod
oc get pods -n user-{guid}-lab

# Check environment variables
oc exec hello-world-xxx-xxx -- env | grep GREETING
```

**You'll see:**
```
GREETING_MESSAGE=🎓 Hello from DEFAULT values - edit catalog to override me!
TENANT_NAME=user-drw4x
REPLICAS_COUNT=1
```

---

### METHOD 2: ConfigMap Mounted as File ✅
**Best for:** Configuration files, scripts, certificates

**How it works:**
1. Catalog passes `message` value to bootstrap
2. Bootstrap passes to hello-world chart
3. Chart creates ConfigMap with `message.txt`
4. Deployment mounts ConfigMap at `/config/message.txt`

**How to verify:**
```bash
# Read the mounted file
oc exec hello-world-xxx-xxx -- cat /config/message.txt
```

**You'll see:**
```
========================================
METHOD 2: ConfigMap Mounted as File
========================================

Message: 🎓 Hello from DEFAULT values - edit catalog to override me!
Tenant: user-drw4x
Replicas: 1
Image Tag: 2.4

This file is mounted at /config/message.txt
```

---

### METHOD 3: HTML Page via ConfigMap ✅
**Best for:** User-facing content, documentation, dashboards

**How it works:**
1. Catalog passes `message` value to bootstrap
2. Bootstrap passes to hello-world chart
3. Chart creates ConfigMap with `index.html` (templated with values)
4. Deployment mounts ConfigMap at `/usr/local/apache2/htdocs/`
5. httpd serves the HTML page
6. Route exposes it externally

**How to verify:**
```bash
# Get the route URL
oc get route hello-world -n user-{guid}-lab

# Access in browser or curl
curl https://hello-world-user-drw4x.apps.cluster-t5qmn.dynamic.redhatworkshops.io
```

**You'll see:** A beautiful HTML page showing all the values!

---

## Value Flow Chart

```
AgnosticV Catalog (common.yaml)
    ↓
ocp4_workload_gitops_bootstrap_helm_values:
  labHelloWorld:
    app:
      message: "Hello from CATALOG!"  ← Override
      replicas: 2                      ← Override
    ↓
Bootstrap Helm Chart (tenant/bootstrap/)
    ↓
Helper Template (_lab-hello-world.tpl)
  - Loads defaults from values-lab-hello-world.yaml
  - Merges catalog overrides
    ↓
Application Template (application-hello-world.yaml)
  - Passes merged values to hello-world chart
    ↓
Hello-World Helm Chart (tenant/labs/hello-world/)
  - Receives values in .Values.message, .Values.replicas
  - Creates resources:
    • Deployment (with env vars)
    • ConfigMap-message (file)
    • ConfigMap-html (HTML page)
    • Service
    • Route
    ↓
Kubernetes Deploys Resources
    ↓
User Sees Values in 3 Different Ways!
```

---

## Testing Different Scenarios

### Scenario 1: Using Defaults
**Catalog config:** Don't pass any overrides
```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  labs:
    helloWorld:
      enabled: true
  # No labHelloWorld override
```

**Result:**
- Message: "🎓 Hello from DEFAULT values - edit catalog to override me!"
- Replicas: 1

### Scenario 2: Catalog Override
**Catalog config:** Pass custom values
```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  labs:
    helloWorld:
      enabled: true
  labHelloWorld:
    app:
      message: "🚀 Hello from the CATALOG!"
      replicas: 3
```

**Result:**
- Message: "🚀 Hello from the CATALOG!"
- Replicas: 3

---

## Files in This Chart

```
tenant/labs/hello-world/
├── Chart.yaml                          # Chart metadata
├── values.yaml                         # Default values (fallback)
├── README.md                           # This file
└── templates/
    ├── deployment.yaml                 # Deployment with all 3 methods
    ├── configmap-message.yaml          # METHOD 2: File
    ├── configmap-html.yaml             # METHOD 3: HTML
    ├── service.yaml                    # ClusterIP Service
    └── route.yaml                      # External access
```

---

## Related Files

**Bootstrap Configuration:**
- `tenant/bootstrap/values-lab-hello-world.yaml` - Default values
- `tenant/bootstrap/templates/_lab-hello-world.tpl` - Helper template
- `tenant/bootstrap/templates/application-hello-world.yaml` - ArgoCD Application

**Catalog Configuration:**
- `agd_v2/sha-learns-ci-cnv/common.yaml` - Catalog that deploys this

---

## Educational Value

This app teaches:
1. ✅ How values flow through GitOps layers
2. ✅ Default vs override patterns
3. ✅ Three common ways to expose configuration
4. ✅ Helm templating with .Values
5. ✅ ArgoCD Application structure
6. ✅ ConfigMap mount patterns

Perfect for learning and demonstrating to other developers! 🎓

# Creating a new tenant app

A tenant app is a Helm chart deployed per-tenant via ArgoCD. Adding one requires three things: the chart itself, a bootstrap Application template, and a values entry.

## 1. Create the Helm chart

Create a directory under `/tenant/` (or a subdirectory like `/tenant/labs/`):

```
tenant/<app-name>/
├── Chart.yaml
├── values.yaml
└── templates/
    └── <your resources>.yaml
```

**Chart.yaml** — follow this exact pattern:

```yaml
apiVersion: v2
name: <app-name>
description: <Short description>
type: application
version: 0.1.0
appVersion: "1.0.0"
```

**values.yaml** — only include values the chart actually uses. If the chart needs tenant identity or cluster info, expect these to be passed from bootstrap:

```yaml
tenant:
  name: xyzzy
deployer:
  domain: apps.cluster-guid.sandbox.opentlc.com
```

If the chart has no configurable values (static resources only), leave values.yaml minimal or empty.

**templates/** — standard Kubernetes manifests with optional Helm templating. Use sync-wave annotations if ordering matters:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "10"
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
```

## 2. Add bootstrap values entry

In `/tenant/bootstrap/values.yaml`, add a block for the new app. Use camelCase for the key:

```yaml
myNewApp:
  enabled: false
  git:
    url: https://github.com/rhpds/ci-template-gitops.git
    revision: main
    path: tenant/<app-name>
```

Always default `enabled: false`.

## 3. Create the Application template

Create `/tenant/bootstrap/templates/application-<app-name>.yaml`:

### If the chart needs tenant/deployer values:

```yaml
{{ if .Values.myNewApp.enabled -}}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tenant-{{ .Values.tenant.name | lower }}-<app-name>
  namespace: openshift-gitops
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: tenants
  source:
    repoURL: {{ .Values.myNewApp.git.url }}
    targetRevision: {{ .Values.myNewApp.git.revision }}
    path: {{ .Values.myNewApp.git.path }}
    helm:
      values: |
        tenant:
        {{- .Values.tenant | toYaml | nindent 10 }}
        deployer:
        {{- .Values.deployer | toYaml | nindent 10 }}
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      enabled: true
    syncOptions:
      - CreateNamespace=true
      - SkipDryRunOnMissingResource=true
      - RespectIgnoreDifferences=true
    retry:
      limit: 10
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
{{- end }}
```

### If the chart is static (no values needed, like lab modules):

```yaml
{{ if .Values.myNewApp.enabled -}}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <app-name>
  namespace: openshift-gitops
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: tenants
  source:
    repoURL: {{ .Values.myNewApp.git.url }}
    targetRevision: {{ .Values.myNewApp.git.revision }}
    path: {{ .Values.myNewApp.git.path }}
  destination:
    server: https://kubernetes.default.svc
    namespace: <target-namespace>
  syncPolicy:
    automated:
      enabled: true
    syncOptions:
      - CreateNamespace=true
      - SkipDryRunOnMissingResource=true
      - RespectIgnoreDifferences=true
    managedNamespaceMetadata:
      labels:
        openshift.io/cluster-monitoring: "true"
    retry:
      limit: 10
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
{{- end }}
```

## 4. Adding a lab with multiple modules

Labs group related modules under a single enable/disable gate. Each lab gets its own values file and helper template, keeping module config out of the main `values.yaml`. See the Rosetta lab for the reference implementation.

### a. Add the lab gate to `values.yaml`

In `/tenant/bootstrap/values.yaml`, add an entry under `labs`:

```yaml
labs:
  rosetta:
    enabled: false
  myNewLab:
    enabled: false
```

### b. Create the lab values file

Create `/tenant/bootstrap/values-lab-<name>.yaml` with all module definitions:

```yaml
labMyNewLab:
  moduleOne:
    enabled: false
    git:
      url: https://github.com/rhpds/ci-template-gitops.git
      revision: main
      path: tenant/labs/my-new-lab/module-one
  moduleTwo:
    enabled: false
    git:
      url: https://github.com/rhpds/ci-template-gitops.git
      revision: main
      path: tenant/labs/my-new-lab/module-two
```

### c. Create the helper template

Create `/tenant/bootstrap/templates/_lab-<name>.tpl`:

```yaml
{{- define "labMyNewLab" -}}
{{- $defaults := (.Files.Get "values-lab-<name>.yaml" | fromYaml).labMyNewLab | default dict -}}
{{- $overrides := .Values.labMyNewLab | default dict -}}
{{- mergeOverwrite $defaults $overrides | toYaml -}}
{{- end -}}
```

The helper loads defaults from the values file, then merges any inline overrides from the deployer (via `.Values.labMyNewLab`). This means `/bootstrap/` and the deployer don't need to know about the file — overrides are passed as normal Helm values.

### d. Create module Application templates

Create one template per module in `/tenant/bootstrap/templates/labs/<name>/`:

```yaml
{{- $lab := include "labMyNewLab" . | fromYaml -}}
{{ if and .Values.labs.myNewLab.enabled $lab.moduleOne.enabled -}}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-new-lab-module-one
  namespace: openshift-gitops
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: tenants
  source:
    repoURL: {{ $lab.moduleOne.git.url }}
    targetRevision: {{ $lab.moduleOne.git.revision }}
    path: {{ $lab.moduleOne.git.path }}
  destination:
    server: https://kubernetes.default.svc
    namespace: <target-namespace>
  syncPolicy:
    automated:
      enabled: true
    syncOptions:
      - CreateNamespace=true
      - SkipDryRunOnMissingResource=true
      - RespectIgnoreDifferences=true
    retry:
      limit: 10
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
{{- end }}
```

Each template uses `$lab` (from the helper) for git coordinates and the module enable flag, and `.Values.labs.<name>.enabled` for the lab-level gate. Both must be true for the module to render.

### e. Verification

```bash
# nothing renders (lab disabled)
helm template tenant/bootstrap --set labMyNewLab.moduleOne.enabled=true

# module renders (both gates true)
helm template tenant/bootstrap \
  --set labs.myNewLab.enabled=true \
  --set labMyNewLab.moduleOne.enabled=true
```

### Existing labs

| Lab | Gate | Values file | Helper |
|-----|------|-------------|--------|
| Rosetta | `labs.rosetta.enabled` | `values-lab-rosetta.yaml` | `_lab-rosetta.tpl` |

## Required elements — do not skip

- **`resources-finalizer.argocd.argoproj.io`** finalizer on the Application metadata. This ensures all managed resources are deleted when the tenant's `bootstrap-tenant-GUID` app is removed. Without it, resources are orphaned.
- **`{{ if .Values.myNewApp.enabled -}}`** guard so the app is only deployed when explicitly enabled. For lab modules, use the two-level gate: `{{ if and .Values.labs.<name>.enabled $lab.module.enabled -}}`.
- **`project: tenants`** — all tenant apps belong to this ArgoCD project.

## Verification

After creating all pieces, run:

```bash
helm template tenant/bootstrap --set myNewApp.enabled=true
```

Confirm the rendered output includes your new Application with the correct source path, values, and finalizer.

## If the app creates resources via kubectl (not Helm-managed)

Resources created at runtime by Jobs (via `kubectl apply`) are not tracked by ArgoCD and won't be cleaned up by the finalizer. These must be explicitly deleted by a cleanup mechanism. Follow the existing pattern for secrets and configmaps.

If the Job needs RBAC, scope it with `resourceNames` to prevent cross-tenant access. Note that `resourceNames` does not work with the `create` verb (the resource doesn't exist yet), so split rules: use `create` without `resourceNames`, and `get`/`update`/`patch` with `resourceNames`.

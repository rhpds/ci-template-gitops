# Tenant Layer

The `tenant/` directory is where per-user workloads live. Each user who provisions
a lab gets their own `bootstrap-tenant-<GUID>` ArgoCD Application pointing at
`tenant/bootstrap/`. Everything here deploys into namespaces scoped to that user's GUID.

This is **not** where cluster operators or shared services live. Those belong in `cluster/`.

---

## TLDR

Three patterns are provided. All are disabled by default. Pick the one that fits your workload.

**Example 1 — Inline resource** (simplest, no sub-chart):
```yaml
ocp4_workload_tenant_namespace_suffixes:
- suffix: example1-lab

ocp4_workload_gitops_bootstrap_helm_values:
  example1InlineResource:
    enabled: true
    namespace: "user-{{ guid }}-example1-lab"
```

**Example 2 — Helm chart in this repo:**
```yaml
ocp4_workload_tenant_namespace_suffixes:
- suffix: example2-lab

ocp4_workload_gitops_bootstrap_helm_values:
  example2HelmBasic:
    enabled: true
    namespace: "user-{{ guid }}-example2-lab"
```

**Example 3 — Parameterized Helm chart (catalog drives values):**
```yaml
ocp4_workload_tenant_namespace_suffixes:
- suffix: example3-lab

ocp4_workload_gitops_bootstrap_helm_values:
  labs:
    example3HelmParameterized:
      enabled: true
      namespace: "user-{{ guid }}-example3-lab"
      message: "Hello, {{ ocp4_workload_tenant_keycloak_username }}!"
      replicas: 1
      imageTag: "latest"
```

Namespaces are created by `ocp4_workload_tenant_namespace` **before** ArgoCD runs.
The suffix must match what you pass to that workload.

---

## How it works

```
Ansible role (ocp4_workload_gitops_bootstrap)
  └── bootstrap-tenant-<GUID>  →  tenant/bootstrap/
        ├── Example 1: Deployment + Service + Route (inline, no sub-chart)
        ├── Example 2: ArgoCD Application  →  tenant/example2-helm-basic/
        └── Example 3: ArgoCD Application  →  tenant/labs/example3-helm-parameterized/
```

The Ansible role creates only `bootstrap-tenant-<GUID>`. ArgoCD renders the bootstrap
chart and creates child Applications for Examples 2 and 3. Example 1 has no child
Application — its resources are rendered directly by the bootstrap chart itself.

Values injected automatically by the Ansible role (never set these in the catalog):
- `deployer.domain` — cluster ingress domain
- `deployer.apiUrl` — cluster API URL
- `deployer.guid` — the deployment GUID

---

## File structure

```
tenant/
├── bootstrap/                          # Entry point — ArgoCD deploys this first
│   ├── values.yaml                     # All defaults (heavily commented)
│   └── templates/
│       ├── example1-inline-resource-pod.yaml
│       ├── example1-inline-resource-service.yaml
│       ├── example1-inline-resource-route.yaml
│       ├── example2-application-helm-basic.yaml    # Creates child ArgoCD Application
│       └── example3-application-helm-parameterized.yaml
│
├── example2-helm-basic/                # Chart deployed by Example 2
│   └── templates/
│       ├── deployment.yaml, service.yaml, route.yaml
│       ├── configmap-html.yaml
│       └── configmap-provisiondata.yaml
│
└── labs/
    └── example3-helm-parameterized/    # Chart deployed by Example 3
        └── templates/
            ├── deployment.yaml, service.yaml, route.yaml
            ├── configmap-html.yaml
            └── configmap-message.yaml
```

---

## The bootstrap chart (`tenant/bootstrap/`)

[`bootstrap/values.yaml`](bootstrap/values.yaml) contains defaults for every example
and is heavily commented. Read it — it explains every key.

Values you control from the catalog (via `ocp4_workload_gitops_bootstrap_helm_values`):
- `tenant.name` — the GUID string, used in resource names and labels
- `tenant.user.name` — the Keycloak username (`user-<GUID>`)
- Per-example `enabled`, `namespace`, and `git` overrides

**Minimum catalog block for the bootstrap:**
```yaml
ocp4_workload_gitops_bootstrap_repo_url: https://github.com/rhpds/ci-template-gitops.git
ocp4_workload_gitops_bootstrap_repo_revision: main
ocp4_workload_gitops_bootstrap_repo_path: tenant/bootstrap
ocp4_workload_gitops_bootstrap_application_name: "bootstrap-tenant-{{ guid }}"
ocp4_workload_gitops_bootstrap_application_project: tenants

ocp4_workload_gitops_bootstrap_helm_values:
  tenant:
    name: "{{ guid }}"
    user:
      name: "{{ ocp4_workload_tenant_keycloak_username }}"
```

---

## Example 1 — Inline resource (`example1InlineResource`)

Raw Kubernetes manifests embedded directly in the bootstrap chart templates.
No sub-chart, no child ArgoCD Application. The Deployment, Service, and Route are
all rendered as part of `bootstrap-tenant-<GUID>` itself.

**Critical:** Always set `namespace:` explicitly on every resource. Without it,
ArgoCD uses the Application's destination namespace, which is not a tenant namespace.

**When to use:** Simple, one-off resources that don't need their own sync lifecycle.

---

## Example 2 — Helm chart in this repo (`example2HelmBasic`)

The bootstrap chart renders an ArgoCD `Application` pointing at [`example2-helm-basic/`](example2-helm-basic/).
That child Application manages its own resources with its own sync status in ArgoCD.

`deployer`, `tenant`, and `example2HelmBasic` values are passed down to the child
chart via inline `helm.values` in the Application spec.

**When to use:** Multiple related resources that benefit from Helm templating and a
visible, dedicated entry in the ArgoCD UI.

---

## Example 3 — Parameterized Helm chart (`labs.example3HelmParameterized`)

Same as Example 2, but the child chart at [`labs/example3-helm-parameterized/`](labs/example3-helm-parameterized/)
is fully parameterized. The catalog drives `message`, `replicas`, and `imageTag` values.
The bootstrap template explicitly threads each value through to the child chart.

`namespace` has no safe default (`NAMESPACE-MUST-BE-SET-BY-CATALOG`) intentionally —
omitting it produces a loud ArgoCD failure rather than a silent wrong-namespace deploy.

**When to use:** Workloads where lab behavior is driven by catalog parameters —
per-user messages, feature flags, resource sizing, image versions.

---

## Enabling multiple examples together

```yaml
ocp4_workload_tenant_namespace_suffixes:
- suffix: example1-lab
- suffix: example2-lab
- suffix: example3-lab

ocp4_workload_gitops_bootstrap_helm_values:
  tenant:
    name: "{{ guid }}"
    user:
      name: "{{ ocp4_workload_tenant_keycloak_username }}"
  example1InlineResource:
    enabled: true
    namespace: "user-{{ guid }}-example1-lab"
  example2HelmBasic:
    enabled: true
    namespace: "user-{{ guid }}-example2-lab"
  labs:
    example3HelmParameterized:
      enabled: true
      namespace: "user-{{ guid }}-example3-lab"
      message: "Welcome to the lab!"
      replicas: 1
      imageTag: "latest"
```

---

## Passing data back to RHDP

Per-tenant provision data uses a ConfigMap labeled `demo.redhat.com/tenant-<GUID>: "true"`.
See `tenant/example2-helm-basic/templates/configmap-provisiondata.yaml` for a working example.

For cluster-level provision data (not per-tenant), see
[`cluster/infra/bootstrap/templates/configmap-cluster-provisiondata.yaml`](../cluster/infra/bootstrap/templates/configmap-cluster-provisiondata.yaml).

# Tenant Layer — Start Here

The `tenant/` directory is where per-user workloads live. When a user provisions a lab through the catalog, this layer gets deployed — once per user, into namespaces scoped to that user's GUID.

This is **not** where cluster-wide operators or infrastructure live. That belongs in `cluster/infra/` and `cluster/platform/`. The tenant layer assumes those are already in place.

---

## Table of Contents

- [File Structure](#file-structure)
- [How It Works](#how-it-works)
- [The Bootstrap Chart](#the-bootstrap-chart-tenantbootstrap)
- [Example 1 — Inline Resource](#example-1--inline-resource-example1inlineresource)
- [Example 2 — Helm Chart in Repo](#example-2--helm-chart-in-repo-example2helmbasic)
- [Example 3 — Parameterized Helm Chart](#example-3--parameterized-helm-chart-labsexample3helmparameterized)
- [Enabling Multiple Examples Together](#enabling-multiple-examples-together)

---

## File Structure

```
tenant/
├── bootstrap/                          # The root Helm chart ArgoCD deploys first
│   ├── Chart.yaml
│   ├── values.yaml                     # Defaults for all examples (all disabled by default)
│   └── templates/
│       ├── example1-inline-resource-pod.yaml      # Example 1: Deployment manifest
│       ├── example1-inline-resource-service.yaml  # Example 1: Service
│       ├── example1-inline-resource-route.yaml    # Example 1: Route
│       ├── example2-application-helm-basic.yaml   # Example 2: ArgoCD Application
│       └── example3-application-helm-parameterized.yaml  # Example 3: ArgoCD Application
│
├── example2-helm-basic/                # Helm chart deployed by Example 2's Application
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── route.yaml
│       ├── configmap-html.yaml
│       └── configmap-provisiondata.yaml
│
└── labs/
    └── example3-helm-parameterized/    # Helm chart deployed by Example 3's Application
        ├── Chart.yaml
        ├── README.md
        ├── values.yaml
        └── templates/
            ├── deployment.yaml
            ├── service.yaml
            ├── route.yaml
            ├── configmap-html.yaml
            └── configmap-message.yaml
```

---

## How It Works

The deployer runs the `ocp4_workload_gitops_bootstrap` Ansible role, which creates a single ArgoCD Application called `bootstrap-tenant-<GUID>`. That Application points at [`tenant/bootstrap/`](bootstrap/) in this repo, rendering it as a Helm chart with values injected from the catalog.

The bootstrap chart is the **entry point**. Depending on which examples are enabled in the catalog, it either renders Kubernetes manifests directly (Example 1) or creates additional ArgoCD Applications (Examples 2 and 3) that pull in their own Helm charts.

All examples are **disabled by default** in [`bootstrap/values.yaml`](bootstrap/values.yaml). The catalog must explicitly enable each one.

### ArgoCD Project vs OpenShift Namespace

These are two different things and are easy to confuse:

- **ArgoCD project** — controls which ArgoCD AppProject the Application belongs to. All tenant Applications (Examples 2 and 3) use `project: tenants`. This is a cluster-wide ArgoCD concept, not a Kubernetes namespace.
- **OpenShift namespace** — the Kubernetes namespace where the actual workload resources (Deployments, Services, Routes) are created. This is per-tenant and per-example, e.g. `user-<GUID>-example1-lab`, `user-<GUID>-example2-lab`. The namespace is created by the `ocp4_workload_tenant_namespace` Ansible workload before ArgoCD runs, and must be set explicitly in the catalog.

Example 1 is inline — it has no ArgoCD Application of its own, so no AppProject. It deploys directly into whatever namespace `bootstrap-tenant-<GUID>` targets via `example1InlineResource.namespace`.

---

## The Bootstrap Chart (`tenant/bootstrap/`)

[`bootstrap/values.yaml`](bootstrap/values.yaml) contains defaults for every example. The catalog overrides these at deploy time via `ocp4_workload_gitops_bootstrap_helm_values`.

Key top-level values injected by the deployer (you don't need to set these manually):
- `deployer.domain` — cluster ingress domain
- `deployer.apiUrl` — cluster API URL
- `deployer.guid` — the deployment GUID

Values you **do** control from the catalog:
- `tenant.name` — the GUID string, used in resource names and labels
- `tenant.user.name` — the Keycloak username (`user-<GUID>`)
- Per-example `enabled`, `namespace`, and `git` overrides

### AgnosticV Tips

Your AgnosticV `common.yaml` might look something like this for the bootstrap block:

```yaml
ocp4_workload_gitops_bootstrap_repo_url: https://github.com/rhpds/ci-template-gitops.git
ocp4_workload_gitops_bootstrap_repo_revision: main
ocp4_workload_gitops_bootstrap_repo_path: tenant/bootstrap
ocp4_workload_gitops_bootstrap_application_name: "bootstrap-tenant-{{ guid }}"

ocp4_workload_gitops_bootstrap_helm_values:
  tenant:
    name: "{{ guid }}"
    user:
      name: "{{ ocp4_workload_tenant_keycloak_username }}"
  # deployer.domain, deployer.apiUrl, deployer.guid are injected automatically
```

---

## Example 1 — Inline Resource (`example1InlineResource`)

**Pattern:** Raw Kubernetes manifests embedded directly in the bootstrap chart templates.

No separate ArgoCD Application. No sub-chart. The Deployment, Service, and Route are rendered as part of `bootstrap-tenant-<GUID>` itself. This is the simplest possible pattern — one chart, everything inline.

**Files:**
- [`bootstrap/templates/example1-inline-resource-pod.yaml`](bootstrap/templates/example1-inline-resource-pod.yaml) — Deployment (UBI8 httpd)
- [`bootstrap/templates/example1-inline-resource-service.yaml`](bootstrap/templates/example1-inline-resource-service.yaml) — ClusterIP Service on port 8080
- [`bootstrap/templates/example1-inline-resource-route.yaml`](bootstrap/templates/example1-inline-resource-route.yaml) — Edge-terminated Route

All three files share the same `{{ if .Values.example1InlineResource.enabled }}` gate. If the gate is false, none of the three resources are rendered.

**Route hostname:** `example1-inline-resource-<GUID>.<domain>`

**When to use this pattern:** Simple, one-off resources that don't need their own lifecycle or separate chart. Good for adding a single resource to a bootstrap deployment without creating a new chart.

> **Important — always set `namespace:` explicitly on every resource.** Because Example 1 resources are rendered directly by `bootstrap-tenant-<GUID>`, any resource without an explicit `namespace:` field will fall back to whatever destination namespace ArgoCD has configured for that Application — which is not a tenant namespace. Every template in Example 1 sets `namespace: {{ .Values.example1InlineResource.namespace }}` for this reason.

### AgnosticV Tips

Your AgnosticV `common.yaml` might look something like this for Example 1:

```yaml
# Namespace created by ocp4_workload_tenant_namespace before ArgoCD runs
ocp4_workload_tenant_namespace_suffixes:
- suffix: example1-lab

ocp4_workload_gitops_bootstrap_helm_values:
  example1InlineResource:
    enabled: true
    namespace: "user-{{ guid }}-example1-lab"
```

> **Note:** The namespace must already exist before ArgoCD syncs Example 1, because `CreateNamespace=false` is the safe default for inline resources. The `ocp4_workload_tenant_namespace` workload handles this — make sure the suffix matches your namespace.

---

## Example 2 — Helm Chart in Repo (`example2HelmBasic`)

**Pattern:** The bootstrap chart renders an ArgoCD `Application` resource that points at a Helm chart living in a sub-directory of the same repo ([`example2-helm-basic/`](example2-helm-basic/)).

This adds a layer of indirection: the bootstrap Application creates a child Application, which manages its own set of resources. This gives Example 2 its own sync lifecycle, its own sync status in the ArgoCD UI, and lets the child chart evolve independently.

**Files involved:**
- [`bootstrap/templates/example2-application-helm-basic.yaml`](bootstrap/templates/example2-application-helm-basic.yaml) — the ArgoCD Application manifest
- [`example2-helm-basic/`](example2-helm-basic/) — the full Helm chart with Deployment, Service, Route, and ConfigMaps

**Route hostname:** `example2-helm-basic-<GUID>.<domain>`

The bootstrap chart passes `deployer`, `tenant`, and `example2HelmBasic` values down to the child chart via inline `helm.values` in the Application spec.

**When to use this pattern:** When your workload has multiple resources that belong together, benefits from Helm templating, and you want it to appear as its own entry in the ArgoCD UI.

### AgnosticV Tips

Your AgnosticV `common.yaml` might look something like this for Example 2:

```yaml
ocp4_workload_tenant_namespace_suffixes:
- suffix: example2-lab

ocp4_workload_gitops_bootstrap_helm_values:
  example2HelmBasic:
    enabled: true
    namespace: "user-{{ guid }}-example2-lab"
    git:
      targetRevision: main    # or a specific branch/tag
```

> **Note:** The `git.repoURL` and `git.path` have sensible defaults in [`bootstrap/values.yaml`](bootstrap/values.yaml). You only need to override `targetRevision` if you're pointing at a non-default branch (e.g., during development on a feature branch).

---

## Example 3 — Parameterized Helm Chart (`labs.example3HelmParameterized`)

**Pattern:** Same as Example 2 (bootstrap creates a child ArgoCD Application pointing at a sub-chart), but the child chart is **fully parameterized** — the catalog drives its behavior through values rather than hardcoding them.

The chart at [`labs/example3-helm-parameterized/`](labs/example3-helm-parameterized/) accepts:
- `message` — displayed on the app's web page
- `replicas` — number of pod replicas
- `imageTag` — container image tag

These are passed from the catalog → [`bootstrap/values.yaml`](bootstrap/values.yaml) defaults → ArgoCD Application → child chart. The bootstrap template at [`bootstrap/templates/example3-application-helm-parameterized.yaml`](bootstrap/templates/example3-application-helm-parameterized.yaml) explicitly threads each value through, so the catalog has full control.

**Route hostname:** `example3-helm-parameterized-<GUID>.<domain>`

**When to use this pattern:** When you need catalog-driven customization — for example, per-user messages, lab-specific configurations, or values that differ between dev/staging/prod deployments.

### AgnosticV Tips

Your AgnosticV `common.yaml` might look something like this for Example 3:

```yaml
ocp4_workload_tenant_namespace_suffixes:
- suffix: example3-lab

ocp4_workload_gitops_bootstrap_helm_values:
  labs:
    example3HelmParameterized:
      enabled: true
      namespace: "user-{{ guid }}-example3-lab"
      git:
        targetRevision: main
      message: "Hello, {{ ocp4_workload_tenant_keycloak_username }}!"
      replicas: 1
      imageTag: "latest"
```

> **Important:** The `namespace` field has no safe default — it is set to `NAMESPACE-MUST-BE-SET-BY-CATALOG` in [`bootstrap/values.yaml`](bootstrap/values.yaml) intentionally. If you omit it, ArgoCD will fail loudly rather than silently deploying to the wrong namespace.

---

## Enabling Multiple Examples Together

You can enable all three in a single `ocp4_workload_gitops_bootstrap_helm_values` block:

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

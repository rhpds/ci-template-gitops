# CLAUDE.md — ci-template-gitops

This repo is a GitOps template for deploying OpenShift labs and demos via ArgoCD.
It is used as-is (cloned and pointed at) by AgnosticV catalog items via the
`ocp4_workload_gitops_bootstrap` Ansible role.

## What this repo is NOT

- Not a standalone app. It is deployed by AgnosticV/AgnosticD, not run directly.
- Not a single monolithic chart. It is three independent bootstrap entry points.
- The `workloads_library/` charts are not deployed automatically. They require
  explicit `enabled: true` from the catalog.

## Deployment mechanism

The Ansible role `ocp4_workload_gitops_bootstrap` (in `agnosticd/core_workloads`)
creates a single ArgoCD `Application` resource pointing at a path in this repo.
That Application renders the Helm chart at that path. ArgoCD then manages everything
that chart produces.

The role injects `deployer.domain`, `deployer.apiUrl`, and `deployer.guid` into the
Helm values automatically from the live cluster. These keys exist as placeholders in
every `values.yaml` but are always overwritten at deploy time. Never set them in the catalog.

If `ocp4_workload_gitops_bootstrap_helm_values` is set in the catalog, it is merged
with the injected `deployer.*` values and passed to ArgoCD as inline `helm.values`.
If it is not set, the role falls back to a kustomize plugin (rarely used).

## Three-layer architecture

```
Layer     Entry point                      ArgoCD app name         Created by
------    --------------------------       ----------------------  --------------------
infra     cluster/infra/bootstrap/         bootstrap-infra         Ansible role
platform  cluster/platform/bootstrap/      bootstrap-platform      infra bootstrap chart
tenant    tenant/bootstrap/                bootstrap-tenant-<GUID> Ansible role (per user)
```

Infra and tenant are created by the Ansible role independently (two separate role
invocations, typically in the cluster CI and the tenant/user CI respectively).
Platform is never created by the Ansible role — it is always a child of the infra bootstrap.

## How values flow through the system

```
AgnosticV catalog
  ocp4_workload_gitops_bootstrap_helm_values:
    someInfraWorkload:                  → top-level values in cluster/infra/bootstrap/
      enabled: true
    platformValues:                     → forwarded verbatim to cluster/platform/bootstrap/
      somePlatformWorkload:             → top-level values in cluster/platform/bootstrap/
        enabled: true
```

The forwarding happens in `cluster/infra/bootstrap/templates/application-bootstrap-platform.yaml`.
It passes `.Values.deployer` and everything under `.Values.platformValues` to the platform chart.
There is no other way for catalog values to reach the platform layer.

## App-of-apps pattern

Each bootstrap chart is an app-of-apps: it produces ArgoCD `Application` resources
(child apps), each pointing at a Helm chart in this repo. Every child Application is
gated by an `enabled` flag. If `enabled: false`, the template renders nothing (empty
output from `{{ if .Values.someWorkload.enabled }}...{{ end }}`).

Helm recurses into all subdirectories of `templates/`, so Application templates in
`templates/workloads_library/` are rendered exactly like those in `templates/` directly.
This is why the workloads library templates work without any special configuration.

## workloads_library/

Contains pre-built, maintained Helm charts for common operators and platform configs,
organized to mirror the cluster layer:

```
workloads_library/
├── infra/      ← operator charts (OLM Subscription + OperatorGroup)
└── platform/   ← configuration charts (CRs, patches, shared services)
```

Their ArgoCD Application templates live inside each bootstrap chart:
- `cluster/infra/bootstrap/templates/workloads_library/application-<name>.yaml`
- `cluster/platform/bootstrap/templates/workloads_library/application-<name>.yaml`

Each `git.path` in `values.yaml` points at the corresponding chart in `workloads_library/`.

Workloads that span both layers (e.g. kubevirt) require both the infra operator and
the platform CR chart to be enabled. The values.yaml comments in each bootstrap chart
call out which workloads are paired.

## Provision data

The deployer reads ConfigMaps with specific labels to surface data in RHDP:

- **Cluster-level:** label `demo.redhat.com/infra: "true"` on any ConfigMap
  → goes into provision_data for the cluster CI
- **Tenant-level:** label `demo.redhat.com/tenant-<GUID>: "true"` on any ConfigMap
  → goes into provision_data/user_data for the specific user's CI

The infra bootstrap creates `configmap-cluster-provisiondata` in `openshift-gitops`.
Tenant charts create their own ConfigMaps in tenant namespaces.

The Helm template for cluster provision data uses a nil-safe check for platformValues
because it can be `{}` (empty dict):
```yaml
{{- if and .Values.platformValues .Values.platformValues.myWorkload .Values.platformValues.myWorkload.enabled }}
```

## ArgoCD AppProjects

The infra bootstrap creates three AppProjects:
- `infra` — used by bootstrap-infra and all infra child Applications
- `platform` — used by bootstrap-platform and all platform child Applications
- `tenants` — used by all bootstrap-tenant-<GUID> Applications and their children

These must exist before tenant Applications can be created (infra bootstrap must run first).

## Key variable names in the Ansible role

```
ocp4_workload_gitops_bootstrap_repo_url        — git repo URL
ocp4_workload_gitops_bootstrap_repo_revision   — branch/tag/SHA
ocp4_workload_gitops_bootstrap_repo_path       — path within repo (e.g. cluster/infra/bootstrap)
ocp4_workload_gitops_bootstrap_application_name — ArgoCD Application name
ocp4_workload_gitops_bootstrap_application_project — ArgoCD project (default: "default")
ocp4_workload_gitops_bootstrap_helm_values     — dict merged with deployer.* and passed as helm.values
ocp4_workload_gitops_bootstrap_namespace       — namespace for the Application (default: openshift-gitops)
```

## Active CIs in agnosticv that use this repo

| CI path | repo_path | Layer |
|---------|-----------|-------|
| `agd_v2/ocp-gitops-example-infra` | `cluster/infra/bootstrap` | infra + platform |
| `agd_v2/ocp-gitops-example-tenant` | `tenant/bootstrap` | tenant |
| `tests/ex-multi-user-ocp-tenant` | `tenant/bootstrap` | tenant |
| `agd_v2/ai-qs-rag-cluster` | *(none set — kustomize fallback)* | infra |

## What to check when adding a new workload

1. Add the chart under `workloads_library/infra/<name>/` or `workloads_library/platform/<name>/`
2. Add an Application template in the corresponding `templates/workloads_library/application-<name>.yaml`
3. Add the values block in the bootstrap `values.yaml` with `enabled: false` and the correct `git.path`
4. Note whether it needs an infra+platform pair in both values.yaml comments
5. Add or update provision data in `configmap-cluster-provisiondata.yaml` if the workload
   produces a URL or credential that should surface in RHDP
6. Add a README to the workload chart directory with a TLDR catalog snippet

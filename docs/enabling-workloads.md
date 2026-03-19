# Enabling Workloads

## TLDR

Every workload has an `enabled: false` flag in its layer's `bootstrap/values.yaml`.
Set it to `true` from the catalog — you almost never need to change the repo.

```yaml
# In your AgnosticV cluster common.yaml:
ocp4_workload_gitops_bootstrap_helm_values:
  # Infra-layer flags go here directly:
  kubevirtOperator:
    enabled: true

  # Platform-layer flags go under platformValues:
  platformValues:
    kubevirt:
      enabled: true
```

Most workloads span both layers (operator + CR). Enable both or neither.

---

## The three layers

| Layer | Path | Managed by | ArgoCD Project |
|-------|------|-----------|----------------|
| infra | `cluster/infra/bootstrap/` | `ocp4_workload_gitops_bootstrap` (Ansible) | `infra` |
| platform | `cluster/platform/bootstrap/` | spawned by infra bootstrap | `platform` |
| tenant | `tenant/bootstrap/` | `ocp4_workload_gitops_bootstrap` (Ansible) | `tenants` |

The infra bootstrap spawns the platform bootstrap automatically. You do not run the
Ansible role twice — `platformValues` is a passthrough key that infra forwards verbatim
to the platform chart.

---

## Controlling workloads from the catalog

### Infra workloads

Set flags directly under `ocp4_workload_gitops_bootstrap_helm_values`:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  deschedulerOperator:
    enabled: true
  kubevirtOperator:
    enabled: true
```

### Platform workloads

Nest them under `platformValues`:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  platformValues:
    descheduler:
      enabled: true
    kubevirt:
      enabled: true
```

### Targeting a different branch or repo

Override `git` per workload (useful during development):

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  kubevirtOperator:
    enabled: true
    git:
      targetRevision: my-feature-branch
```

The `repoURL` and `targetRevision` keys in each workload's `git:` block inherit
from the `&git_defaults` anchor in `values.yaml` unless overridden.

---

## Workloads library

Optional workloads live in `workloads_library/infra/` and `workloads_library/platform/`.
Their ArgoCD Application templates are in `templates/workloads_library/` inside each
bootstrap chart. Helm recurses into subdirectories, so they behave identically to the
active workloads — same `enabled` flag pattern, same `git` override pattern.

See each workload's README under `workloads_library/infra/<name>/` or
`workloads_library/platform/<name>/` for workload-specific catalog snippets.

---

## Common sync options

All bootstrap Applications use these sync options (set in the Application templates,
not in values.yaml):

| Option | Why |
|--------|-----|
| `CreateNamespace=true` | Auto-creates operator namespaces |
| `SkipDryRunOnMissingResource=true` | CRDs don't exist until the operator installs — dry-run would fail |
| `RespectIgnoreDifferences=true` | Operators often mutate their own CR fields; this honors `ignoreDifferences` |
| Retry: 10 attempts, 5s × 2, max 3m | Absorbs timing gaps between operator install and CR creation |

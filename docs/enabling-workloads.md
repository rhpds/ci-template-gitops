# Enabling Workloads — Common Pattern

This document explains the shared pattern used by all workloads in this gitops repo. Each workload's own README covers workload-specific details and links back here for the common steps.

## Contents

- [Three-Layer System](#three-layer-system)
- [How Bootstrap Applications Work](#how-bootstrap-applications-work)
- [Enabling a Workload — Step by Step](#enabling-a-workload--step-by-step)
- [Common Sync Options](#common-sync-options)

## Three-Layer System

This repo uses three layers:

| Layer | Path | Purpose | ArgoCD Project |
|-------|------|---------|----------------|
| **infra** | `cluster/infra/` | Operator installation via OLM (Subscriptions, OperatorGroups) | `infra` |
| **platform** | `cluster/platform/` | Cluster-wide configuration that uses those operators (CRs, patches, StorageClasses) | `platform` |
| **tenant** | `tenant/` | Per-tenant/per-user resources | `tenants` |

Some workloads span two layers (e.g., descheduler, kubevirt), others are single-layer (e.g., webterminal is platform-only, gitlab is platform-only).

## How Bootstrap Applications Work

The deployer creates a `bootstrap-infra` ArgoCD Application pointing at `cluster/infra/bootstrap/`. This bootstrap chart contains templates that create **child Applications** — one per workload — each gated by an `enabled` flag.

The infra bootstrap also creates a `bootstrap-platform` Application pointing at `cluster/platform/bootstrap/`, which follows the same pattern for platform-layer workloads.

```
deployer
  └── bootstrap-infra (cluster/infra/bootstrap/)
        ├── descheduler-operator Application  ← gated by deschedulerOperator.enabled
        ├── kubevirt-operator Application     ← gated by kubevirtOperator.enabled
        ├── ...
        └── bootstrap-platform Application (cluster/platform/bootstrap/)
              ├── descheduler Application     ← gated by descheduler.enabled
              ├── kubevirt Application        ← gated by kubevirt.enabled
              ├── webterminal Application     ← gated by webterminal.enabled
              └── ...
```

## Enabling a Workload — Step by Step

### Step 1: Set the `enabled` flag(s) in the repo

Every workload has an entry in its layer's `bootstrap/values.yaml` that looks like this:

```yaml
# cluster/infra/bootstrap/values.yaml (for infra-layer workloads)
someOperator:
  enabled: false          # ← set to true
  git:
    path: cluster/infra/some-operator
    <<: *git_defaults     # inherits repoURL and targetRevision

# cluster/platform/bootstrap/values.yaml (for platform-layer workloads)
some:
  enabled: false          # ← set to true
  git:
    path: cluster/platform/some
    <<: *git_defaults
```

If a workload spans both layers (infra + platform), you must set **both** flags to `true`.

The `git` block (`repoURL`, `targetRevision`, `path`) has defaults via YAML anchors. You only need to override these if you're pointing at a different repo or branch.

### Step 2: Ensure your AgnosticV catalog is set up

Your **cluster-level** catalog item (e.g., `ocp4-getting-started-cluster/common.yaml`) must have the GitOps bootstrap workload in its workloads list and the repo configured. You almost certainly have this already if you're using this gitops repo:

```yaml
# --- These should already exist in your cluster catalog common.yaml ---

# The gitops bootstrap workload and its dependency:
workloads:
  # ... other workloads ...
  - agnosticd.core_workloads.ocp4_workload_openshift_gitops   # installs ArgoCD itself
  - agnosticd.core_workloads.ocp4_workload_gitops_bootstrap   # creates bootstrap-infra

# Points ArgoCD at your gitops repo:
ocp4_workload_gitops_bootstrap_repo_url: https://github.com/rhpds/ci-template-gitops.git
ocp4_workload_gitops_bootstrap_repo_revision: main
ocp4_workload_gitops_bootstrap_application_name: "bootstrap-infra"
```

### Step 3 (optional): Override values from the catalog

Infra bootstrap values can be overridden from the catalog via `ocp4_workload_gitops_bootstrap_helm_values`. This is useful if you want to enable/disable workloads per-environment without changing the repo:

```yaml
# In your cluster catalog common.yaml:
ocp4_workload_gitops_bootstrap_helm_values:
  someOperator:
    enabled: true
  # You can also override chart-level values like operator channel:
  # someOperator:
  #   git:
  #     targetRevision: some-branch
```

### Platform values via `platformValues` passthrough

Unlike sha-learns-ci-gitops, this repo supports overriding platform-layer values from the catalog. The `application-bootstrap-platform.yaml` template forwards both `deployer` values and anything set under `platformValues`:

```yaml
# In your cluster catalog common.yaml:
ocp4_workload_gitops_bootstrap_helm_values:
  platformValues:
    webterminal:
      enabled: true
    descheduler:
      enabled: true
```

This means both infra-layer and platform-layer `enabled` flags can be controlled from the catalog without changing the repo.

## Common Sync Options

All bootstrap Applications use these sync options:

| Option | Why |
|--------|-----|
| `CreateNamespace=true` | Auto-creates operator namespaces |
| `SkipDryRunOnMissingResource=true` | CRDs don't exist until the operator installs them — dry-run would fail without this |
| `RespectIgnoreDifferences=true` | Honors `ignoreDifferences` entries (operators often mutate CR fields) |
| Retry: 10 attempts, 5s backoff x2, max 3m | Handles timing dependencies between operator install and CR creation |

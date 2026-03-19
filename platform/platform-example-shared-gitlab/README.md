# Platform Example: Shared GitLab

## Overview

Example of a **platform-level shared resource** — a GitLab CE instance shared across all tenants. This is a copy of the [GitLab workload](../gitlab/README.md) configured as a platform example to demonstrate how cluster-wide services are deployed.

Deploys GitLab CE with PostgreSQL and Redis as plain Deployments (no operator). An init Job provisions users and creates groups with imported repositories.

> For background on the layer system, bootstrap chain, and common enable/disable pattern, see [docs/enabling-workloads.md](../../docs/enabling-workloads.md).

## File Inventory

The chart structure is identical to `platform/gitlab/` — see [GitLab README](../gitlab/README.md) for the full file inventory.

```
platform/platform-example-shared-gitlab/
├── Chart.yaml                               # "Example 1 — Platform shared resource"
├── values.yaml                              # Same structure as platform/gitlab/values.yaml
└── templates/                               # Same templates as platform/gitlab/

platform/bootstrap/templates/
└── application-platform-example-shared-gitlab.yaml  # ArgoCD Application, gated by platformExampleSharedGitlab.enabled
```

## How to Enable

| Flag | File | Default |
|------|------|---------|
| `platformExampleSharedGitlab.enabled` | `platform/bootstrap/values.yaml` | `false` |

The platform flag can be set from the catalog via `platformValues`:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  platformValues:
    platformExampleSharedGitlab:
      enabled: true
```

## Key differences from `platform/gitlab`

1. **Uses `project: platform`** — deployed into the `platform` ArgoCD project (not `default`).
2. **Has a destination namespace** — `platform-example-shared-gitlab` (unlike `platform/gitlab` which has none).
3. **Uses `.Values.platformExampleSharedGitlab.git.*`** — has proper `git:` defaults with `<<: *git_defaults` (unlike `platform/gitlab` which is missing them).
4. **Path is correct** — hardcoded to `platform/platform-example-shared-gitlab` (unlike `platform/gitlab` which uses just `gitlab`).

## Gotchas

See the [GitLab README](../gitlab/README.md) for all GitLab-specific gotchas (host override, placeholder keyBase, privileged containers, etc.). The only additional gotcha:

1. **This is an example workload.** It's provided as a starting point for platform-level shared services. For production use, customize the values (especially `gitlab.host`, `keyBase.*`, passwords) and consider renaming the chart.

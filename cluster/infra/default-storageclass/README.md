# Default StorageClass Workload

## Contents

- [Overview](#overview)
- [File Inventory](#file-inventory)
- [How to Enable](#how-to-enable)
- [Variables Reference](#variables-reference)
- [Gotchas](#gotchas)

## Overview

Ensures a default StorageClass exists on the cluster. Runs an idempotent Job at sync-wave `-50` (the earliest infra wave) that checks whether any StorageClass is already marked as default. If none is found, it patches the configured StorageClass to become the default. If a default already exists, it does nothing.

This is an **infra-only** workload — no platform or tenant components.

> For background on the layer system, bootstrap chain, and common enable/disable pattern, see [docs/enabling-workloads.md](../../../docs/enabling-workloads.md).

## File Inventory

```
cluster/infra/default-storageclass/
├── Chart.yaml
├── values.yaml                              # storageClassName
└── templates/
    └── job-default-storageclass.yaml        # ServiceAccount + ClusterRole + ClusterRoleBinding + Job (sync-wave -50)

cluster/infra/bootstrap/templates/
└── application-default-storageclass.yaml    # ArgoCD Application, gated by defaultStorageclass.enabled
```

## How to Enable

> Full explanation of the enable pattern and AgnosticV integration: [docs/enabling-workloads.md](../../../docs/enabling-workloads.md).

This is a single-layer workload — only one flag needed:

| Flag | File | Default |
|------|------|---------|
| `defaultStorageclass.enabled` | `cluster/infra/bootstrap/values.yaml` | **`true`** |

Note: unlike most workloads, this one defaults to **enabled**. It can be disabled by setting `defaultStorageclass.enabled: false`, or overridden from the catalog:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  defaultStorageclass:
    enabled: false
```

## Variables Reference

### Infra chart — `cluster/infra/default-storageclass/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `storageClassName` | `ocs-external-storagecluster-ceph-rbd` | StorageClass to make default (only if no default exists yet) |

## Gotchas

1. **Enabled by default.** This is the only workload in the repo that defaults to `enabled: true`. This ensures new clusters always get a default StorageClass.

2. **Runs at sync-wave `-50`.** This is the earliest wave in the repo, ensuring the default StorageClass is set before any other workload tries to create PVCs. Other infra operators start at wave `-20`.

3. **Uses `argocd.argoproj.io/hook: Sync` with `HookSucceeded` delete policy.** The Job is an ArgoCD Sync hook — it runs during each sync and is cleaned up after success. This is different from regular resources managed by ArgoCD.

4. **Idempotent — won't override an existing default.** If any StorageClass is already marked as default, the Job exits cleanly. It only patches when no default exists.

5. **Least-privilege RBAC.** Unlike most Jobs in this repo that use `cluster-admin`, this one creates a scoped `ClusterRole` with only `get`, `list`, and `patch` on `storageclasses`. The resources are created in `openshift-gitops` namespace (not `default`).

6. **The StorageClass must already exist.** The Job does not create the StorageClass — it only annotates an existing one. If `ocs-external-storagecluster-ceph-rbd` doesn't exist on the cluster, the Job will fail.

# Migration Toolkit for Containers (MTC) Workload

## Overview

Installs and configures the Migration Toolkit for Containers (MTC) operator, which enables migrating containerized workloads between OpenShift clusters or between namespaces within a cluster.

This workload spans **two layers**:
- **infra** (`infra/mtc-operator/`) — installs the MTC operator via OLM
- **platform** (`platform/mtc/`) — creates the `MigrationController` CR and an external Ceph StorageClass

> For background on the layer system, bootstrap chain, and common enable/disable pattern, see [docs/enabling-workloads.md](../../docs/enabling-workloads.md).

## File Inventory

### Infra layer — operator installation

```
infra/mtc-operator/
├── Chart.yaml
├── values.yaml                              # operator.channel, operator.installPlanApproval
└── templates/
    ├── operatorgroup.yaml                   # OperatorGroup in openshift-migration
    └── subscription.yaml                    # OLM Subscription

infra/bootstrap/templates/
└── application-mtc-operator.yaml            # ArgoCD Application, gated by mtcOperator.enabled
```

### Platform layer — operator configuration

```
platform/mtc/
├── Chart.yaml
├── values.yaml                              # mtc.replicas, guid
└── templates/
    ├── migrationcontroller-mtc.yaml         # MigrationController CR (sync-wave 3)
    └── storageclass-mtc.yaml                # External Ceph RBD StorageClass (not default)

platform/bootstrap/templates/
└── application-mtc.yaml                     # ArgoCD Application, gated by mtc.enabled
```

## How to Enable

> Full explanation of the enable pattern and AgnosticV integration: [docs/enabling-workloads.md](../../docs/enabling-workloads.md).

This workload requires **two** `enabled` flags (one per layer):

| Flag | File | Default |
|------|------|---------|
| `mtcOperator.enabled` | `infra/bootstrap/values.yaml` | `false` |
| `mtc.enabled` | `platform/bootstrap/values.yaml` | `false` |

Set both to `true`. Both flags can be set from the AgnosticV catalog:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  mtcOperator:
    enabled: true
  platformValues:
    mtc:
      enabled: true
```

## Variables Reference

### Infra chart — `infra/mtc-operator/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `operator.channel` | `release-v1.8` | OLM subscription channel |
| `operator.installPlanApproval` | `Automatic` | `Automatic` or `Manual` |

### Platform chart — `platform/mtc/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `mtc.replicas` | `1` | Not currently templated into any resource |
| `guid` | `xyzzy` | Cluster GUID, used as volume name prefix in StorageClass |

### MigrationController CR — hardcoded values

The following are set directly in `migrationcontroller-mtc.yaml` and are **not** configurable via values:

| Field | Value | Description |
|-------|-------|-------------|
| `migration_ui` | `true` | Enable the migration UI |
| `migration_controller` | `true` | Enable the migration controller |
| `migration_velero` | `true` | Enable Velero integration |
| `migration_log_reader` | `true` | Enable log reader |
| `olm_managed` | `true` | Operator managed via OLM |
| `cluster_name` | `host` | Name of this cluster in MTC |
| `restic_timeout` | `1h` | Timeout for Restic operations |
| `mig_namespace_limit` | `10` | Max namespaces per migration |
| `mig_pod_limit` | `100` | Max pods per migration |
| `mig_pv_limit` | `100` | Max persistent volumes per migration |

## Gotchas

1. **Two flags, two layers.** Enabling only infra installs the operator but creates no `MigrationController`. Enabling only platform creates a CR for an operator that isn't installed.

2. **External Ceph StorageClass.** The `storageclass-mtc.yaml` creates `custom-storage-class` with `volumeBindingMode: Immediate` (not `WaitForFirstConsumer` like the kubevirt StorageClass). It references external Ceph pool `ocpv-tenants` and uses the `guid` variable for volume name prefix. If you don't use external Ceph, remove or modify this template.

3. **The `guid` variable must be set.** The placeholder default `xyzzy` will produce volumes prefixed `openshift-cluster-xyzzy-`.

4. **No sync-wave on the StorageClass.** The `storageclass-mtc.yaml` has no sync-wave annotation, so it deploys at ArgoCD's default wave `0`. The `MigrationController` CR deploys at wave `3`.

5. **`mtc.replicas` is unused.** The value exists in `values.yaml` but is not referenced in any template.

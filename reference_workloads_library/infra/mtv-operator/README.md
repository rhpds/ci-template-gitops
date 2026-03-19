# Migration Toolkit for Virtualization (MTV) Workload

## Contents

- [Overview](#overview)
- [File Inventory](#file-inventory)
- [How to Enable](#how-to-enable)
- [Variables Reference](#variables-reference)
- [Gotchas](#gotchas)

## Overview

Installs and configures the Migration Toolkit for Virtualization (MTV / Forklift) operator, which enables migrating virtual machines from VMware, Red Hat Virtualization, or OpenStack to OpenShift Virtualization. **Requires** the [KubeVirt workload](../kubevirt-operator/README.md) to be installed first.

This workload spans **two layers**:
- **infra** (`cluster/infra/mtv-operator/`) — installs the MTV operator via OLM
- **platform** (`cluster/platform/mtv/`) — creates the `ForkliftController` CR and patches KubeVirt for decentralized live migration

> For background on the layer system, bootstrap chain, and common enable/disable pattern, see [docs/enabling-workloads.md](../../../docs/enabling-workloads.md).

## File Inventory

### Infra layer — operator installation

```
cluster/infra/mtv-operator/
├── Chart.yaml
├── values.yaml                              # operator.channel, operator.installPlanApproval
└── templates/
    ├── operatorgroup.yaml                   # OperatorGroup in openshift-mtv
    └── subscription.yaml                    # OLM Subscription

cluster/infra/bootstrap/templates/
└── application-mtv-operator.yaml            # ArgoCD Application, gated by mtvOperator.enabled
```

### Platform layer — operator configuration

```
cluster/platform/mtv/
├── Chart.yaml
├── values.yaml                              # mtv.replicas (unused)
└── templates/
    ├── forkliftcontroller-mtv.yaml          # ForkliftController CR (sync-wave 3)
    └── featuregate-patch-job.yaml           # Job that enables decentralized live migration on HyperConverged CR (sync-wave 4)

cluster/platform/bootstrap/templates/
└── application-mtv.yaml                     # ArgoCD Application, gated by mtv.enabled
```

## How to Enable

> Full explanation of the enable pattern and AgnosticV integration: [docs/enabling-workloads.md](../../../docs/enabling-workloads.md).

This workload requires **two** `enabled` flags (one per layer):

| Flag | File | Default |
|------|------|---------|
| `mtvOperator.enabled` | `cluster/infra/bootstrap/values.yaml` | `false` |
| `mtv.enabled` | `cluster/platform/bootstrap/values.yaml` | `false` |

Set both to `true`. Both flags can be set from the AgnosticV catalog:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  mtvOperator:
    enabled: true
  platformValues:
    mtv:
      enabled: true
```

## Variables Reference

### Infra chart — `cluster/infra/mtv-operator/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `operator.channel` | `release-v2.10` | OLM subscription channel |
| `operator.installPlanApproval` | `Automatic` | `Automatic` or `Manual` |

### Platform chart — `cluster/platform/mtv/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `mtv.replicas` | `1` | Not currently templated into any resource |

### ForkliftController CR — hardcoded values

The following are set directly in `forkliftcontroller-mtv.yaml` and are **not** configurable via values:

| Field | Value | Description |
|-------|-------|-------------|
| `controller_container_limits_memory` | `5Gi` | Memory limit for the controller |
| `feature_ui_plugin` | `"true"` | Enable the console UI plugin |
| `feature_validation` | `"true"` | Enable provider validation |
| `feature_volume_populator` | `"true"` | Enable volume populator for disk transfers |
| `feature_ocp_live_migration` | `"true"` | Enable live migration from OCP source |

## Gotchas

1. **Depends on KubeVirt.** MTV requires OpenShift Virtualization (KubeVirt) to be installed. The `featuregate-patch-job` patches the `HyperConverged` CR in `openshift-cnv` to enable `decentralizedLiveMigration`. If KubeVirt isn't installed, this Job will fail.

2. **Two flags, two layers.** Enabling only infra installs the operator but creates no `ForkliftController`. Enabling only platform creates a CR for an operator that isn't installed.

3. **Feature gate patch Job with `cluster-admin`.** The `featuregate-patch-job` (sync-wave 4) creates a ServiceAccount and ClusterRoleBinding with `cluster-admin` in the `default` namespace. It patches the KubeVirt `HyperConverged` CR to enable decentralized live migration. These RBAC resources persist after the Job completes.

4. **`mtv.replicas` is unused.** The value exists in `values.yaml` but is not referenced in any template.

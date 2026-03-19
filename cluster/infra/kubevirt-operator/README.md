# KubeVirt (OpenShift Virtualization) Workload

## Contents

- [Overview](#overview)
- [File Inventory](#file-inventory)
- [How to Enable](#how-to-enable)
- [Variables Reference](#variables-reference)
- [Gotchas](#gotchas)

## Overview

Installs and configures the OpenShift Virtualization (KubeVirt) operator. This enables running virtual machines alongside containers on OpenShift. The workload spans **two layers**:

- **infra** (`cluster/infra/kubevirt-operator/`) — installs the operator via OLM with Manual install plan approval, plus a Job to auto-approve the InstallPlan
- **platform** (`cluster/platform/kubevirt/`) — creates the `HyperConverged` CR, an external Ceph StorageClass, and a Job to patch storage settings for VM boot images

> For background on the layer system, bootstrap chain, and common enable/disable pattern, see [docs/enabling-workloads.md](../../../docs/enabling-workloads.md).

## File Inventory

### Infra layer — operator installation

```
cluster/infra/kubevirt-operator/
├── Chart.yaml
├── values.yaml                              # operator.channel, startingCSV, Manual approval
└── templates/
    ├── operatorgroup.yaml                   # OperatorGroup in openshift-cnv (sync-wave 3)
    ├── subscription.yaml                    # OLM Subscription with pinned CSV (sync-wave 3)
    └── installplan-approval-job.yaml        # SA + CRB + Job that approves InstallPlan (sync-wave 3)

cluster/infra/bootstrap/templates/
└── application-kubevirt-operator.yaml       # ArgoCD Application, gated by kubevirtOperator.enabled
```

### Platform layer — operator configuration

```
cluster/platform/kubevirt/
├── Chart.yaml
├── values.yaml                              # tolerations, external_ceph, guid
└── templates/
    ├── hyperconverged.yaml                  # HyperConverged CR in openshift-cnv (sync-wave 3)
    ├── storageclass.yaml                    # External Ceph RBD StorageClass (sync-wave 0)
    └── vm-datasource-job.yaml              # Job that patches StorageProfile + re-enables boot image import (sync-wave 4)

cluster/platform/bootstrap/templates/
└── application-kubevirt.yaml                # ArgoCD Application, gated by kubevirt.enabled
```

## How to Enable

> Full explanation of the enable pattern and AgnosticV integration: [docs/enabling-workloads.md](../../../docs/enabling-workloads.md).

This workload requires **two** `enabled` flags (one per layer):

| Flag | File | Default |
|------|------|---------|
| `kubevirtOperator.enabled` | `cluster/infra/bootstrap/values.yaml` | `false` |
| `kubevirt.enabled` | `cluster/platform/bootstrap/values.yaml` | `false` |

Set both to `true`. Both flags can be set from the AgnosticV catalog:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  kubevirtOperator:
    enabled: true
  platformValues:
    kubevirt:
      enabled: true
```

## Variables Reference

### Infra chart — `cluster/infra/kubevirt-operator/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `operator.channel` | `candidate` | OLM subscription channel |
| `operator.startingCSV` | `kubevirt-hyperconverged-operator.v4.20.3` | Pinned operator version |
| `operator.installPlanApproval` | `Manual` | `Manual` triggers the approval Job |

### Platform chart — `cluster/platform/kubevirt/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `ocp4_workload_openshift_virtualization_workload_tolerations` | `[]` | Node tolerations for VM workloads |
| `external_ceph` | `true` | When `true`, disables common boot image import in the CR |
| `guid` | `xyzzy` | Cluster GUID, used as volume name prefix in the StorageClass |

## Gotchas

1. **Manual InstallPlan approval pattern.** Unlike most workloads that use `Automatic` approval, KubeVirt uses `Manual` with a companion Job (`installplan-approval-job`) that patches the InstallPlan to approved. This pins the operator to a specific CSV version. The Job uses `cluster-admin` in the `default` namespace.

2. **`startingCSV` pins the version.** The default `kubevirt-hyperconverged-operator.v4.20.3` pins to a specific operator version. When upgrading, update this value.

3. **`ignoreDifferences` on `HyperConverged`.** The platform Application ignores diffs on `/spec/enableCommonBootImageImport` because the `vm-datastore-job` patches this field post-deploy.

4. **External Ceph StorageClass is hardcoded.** The `storageclass.yaml` creates `ocs-external-storagecluster-ceph-rbd` as the default StorageClass, configured for an external Ceph cluster. If you don't use external Ceph, remove or modify this template.

5. **The `guid` variable must be set.** Used as volume name prefix in the StorageClass. The default `xyzzy` is a placeholder.

6. **Two Jobs with `cluster-admin`.** Both the install plan approval Job (infra) and the VM datastore Job (platform) create ServiceAccounts with `cluster-admin` ClusterRoleBindings in the `default` namespace. These persist after the Jobs complete.

7. **Boot image import sequence.** The `HyperConverged` CR initially sets `enableCommonBootImageImport: false` (when `external_ceph: true`). Then at wave 4, the `vm-datastore-job` patches the StorageProfile and re-enables boot image import.

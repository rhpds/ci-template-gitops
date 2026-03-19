# Descheduler Operator Workload

## Contents

- [Overview](#overview)
- [File Inventory](#file-inventory)
- [How to Enable](#how-to-enable)
- [Variables Reference](#variables-reference)
- [Gotchas](#gotchas)

## Overview

Installs and configures the OpenShift Kube Descheduler Operator. The descheduler periodically rebalances pod placement across cluster nodes by evicting pods that violate scheduling constraints or cause resource imbalance. Particularly useful with KubeVirt for live-migrating VMs to less-loaded nodes.

This workload spans **two layers**:
- **infra** (`cluster/infra/descheduler-operator/`) — installs the operator via OLM
- **platform** (`cluster/platform/descheduler/`) — creates the `KubeDescheduler` CR and optional `MachineConfig`

> For background on the layer system, bootstrap chain, and common enable/disable pattern, see [docs/enabling-workloads.md](../../../docs/enabling-workloads.md).

## File Inventory

### Infra layer — operator installation

```
cluster/infra/descheduler-operator/
├── Chart.yaml
├── values.yaml                              # operator.channel, operator.installPlanApproval
└── templates/
    ├── operatorgroup.yaml                   # OperatorGroup in openshift-kube-descheduler-operator
    └── subscription.yaml                    # OLM Subscription (sync-wave 1)

cluster/infra/bootstrap/templates/
└── application-descheduler-operator.yaml    # ArgoCD Application, gated by deschedulerOperator.enabled
```

### Platform layer — operator configuration

```
cluster/platform/descheduler/
├── Chart.yaml
├── values.yaml                              # descheduler.enable_machineconfig
└── templates/
    ├── customresource-descheduler.yaml      # KubeDescheduler CR (sync-wave 3)
    └── machineconfig-descheduler.yaml       # PSI kernel arg MachineConfig (sync-wave -3), gated by descheduler.enable_machineconfig

cluster/platform/bootstrap/templates/
└── application-descheduler.yaml             # ArgoCD Application, gated by descheduler.enabled
```

## How to Enable

> Full explanation of the enable pattern and AgnosticV integration: [docs/enabling-workloads.md](../../../docs/enabling-workloads.md).

This workload requires **two** `enabled` flags (one per layer):

| Flag | File | Default |
|------|------|---------|
| `deschedulerOperator.enabled` | `cluster/infra/bootstrap/values.yaml` | `false` |
| `descheduler.enabled` | `cluster/platform/bootstrap/values.yaml` | `false` |

Set both to `true`. Both flags can be set from the AgnosticV catalog:

```yaml
# In your cluster catalog common.yaml:
ocp4_workload_gitops_bootstrap_helm_values:
  deschedulerOperator:
    enabled: true
  platformValues:
    descheduler:
      enabled: true
```

## Variables Reference

### Infra chart — `cluster/infra/descheduler-operator/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `operator.channel` | `stable` | OLM subscription channel |
| `operator.installPlanApproval` | `Automatic` | `Automatic` or `Manual` |

### Platform chart — `cluster/platform/descheduler/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `descheduler.replicas` | `1` | Not currently templated into any resource |
| `descheduler.enable_machineconfig` | `false` | Deploy the PSI kernel arg MachineConfig (see Gotchas) |

### KubeDescheduler CR — hardcoded values

The following are set directly in `customresource-descheduler.yaml` and are **not** configurable via values. To change them, edit the template:

| Field | Value | Description |
|-------|-------|-------------|
| `mode` | `Predictive` | Descheduling strategy |
| `profiles` | `[KubeVirtRelieveAndMigrate]` | Descheduler profile — designed for KubeVirt VM live migration |
| `deschedulingIntervalSeconds` | `3600` | How often the descheduler runs (1 hour) |
| `profileCustomizations.devEnableSoftTainter` | `true` | Enables soft tainting of nodes |
| `profileCustomizations.devDeviationThresholds` | `AsymmetricLow` | Threshold sensitivity |
| `profileCustomizations.devActualUtilizationProfile` | `PrometheusCPUCombined` | Uses Prometheus for actual CPU utilization |

## Gotchas

1. **Two flags, two layers.** Enabling only infra installs the operator but creates no CR. Enabling only platform creates a CR for an operator that isn't installed.

2. **`ignoreDifferences` on the platform Application.** The operator mutates `mode` and `deschedulingIntervalSeconds` on the CR after creation, so the Application is configured to ignore diffs on those fields.

3. **MachineConfig triggers node reboots.** Setting `descheduler.enable_machineconfig: true` deploys a MachineConfig that adds the `psi=1` kernel argument (Pressure Stall Information for CPU-aware descheduling). The MachineConfigOperator will **reboot worker nodes** to apply this.

4. **CR fields are not templatized.** To customize the descheduler profile, mode, or interval, edit `customresource-descheduler.yaml` directly or templatize the fields and add values.

5. **Sync-wave ordering.** Subscription at wave `1` (infra), MachineConfig at wave `-3` (platform), KubeDescheduler CR at wave `3` (platform). The CR must come after the operator is ready, which is handled by the separate infra → platform Application chain plus retry backoff.

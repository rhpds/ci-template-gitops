# Red Hat OpenShift AI (RHOAI) Workload

## Overview

Installs and configures Red Hat OpenShift AI (formerly RHODS), which provides a platform for data scientists and ML engineers to develop, train, and deploy machine learning models on OpenShift.

This workload spans **two layers**:
- **infra** (`cluster/infra/rhoai-operator/`) — installs the RHOAI operator via OLM, with `helper-status-checker` sub-chart to verify readiness
- **platform** (`cluster/platform/rhoai/`) — creates the `DSCInitialization` and `DataScienceCluster` CRs, with optional patcher Jobs

> For background on the layer system, bootstrap chain, and common enable/disable pattern, see [docs/enabling-workloads.md](../../../docs/enabling-workloads.md).

## File Inventory

### Infra layer — operator installation

```
cluster/infra/rhoai-operator/
├── Chart.yaml                               # Depends on helper-status-checker and tpl sub-charts
├── Chart.lock                               # Locked dependency versions
├── values.yaml                              # operator.*, helper-status-checker.*
└── templates/
    ├── namespace.yaml                       # Creates redhat-ods-operator namespace
    ├── operatorgroup.yaml                   # OperatorGroup (all-namespace mode)
    └── subscription.yaml                    # OLM Subscription

cluster/infra/bootstrap/templates/
└── application-rhoai-operator.yaml          # ArgoCD Application, gated by rhoaiOperator.enabled
```

### Platform layer — operator configuration

```
cluster/platform/rhoai/
├── Chart.yaml
├── values.yaml                              # dscinitialization.*, datasciencecluster.*, patcher.*
└── templates/
    ├── dscinitialization.yaml               # DSCInitialization CR (sync-wave 2), gated by dscinitialization.enabled AND dscinitialization.serviceMesh
    ├── datasciencecluster.yaml              # DataScienceCluster CR (sync-wave 3), gated by datasciencecluster.enabled
    └── patcher.yaml                         # PostSync hook Jobs: route creation + dashboard scaling, gated by patcher.enabled

cluster/platform/bootstrap/templates/
└── application-rhoai.yaml                   # ArgoCD Application, gated by rhoai.enabled (passes helm overrides)
```

## How to Enable

> Full explanation of the enable pattern and AgnosticV integration: [docs/enabling-workloads.md](../../../docs/enabling-workloads.md).

This workload requires **two** `enabled` flags (one per layer), plus inner gates for each CR:

| Flag | File | Default |
|------|------|---------|
| `rhoaiOperator.enabled` | `cluster/infra/bootstrap/values.yaml` | `false` |
| `rhoai.enabled` | `cluster/platform/bootstrap/values.yaml` | `false` |

Set both to `true`. Both flags can be set from the AgnosticV catalog:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  rhoaiOperator:
    enabled: true
  platformValues:
    rhoai:
      enabled: true
```

Additionally, inside the platform chart, each CR has its own gate:

| Inner gate | Default | What it creates |
|------------|---------|-----------------|
| `datasciencecluster.enabled` | `false` | DataScienceCluster CR |
| `dscinitialization.enabled` | `false` | DSCInitialization CR (also requires `dscinitialization.serviceMesh` to be set) |
| `patcher.enabled` | `false` | PostSync hook Jobs for route and dashboard |

## Variables Reference

### Infra chart — `cluster/infra/rhoai-operator/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `operator.name` | `rhods-operator` | Operator package name |
| `operator.namespace` | `redhat-ods-operator` | Namespace for the operator |
| `operator.channel` | `stable` | OLM channel |
| `operator.installPlanApproval` | `Automatic` | Install plan approval |
| `operator.source` | `redhat-operators` | CatalogSource |
| `operator.sourceNamespace` | `openshift-marketplace` | CatalogSource namespace |
| `operator.startingCSV` | unset | Pin to specific version |
| `helper-status-checker.enabled` | `true` | Run operator readiness check |
| `helper-status-checker.checks[0].operatorName` | `rhods-operator` | Operator to check |
| `helper-status-checker.checks[0].syncwave` | `"1"` | Sync-wave for checker |

### Platform chart — `cluster/platform/rhoai/values.yaml`

**DataScienceCluster:**

| Variable | Default | Description |
|----------|---------|-------------|
| `datasciencecluster.enabled` | `false` | Create the DataScienceCluster CR |
| `datasciencecluster.name` | `default-dsc` | CR name |
| `datasciencecluster.apiVersion` | `datasciencecluster.opendatahub.io/v1` | API version (bootstrap overrides to `v2`) |
| `datasciencecluster.components.*` | all `Removed` | Each component's `managementState` — all default to `Removed` |

Available components: `aipipelines`, `dashboard`, `feastoperator`, `kserve`, `kueue`, `llamastackoperator`, `modelregistry`, `ray`, `trainingoperator`, `trustyai`, `workbenches`.

**DSCInitialization:**

| Variable | Default | Description |
|----------|---------|-------------|
| `dscinitialization.enabled` | `false` | Create the DSCInitialization CR |
| `dscinitialization.name` | `default-dsci` | CR name |
| `dscinitialization.serviceMesh` | unset | Service Mesh config — template requires this to render |

**Patcher:**

| Variable | Default | Description |
|----------|---------|-------------|
| `patcher.enabled` | `false` | Run PostSync hook Jobs |
| `patcher.name` | `rhoai-patcher` | Job/SA/CRB name prefix |
| `patcher.namespace` | `redhat-ods-applications` | Namespace for patcher resources |
| `patcher.syncwave` | `"0"` | Sync-wave for patcher Jobs |
| `patcher.image` | `registry.redhat.io/openshift4/ose-cli` | Image for patcher containers |
| `patcher.route` | unset | When `true`, creates a Gateway route for KServe |
| `patcher.dashboard.replicas` | unset | When set, scales the RHODS dashboard deployment |

## Gotchas

1. **Two flags, two layers, plus inner gates.** The bootstrap `enabled` flags create the ArgoCD Applications. But the platform CRs also have their own `enabled` gates (`datasciencecluster.enabled`, `dscinitialization.enabled`, `patcher.enabled`). All default to `false`, so enabling the bootstrap alone creates an empty chart with no resources.

2. **Bootstrap overrides the API version.** The `application-rhoai.yaml` bootstrap template passes `datasciencecluster.apiVersion: datasciencecluster.opendatahub.io/v2` as a helm override, upgrading from the chart default `v1`. It also forces `patcher.dashboard.replicas: 1` and `patcher.route: true`.

3. **All DSC components default to `Removed`.** Every component in `datasciencecluster.components` defaults to `managementState: Removed`. You must explicitly set components to `Managed` to actually deploy any RHOAI functionality.

4. **DSCInitialization requires `serviceMesh`.** The template condition is `{{ if and .Values.dscinitialization.enabled .Values.dscinitialization.serviceMesh }}` — setting `enabled: true` alone is not enough. You must also provide the `serviceMesh` configuration block.

5. **Sub-chart dependencies.** The infra chart depends on `helper-status-checker` (~4.0.0) and `tpl` (~1.0.0) from `https://charts.stderr.at/`. If the external repo is unavailable, sync will fail.

6. **Patcher uses PostSync hooks.** The patcher Jobs use `argocd.argoproj.io/hook: PostSync` with `HookSucceeded` delete policy — they run after the main sync and are cleaned up on success. This is different from regular sync-wave-based Jobs.

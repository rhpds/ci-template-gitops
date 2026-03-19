# Node Health Check Workload

## Overview

Installs and configures the Node Health Check operator, which automatically detects unhealthy nodes and triggers remediation. This workload works together with the [Self Node Remediation operator](../self-node-remediation-operator/README.md), which provides the actual remediation mechanism (node fencing and restart). Both operators install into the same namespace (`openshift-workload-availability`).

This workload spans **three components**:
- **infra** (`cluster/infra/node-health-check-operator/`) — installs the Node Health Check operator via OLM
- **infra** (`cluster/infra/self-node-remediation-operator/`) — installs the Self Node Remediation operator via OLM (see [its README](../self-node-remediation-operator/README.md))
- **platform** (`cluster/platform/node-health-check/`) — runs a Job to enable the console plugin

> For background on the layer system, bootstrap chain, and common enable/disable pattern, see [docs/enabling-workloads.md](../../../docs/enabling-workloads.md).

## File Inventory

### Infra layer — operator installation

```
cluster/infra/node-health-check-operator/
├── Chart.yaml
├── values.yaml                              # operator.channel, operator.installPlanApproval
└── templates/
    ├── operatorgroup.yaml                   # OperatorGroup in openshift-workload-availability (no targetNamespaces — all-namespace mode)
    └── subscription.yaml                    # OLM Subscription

cluster/infra/bootstrap/templates/
└── application-node-health-check-operator.yaml  # ArgoCD Application, gated by nodeHealthCheckOperator.enabled
```

### Related: Self Node Remediation operator

```
cluster/infra/self-node-remediation-operator/
├── Chart.yaml
├── values.yaml                              # operator.channel, operator.installPlanApproval
└── templates/
    ├── operatorgroup.yaml                   # OperatorGroup in openshift-workload-availability (single-namespace mode)
    └── subscription.yaml                    # OLM Subscription

cluster/infra/bootstrap/templates/
└── application-self-node-remediation-operator.yaml  # gated by selfNodeRemediationOperator.enabled
```

### Platform layer — console plugin

```
cluster/platform/node-health-check/
├── Chart.yaml
├── values.yaml                              # empty (no configurable values)
└── templates/
    └── console-plugin-patch-job.yaml        # Job that adds node-remediation-console-plugin to OpenShift console (sync-wave 3)

cluster/platform/bootstrap/templates/
└── application-node-health-check.yaml       # ArgoCD Application, gated by nodeHealthCheck.enabled
```

## How to Enable

> Full explanation of the enable pattern and AgnosticV integration: [docs/enabling-workloads.md](../../../docs/enabling-workloads.md).

This workload requires **three** `enabled` flags:

| Flag | File | Default |
|------|------|---------|
| `nodeHealthCheckOperator.enabled` | `cluster/infra/bootstrap/values.yaml` | `false` |
| `selfNodeRemediationOperator.enabled` | `cluster/infra/bootstrap/values.yaml` | `false` |
| `nodeHealthCheck.enabled` | `cluster/platform/bootstrap/values.yaml` | `false` |

Set all three to `true`. All flags can be set from the AgnosticV catalog:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  nodeHealthCheckOperator:
    enabled: true
  selfNodeRemediationOperator:
    enabled: true
  platformValues:
    nodeHealthCheck:
      enabled: true
```

## Variables Reference

### Infra chart — `cluster/infra/node-health-check-operator/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `operator.channel` | `stable` | OLM subscription channel |
| `operator.installPlanApproval` | `Automatic` | `Automatic` or `Manual` |

### Infra chart — `cluster/infra/self-node-remediation-operator/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `operator.channel` | `stable` | OLM subscription channel |
| `operator.installPlanApproval` | `Automatic` | `Automatic` or `Manual` |

### Platform chart — `cluster/platform/node-health-check/values.yaml`

No configurable values. The chart only contains the console plugin patch Job.

## Gotchas

1. **Three operators, one platform.** You need both the Node Health Check operator AND the Self Node Remediation operator for the system to work. Node Health Check detects unhealthy nodes; Self Node Remediation performs the actual fencing. Without Self Node Remediation, detected issues won't be remediated.

2. **Shared namespace, different OperatorGroups.** Both operators install into `openshift-workload-availability`, but their OperatorGroups differ: Node Health Check uses all-namespace mode (no `targetNamespaces`), while Self Node Remediation uses single-namespace mode (`targetNamespaces: [openshift-workload-availability]`). Having two OperatorGroups in the same namespace can cause conflicts — in practice, whichever deploys first will be used.

3. **Console plugin patch is complex.** The `console-plugin-patch-job` uses a single-line Go template within a JSON patch to idempotently add `node-remediation-console-plugin` to the console operator's plugin list without removing existing plugins. The command is dense but safe to re-run.

4. **Job uses `cluster-admin`.** The console plugin patch Job creates a ServiceAccount and ClusterRoleBinding with `cluster-admin` in the `default` namespace. These persist after the Job completes.

5. **No `NodeHealthCheck` or `SelfNodeRemediation` CRs.** The platform chart only patches the console. It does not create `NodeHealthCheck` or `SelfNodeRemediation` custom resources — the operators create default instances automatically when installed.

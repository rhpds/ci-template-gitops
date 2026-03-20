# Self Node Remediation Operator Workload

## Contents

- [Overview](#overview)
- [File Inventory](#file-inventory)
- [How to Enable](#how-to-enable)
- [Variables Reference](#variables-reference)

## Overview

Installs the Self Node Remediation operator, which provides automatic node fencing and restart for unhealthy nodes. This operator is the **remediation backend** for the [Node Health Check operator](../node-health-check-operator/README.md) — it should always be enabled alongside it. Both operators install into the `openshift-workload-availability` namespace.

See the [Node Health Check README](../node-health-check-operator/README.md) for the full documentation covering both operators, including the platform layer, all enable flags, and gotchas.

> For background on the layer system, bootstrap chain, and common enable/disable pattern, see [docs/enabling-workloads.md](../../../docs/enabling-workloads.md).

## File Inventory

```
cluster/infra/self-node-remediation-operator/
├── Chart.yaml
├── values.yaml                              # operator.channel, operator.installPlanApproval
└── templates/
    ├── operatorgroup.yaml                   # OperatorGroup in openshift-workload-availability (single-namespace mode)
    └── subscription.yaml                    # OLM Subscription

cluster/infra/bootstrap/templates/
└── application-self-node-remediation-operator.yaml  # ArgoCD Application, gated by selfNodeRemediationOperator.enabled
```

## How to Enable

Set `selfNodeRemediationOperator.enabled: true` in `cluster/infra/bootstrap/values.yaml`. Also enable the companion [Node Health Check operator](../node-health-check-operator/README.md).

## Variables Reference

### Infra chart — `cluster/infra/self-node-remediation-operator/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `operator.channel` | `stable` | OLM subscription channel |
| `operator.installPlanApproval` | `Automatic` | `Automatic` or `Manual` |

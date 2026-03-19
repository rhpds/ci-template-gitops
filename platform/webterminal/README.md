# Web Terminal Workload

## Overview

Installs the OpenShift Web Terminal Operator, which adds an in-console terminal for running CLI commands directly from the OpenShift web console. This is a **platform-only** workload — the operator is installed via OLM directly in the platform layer (no separate infra chart).

Uses the `helper-status-checker` sub-chart from `charts.stderr.at` to verify operator readiness after installation.

> For background on the layer system, bootstrap chain, and common enable/disable pattern, see [docs/enabling-workloads.md](../../docs/enabling-workloads.md).

## File Inventory

```
platform/webterminal/
├── Chart.yaml                               # Declares sub-chart dependencies
├── Chart.lock                               # Locked dependency versions
├── values.yaml                              # Defaults for operator and status checker
├── .helmignore                              # Helm build ignore patterns
├── .gitignore                               # Ignores charts/ directory
├── application-webterminal.yaml             # Standalone reference Application (not used by bootstrap)
└── templates/
    └── operator.yaml                        # OLM Subscription (sync-wave from values, default -5)

platform/bootstrap/templates/
└── application-webterminal.yaml             # ArgoCD Application, gated by webterminal.enabled
```

## How to Enable

> Full explanation of the enable pattern and AgnosticV integration: [docs/enabling-workloads.md](../../docs/enabling-workloads.md).

Single-layer workload — one flag:

| Flag | File | Default |
|------|------|---------|
| `webterminal.enabled` | `platform/bootstrap/values.yaml` | `false` |

The platform flag can be set from the catalog via `platformValues`:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  platformValues:
    webterminal:
      enabled: true
```

## Variables Reference

### Platform chart — `platform/webterminal/values.yaml`

**Operator settings:**

| Variable | Default | Description |
|----------|---------|-------------|
| `operator.enabled` | `false` | Inner gate (see Gotchas — effectively unused) |
| `operator.name` | `web-terminal` | Operator package name |
| `operator.namespace` | `openshift-operators` | Install namespace |
| `operator.channel` | `fast` | OLM channel |
| `operator.installPlanApproval` | `Automatic` | Install plan approval |
| `operator.source` | `redhat-operators` | CatalogSource name |
| `operator.sourceNamespace` | `openshift-marketplace` | CatalogSource namespace |
| `operator.startingCSV` | unset | Pin to specific version |
| `operator.syncwave` | `-5` | Sync-wave for the Subscription |

**Status checker settings:**

| Variable | Default | Description |
|----------|---------|-------------|
| `helper-status-checker.enabled` | `true` | Run post-install readiness check |
| `helper-status-checker.approver` | `false` | Auto-approve InstallPlans |
| `helper-status-checker.checks[0].operatorName` | `web-terminal` | Operator to check |
| `helper-status-checker.checks[0].syncwave` | `"1"` | Sync-wave for the check Job |

## Gotchas

1. **Sub-chart dependencies.** Depends on `helper-status-checker` (~4.0.0) and `tpl` (~1.0.0) from `https://charts.stderr.at/`. If unavailable, sync will fail.

2. **`operator.enabled` is effectively unused.** The Subscription template checks `{{ if .Values.operator -}}` (map existence, always truthy) not `.Values.operator.enabled`.

3. **Bootstrap path is `webterminal`, not `platform/webterminal`.** The bootstrap Application template hardcodes `path: webterminal` instead of using `.Values.webterminal.git.path`.

4. **Two Application manifests.** `platform/webterminal/application-webterminal.yaml` is a standalone reference. The actual Application is `platform/bootstrap/templates/application-webterminal.yaml`.

5. **Bootstrap overrides `installPlanApproval`.** Always passes `Automatic` as a helm override (redundant with chart default).

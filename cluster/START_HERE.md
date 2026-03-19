# Cluster Layer — Start Here

The `cluster/` directory contains everything that runs at the cluster level — operators, cluster-wide configuration, and shared platform services. It is split into two sub-layers:

- **`infra/`** — Installs operators via OLM (Subscriptions, OperatorGroups)
- **`platform/`** — Configures those operators and deploys cluster-wide resources (CRs, patches, shared services)

This is **not** where per-user workloads live. That belongs in [`tenant/`](../tenant/START_HERE.md).

---

## Table of Contents

- [File Structure](#file-structure)
- [How It Works](#how-it-works)
- [The Bootstrap Chain](#the-bootstrap-chain)
- [Infra Layer](#infra-layer)
- [Platform Layer](#platform-layer)
- [Controlling Both Layers from the Catalog](#controlling-both-layers-from-the-catalog)
- [Provision Data — Passing Information Back to RHDP](#provision-data--passing-information-back-to-rhdp)
- [Reference Workloads Library](#reference-workloads-library)

---

## File Structure

```
cluster/
├── infra/
│   ├── bootstrap/                        # Infra bootstrap Helm chart (entry point)
│   │   ├── Chart.yaml
│   │   ├── values.yaml                   # All infra workload flags and git paths
│   │   └── templates/
│   │       ├── application-bootstrap-platform.yaml    # Spawns the platform layer
│   │       ├── application-default-storageclass.yaml  # Default StorageClass workload
│   │       ├── appproject-infra.yaml                  # ArgoCD AppProject: infra
│   │       ├── appproject-platform.yaml               # ArgoCD AppProject: platform
│   │       ├── appproject-tenants.yaml                # ArgoCD AppProject: tenants
│   │       ├── configmap-cluster-provisiondata.yaml   # Data passed back to RHDP
│   │       ├── job-cluster-provisiondata-secrets.yaml # Secret provisioning job
│   │       ├── keycloak/                              # Keycloak automation templates
│   │       └── reference_workloads_library/           # Templates for non-default workloads
│   └── default-storageclass/             # Default StorageClass chart (enabled by default)
│
└── platform/
    ├── bootstrap/                        # Platform bootstrap Helm chart
    │   ├── Chart.yaml
    │   ├── values.yaml                   # All platform workload flags and git paths
    │   └── templates/
    │       ├── application-platform-example-shared-gitlab.yaml  # Example shared service
    │       ├── application-openshift-oauth-account-operator.yaml
    │       └── reference_workloads_library/                     # Templates for non-default workloads
    └── platform-example-shared-gitlab/   # Example: GitLab shared across all tenants
```

---

## How It Works

The deployer runs the `ocp4_workload_gitops_bootstrap` Ansible role, which creates a single ArgoCD Application called `bootstrap-infra`. That Application points at [`cluster/infra/bootstrap/`](infra/bootstrap/) and renders it as a Helm chart.

The infra bootstrap chart does three things:

1. **Creates ArgoCD AppProjects** — `infra`, `platform`, and `tenants` (used by all three layers)
2. **Creates child Applications** for each enabled infra workload (e.g., `default-storageclass`)
3. **Spawns the platform layer** by creating the `bootstrap-platform` Application, which points at [`cluster/platform/bootstrap/`](platform/bootstrap/) and follows the same pattern for platform workloads

---

## The Bootstrap Chain

```
deployer (Ansible)
  └── bootstrap-infra (cluster/infra/bootstrap/)
        ├── AppProjects: infra, platform, tenants
        ├── default-storageclass Application       ← enabled by default
        ├── configmap-cluster-provisiondata        ← passes data back to RHDP
        └── bootstrap-platform (cluster/platform/bootstrap/)
              ├── platform-example-shared-gitlab Application  ← disabled by default
              └── openshift-oauth-account-operator Application
```

Every child Application is gated by an `enabled` flag in its layer's [`values.yaml`](infra/bootstrap/values.yaml). If the flag is `false`, the Application template renders nothing.

---

## Infra Layer

The infra layer installs operators. Each workload is a Helm chart containing an OLM Subscription and OperatorGroup.

**Active workloads** (in `cluster/infra/`):

| Workload | Values Key | Default | Purpose |
|----------|-----------|---------|---------|
| [`default-storageclass`](infra/default-storageclass/) | `defaultStorageclass` | **enabled** | Sets the default StorageClass |

The infra bootstrap also creates the three ArgoCD AppProjects (`infra`, `platform`, `tenants`) and the provision data ConfigMap.

**Values:** [`infra/bootstrap/values.yaml`](infra/bootstrap/values.yaml)

---

## Platform Layer

The platform layer configures operators and deploys cluster-wide shared services. Each workload is a Helm chart containing CRs, patches, or full application deployments.

**Active workloads** (in `cluster/platform/`):

| Workload | Values Key | Default | Purpose |
|----------|-----------|---------|---------|
| [`platform-example-shared-gitlab`](platform/platform-example-shared-gitlab/) | `platformExampleSharedGitlab` | disabled | Example: GitLab CE instance shared across all tenants |

**Values:** [`platform/bootstrap/values.yaml`](platform/bootstrap/values.yaml)

---

## Controlling Both Layers from the Catalog

Infra workloads are controlled directly via `ocp4_workload_gitops_bootstrap_helm_values`. Platform workloads use the `platformValues` passthrough — the infra bootstrap forwards these values to the platform bootstrap automatically.

```yaml
# In your AgnosticV cluster catalog common.yaml:
ocp4_workload_gitops_bootstrap_helm_values:
  # Infra-layer flags go here directly
  defaultStorageclass:
    enabled: true

  # Platform-layer flags go under platformValues
  platformValues:
    platformExampleSharedGitlab:
      enabled: true
```

Both layers controlled from one place. See [docs/enabling-workloads.md](../docs/enabling-workloads.md) for the full pattern.

---

## Provision Data — Passing Information Back to RHDP

The file [`infra/bootstrap/templates/configmap-cluster-provisiondata.yaml`](infra/bootstrap/templates/configmap-cluster-provisiondata.yaml) creates a ConfigMap labeled `demo.redhat.com/infra: "true"`. The deployer watches for this label and makes the key-value pairs available in RHDP.

To expose a new URL or value, add it under `provision_data:`:

```yaml
data:
  provision_data: |
    openshift_console_url: https://console-openshift-console.{{ .Values.deployer.domain }}
    my_custom_url: https://my-app.{{ .Values.deployer.domain }}
```

Conditional entries (only included when a workload is enabled) use a nil-safe Helm `if`:

```yaml
    {{- if and .Values.platformValues .Values.platformValues.myWorkload .Values.platformValues.myWorkload.enabled }}
    my_workload_url: https://my-workload.{{ .Values.deployer.domain }}
    {{- end }}
```

---

## Reference Workloads Library

Workloads that are not part of the default deployment have been moved to [`reference_workloads_library/`](../reference_workloads_library/) at the repo root. Their Application templates remain functional in `templates/reference_workloads_library/` subdirectories within each bootstrap chart — Helm recurses into subdirectories, so enabling one via `values.yaml` works exactly the same way. See the [reference library README](../reference_workloads_library/) for the full list.

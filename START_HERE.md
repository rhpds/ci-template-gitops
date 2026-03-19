# ci-template-gitops

A GitOps repo template for deploying labs and demos on OpenShift via ArgoCD.
Clone this repo, point your AgnosticV catalog at it, and everything your lab needs
is deployed and managed declaratively.

---

## TLDR

This repo has three independently-deployable layers. Each is an ArgoCD app-of-apps
Helm chart. The Ansible role `ocp4_workload_gitops_bootstrap` creates the entry-point
Application; everything else is spawned by ArgoCD from there.

| Layer | Entry point | What it deploys |
|-------|-------------|-----------------|
| **infra** | `cluster/infra/bootstrap/` | Operators via OLM |
| **platform** | `cluster/platform/bootstrap/` | CRs, shared services (spawned by infra) |
| **tenant** | `tenant/bootstrap/` | Per-user lab workloads |

**Catalog snippet — minimum to get started:**

```yaml
# Cluster-level: deploys infra + platform
ocp4_workload_gitops_bootstrap_repo_url: https://github.com/rhpds/ci-template-gitops.git
ocp4_workload_gitops_bootstrap_repo_revision: main
ocp4_workload_gitops_bootstrap_application_name: bootstrap-infra
ocp4_workload_gitops_bootstrap_repo_path: cluster/infra/bootstrap

# Tenant-level: deploys per-user workloads
ocp4_workload_gitops_bootstrap_repo_url: https://github.com/rhpds/ci-template-gitops.git
ocp4_workload_gitops_bootstrap_repo_revision: main
ocp4_workload_gitops_bootstrap_application_name: "bootstrap-{{ guid }}"
ocp4_workload_gitops_bootstrap_repo_path: tenant/bootstrap
ocp4_workload_gitops_bootstrap_application_project: tenants
```

---

## Where to go next

- **[cluster/START_HERE.md](cluster/START_HERE.md)** — Infra + platform layer: operators, shared services, provision data, enabling workloads from the catalog
- **[tenant/START_HERE.md](tenant/START_HERE.md)** — Tenant layer: three example deployment patterns with catalog snippets for each
- **[docs/enabling-workloads.md](docs/enabling-workloads.md)** — How the `enabled` flag, git paths, and `platformValues` passthrough work

---

## Repo layout

```
cluster/
├── infra/bootstrap/          # Infra entry point (operators)
├── infra/default-storageclass/
└── platform/bootstrap/       # Platform entry point (CRs, shared services)

tenant/
└── bootstrap/                # Tenant entry point (per-user workloads)

workloads_library/
├── infra/                    # Optional operators (all disabled by default)
└── platform/                 # Optional platform configs (all disabled by default)

docs/
├── enabling-workloads.md
└── release_notes.md
```

`workloads_library/` contains maintained, ready-to-use charts for common workloads
(KubeVirt, RHOAI, ODF, etc.). They are all disabled by default and enabled via the
catalog. See each workload's README for the exact catalog snippet.

# ci-template-gitops — Start Here

This repo is a GitOps template for deploying per-user lab environments on OpenShift using ArgoCD and the RHDP catalog system. It follows a three-layer architecture:

```
ci-template-gitops/
├── infra/        # Operator installation (Subscriptions, OLM)
├── platform/     # Cluster-wide resources that depend on those operators
└── tenant/       # Per-user workloads deployed once per provisioned user
```

Each layer is an independent ArgoCD bootstrap. The deployer creates:
- `bootstrap-infra` → points at `infra/bootstrap/`
- `bootstrap-platform` → points at `platform/bootstrap/`
- `bootstrap-tenant-<GUID>` → points at `tenant/bootstrap/`

The tenant layer is where the per-user lab workloads live. If you're here to understand how examples are structured or how to add your own workload, start with the tenant layer.

---

## Where to Go Next

**[tenant/START_HERE.md](tenant/START_HERE.md)** — Detailed walkthrough of the tenant layer, including:
- File structure overview
- How the bootstrap chart works
- Three example deployment patterns (inline resources, Helm chart, parameterized Helm chart)
- AgnosticV catalog snippets for each example

---

## Quick Reference

| Layer | ArgoCD App Name | Chart Path | Purpose |
|-------|----------------|------------|---------|
| Infra | `bootstrap-infra` | `infra/bootstrap/` | Operators (OLM subscriptions) |
| Platform | `bootstrap-platform` | `platform/bootstrap/` | Cluster resources (post-operator) |
| Tenant | `bootstrap-tenant-<GUID>` | `tenant/bootstrap/` | Per-user lab workloads |

All three examples in the tenant layer are **disabled by default**. The catalog must explicitly set `enabled: true` for each one via `ocp4_workload_gitops_bootstrap_helm_values`.

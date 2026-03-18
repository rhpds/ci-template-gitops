# ci-template-gitops — Start Here

#TODO: we will create the overview with everything is done

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
| Infra | `bootstrap-infra` | [`infra/bootstrap/`](infra/bootstrap/) | Operators (OLM subscriptions) |
| Platform | `bootstrap-platform` | [`platform/bootstrap/`](platform/bootstrap/) | Cluster resources (post-operator) |
| Tenant | `bootstrap-tenant-<GUID>` | [`tenant/bootstrap/`](tenant/bootstrap/) | Per-user lab workloads |

All three examples in the tenant layer are **disabled by default**. The catalog must explicitly set `enabled: true` for each one via `ocp4_workload_gitops_bootstrap_helm_values`.

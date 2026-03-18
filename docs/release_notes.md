# Release Notes

All changes from the original [ci-template-gitops](https://github.com/rhpds/ci-template-gitops) repo are tracked here.
Changes are surgical — any rename or structural change is reflected across all affected files.

---

## v0.1 — Baseline (2026-03-18)

- commit `582f480` 
    - Initial fork of `rhpds/ci-template-gitops` onto branch `Summit2026_Start_Here`; no functional changes from upstream.
    - Removed editor/IDE artifacts: `.claude/` (Claude Code settings), `.nvim.lua` (Neovim config), `CLAUDE.md` (AI assistant instructions).
    - Removed root-level `_tenant.tpl` (unreferenced Helm helper, no consumers found).
    - Removed ocpOps lab: `tenant/labs/ocpOps/` (chart with KubeVirt VM, stress workloads, and balance namespace resources), `tenant/bootstrap/templates/application-ocpops-lab.yaml`, and the `labs.ocpOps` block from `tenant/bootstrap/values.yaml`.
- [commit `6da78bd`] 
    - Renamed the three remaining example applications for clarity (all references updated across chart files, templates, values, and Application manifests):
        - `myotherapp-deployment.yaml` → `example1-inline-resource` (single manifest embedded directly in bootstrap)
        - `tenant/myapp/` + `application-myapp.yaml` → `tenant/example2-helm-basic/` + `application-example2-helm-basic.yaml` (ArgoCD Application pointing at a simple Helm chart)
        - `tenant/labs/hello-world/` + `application-hello-world.yaml` → `tenant/labs/example3-helm-parameterized/` + `application-example3-helm-parameterized.yaml` (full Helm chart with catalog-driven values)
- Removed all `scratch/` directories: `bootstrap/scratch/`, `infra/bootstrap/scratch/` (and nested `keycloak-realm/scratch/`); contained draft/reference material not deployed by any active template.

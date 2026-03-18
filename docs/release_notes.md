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
- commit `6da78bd`
    - Renamed the three remaining example applications for clarity (all references updated across chart files, templates, values, and Application manifests):
        - `myotherapp-deployment.yaml` → `example1-inline-resource` (single manifest embedded directly in bootstrap)
        - `tenant/myapp/` + `application-myapp.yaml` → `tenant/example2-helm-basic/` + `application-example2-helm-basic.yaml` (ArgoCD Application pointing at a simple Helm chart)
        - `tenant/labs/hello-world/` + `application-hello-world.yaml` → `tenant/labs/example3-helm-parameterized/` + `application-example3-helm-parameterized.yaml` (full Helm chart with catalog-driven values)
- commit `655d9f8`
    - Removed all `scratch/` directories: `bootstrap/scratch/`, `infra/bootstrap/scratch/` (and nested `keycloak-realm/scratch/`); contained draft/reference material not deployed by any active template.
- commit `ed49907`
    - Removed `tenant/CLAUDE.md` (AI assistant instructions) and `tenant/values-lab-hello-world.yaml` (orphaned values file unreachable by `Files.Get` from the bootstrap chart).
- commit `53e9ef1`
    - Renamed Application templates to lead with example number for clean sort order: `application-example2-helm-basic.yaml` → `example2-application-helm-basic.yaml`, `application-example3-helm-parameterized.yaml` → `example3-application-helm-parameterized.yaml`.
- commit `baeb247`
    - *REVIEW* Added explicit `enabled: false` default gate to example1 and example2 (previously always rendered unconditionally); all three examples now require `enabled: true` to be set explicitly in the catalog helm values.
- commit `23b75a9`
    - Added Service and Route to example2 (`tenant/example2-helm-basic/templates/service.yaml`, `route.yaml`). Route hostname: `example2-helm-basic-<tenant>.<domain>`.
- commit `79dee45`
    - Added Service and Route to example1; split into three files with `-pod`, `-service`, `-route` suffixes (`example1-inline-resource-pod.yaml`, `example1-inline-resource-service.yaml`, `example1-inline-resource-route.yaml`). All three share the same `enabled` gate.
- commit `43f6055`
    - Changed default namespace for example3 from `default` to `NAMESPACE-MUST-BE-SET-BY-CATALOG` to prevent silent misconfiguration; if the catalog omits the namespace, ArgoCD will now fail loudly instead of deploying to the wrong namespace.
- commit `4412140`
    - Added `START_HERE.md` at repo root: brief overview of the three-layer architecture (infra/platform/tenant) and pointer to the tenant doc.
    - Added `tenant/START_HERE.md`: full walkthrough of the tenant layer including file tree, bootstrap chart explanation, per-example sections (inline resources, Helm chart, parameterized Helm chart), and AgnosticV catalog snippets for each example.
- commit `5ec6f42`
    - Added GitHub-compatible table of contents to `tenant/START_HERE.md` (anchor links to each section).
    - Converted file name mentions in both `START_HERE.md` and `tenant/START_HERE.md` to relative GitHub links.
- commit `2e75dc7`
    - Simplified root `START_HERE.md` to a placeholder; removed architecture overview and Quick Reference table pending completion of all layers. TODO comment left for future full overview.

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
- commit `43f6055`
    - Changed default namespace for example3 from `default` to `NAMESPACE-MUST-BE-SET-BY-CATALOG` to prevent silent misconfiguration; if the catalog omits the namespace, ArgoCD will now fail loudly instead of deploying to the wrong namespace.

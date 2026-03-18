# Release Notes

All changes from the original [ci-template-gitops](https://github.com/rhpds/ci-template-gitops) repo are tracked here.
Changes are surgical — any rename or structural change is reflected across all affected files.

---

## v0.1 — Baseline (2026-03-18)

- Initial fork of `rhpds/ci-template-gitops` onto branch `Summit2026_Start_Here`; no functional changes from upstream.
- Removed editor/IDE artifacts: `.claude/` (Claude Code settings), `.nvim.lua` (Neovim config), `CLAUDE.md` (AI assistant instructions).
- Removed root-level `_tenant.tpl` (unreferenced Helm helper, no consumers found).
- Removed ocpOps lab: `tenant/labs/ocpOps/` (chart with KubeVirt VM, stress workloads, and balance namespace resources), `tenant/bootstrap/templates/application-ocpops-lab.yaml`, and the `labs.ocpOps` block from `tenant/bootstrap/values.yaml`.

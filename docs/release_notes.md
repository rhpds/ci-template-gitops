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

---

## v0.2 — Cluster/Infra/Platform layer (2026-03-18)

- commit `ac82af7`
    - Added `platformValues` passthrough in `infra/bootstrap`: catalog can now independently configure platform apps without infra needing to know about them.
- commit `a93de60`
    - Added `platform/example1-platform-shared-gitlab/` (copied from `platform/gitlab/`) and wired it into `platform/bootstrap` as a disabled-by-default example of a cluster-wide shared platform resource.
- commit `7c7bbb2`
    - Set destination namespace to `example1-platform-shared-gitlab` on the ArgoCD Application; previously unset so ArgoCD had no namespace to deploy into.

---

---

## v0.3 — Tenant fixes (2026-03-18)

- commit `48038f8`
    - *REVIEW* Fixed example3 ArgoCD Application `project` from `default` to `tenants`; was deploying outside the tenant AppProject scope.

- commit `4f99648`
    - Added note to `tenant/START_HERE.md` clarifying the distinction between ArgoCD project (`tenants`) and OpenShift namespace (`user-<GUID>-example*-lab`).
- commit `0ad0fb8`
    - Added warning in Example 1 section of `tenant/START_HERE.md`: inline resources must always set `namespace:` explicitly or they fall back to the Application's destination namespace.
- commit `dfc46ed`
    - Renamed `example1-platform-shared-gitlab` → `platform-example-shared-gitlab` across chart directory, Application template, values, and catalog (all references updated).

---

## v0.4 — Workload Documentation & Bootstrap Fixes (2026-03-18)

- commit `09f079a`
    - Added shared documentation `docs/enabling-workloads.md`: explains the three-layer system (infra/platform/tenant), bootstrap chain, how to enable/disable workloads, AgnosticV catalog integration, `platformValues` passthrough (platform flags overridable from catalog), and common ArgoCD sync options. All workload READMEs link here instead of duplicating this content.
    - Added 12 new workload READMEs (standardized format: Overview, File Inventory, How to Enable, Variables Reference, Gotchas):
        - `infra/descheduler-operator/README.md` — two-layer (infra+platform), KubeDescheduler CR + optional MachineConfig.
        - `infra/kubevirt-operator/README.md` — two-layer, Manual InstallPlan approval pattern, external Ceph StorageClass, VM boot image import.
        - `infra/mtc-operator/README.md` — two-layer, MigrationController CR + external Ceph StorageClass.
        - `infra/mtv-operator/README.md` — two-layer, ForkliftController CR + featuregate-patch-job, cross-references KubeVirt dependency.
        - `infra/node-health-check-operator/README.md` — three-component (NHC operator + SNR operator + platform console plugin), three enable flags.
        - `infra/self-node-remediation-operator/README.md` — brief companion README pointing to NHC doc.
        - `infra/rhoai-operator/README.md` — two-layer with inner gates, bootstrap overrides apiVersion to v2.
        - `infra/default-storageclass/README.md` — infra-only, enabled by default, sync-wave -50, Sync hook pattern.
        - `platform/gitlab/README.md` — platform-only, non-operator deployment (GitLab CE + PostgreSQL + Redis).
        - `platform/odf/README.md` — platform-only, patches Ceph RBD CSI Driver with node remediation tolerations.
        - `platform/platform-example-shared-gitlab/README.md` — example platform shared resource, documents differences from `platform/gitlab`.
    - Rewrote `platform/webterminal/README.md` — replaced generic placeholder with full standardized doc (sub-chart dependencies, operator.enabled gotcha, hardcoded path mismatch).
    - Rewrote `platform/rhoai/README.md` — replaced generic placeholder with one-line companion pointing to `infra/rhoai-operator/README.md`.
- commit `eacd234`
    - *FIX* `application-gitlab.yaml`: added missing `git:` defaults to `platform/bootstrap/values.yaml` (`repoURL` and `targetRevision` were empty when enabled); replaced hardcoded `path: gitlab` with `{{ .Values.gitlab.git.path }}` (was pointing at repo root instead of `platform/gitlab`).
    - *FIX* `application-webterminal.yaml`: replaced hardcoded `path: webterminal` with `{{ .Values.webterminal.git.path }}` (was pointing at repo root instead of `platform/webterminal`).
    - *FIX* `application-rhoai.yaml`: added missing `syncPolicy` block (automated sync, syncOptions, retry); was the only Application without one, requiring manual sync from ArgoCD UI.
    - *FIX* `application-openshift-oauth-account-operator.yaml`: changed `.Values.userOperator.*` references to `.Values.OAuthAccountOperator.*` (template referenced a key that didn't exist in values); removed `prune: true` (unique to this Application, inconsistent with all others); added `retry` block for consistency.

---

## To Discuss

- **Infra always deploys platform — catalog cannot opt out.** Currently `bootstrap-infra` unconditionally spawns `bootstrap-platform` (`platform.enabled: true` is baked into `infra/bootstrap/values.yaml`). The catalog has no way to deploy infra without platform, or platform without infra. Should the catalog be able to control each layer independently, or is "infra always brings platform" the intended contract?
- **AppProject for platform shared resources.** Platform apps (e.g. `platform-example-shared-gitlab`) use `project: platform`, which is created by `infra/bootstrap`. This works, but is `platform` the right project for cluster-wide shared resources that tenants may consume? Should there be a separate `shared` or `cluster-services` AppProject, or is `platform` the correct scope?


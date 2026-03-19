# Release Notes

All changes from the original [ci-template-gitops](https://github.com/rhpds/ci-template-gitops) repo are tracked here.
Changes are surgical — any rename or structural change is reflected across all affected files.

## Contents

- [v0.1 — Baseline](#v01--baseline-2026-03-18)
- [v0.2 — Cluster/Infra/Platform layer](#v02--clusterinfraplatform-layer-2026-03-18)
- [v0.3 — Tenant fixes](#v03--tenant-fixes-2026-03-18)
- [v0.4 — Workload Documentation & Bootstrap Fixes](#v04--workload-documentation--bootstrap-fixes-2026-03-18)
- [v0.5 — Directory Restructure](#v05--directory-restructure-2026-03-18)
- [v0.6 — Reference Workloads Library](#v06--reference-workloads-library-2026-03-19)
- [v0.7 — Rename to Workloads Library + Documentation Overhaul](#v07--rename-to-workloads-library--documentation-overhaul-2026-03-19)
- [To Discuss](#to-discuss)

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
- commit `06eb07f`
    - Removed now-fixed gotchas from workload READMEs: gitlab (hardcoded path, missing git defaults), webterminal (hardcoded path), rhoai (missing syncPolicy). Renumbered remaining gotchas.

---

## v0.5 — Directory Restructure (2026-03-18)

- commit `dbd3156`
    - Moved `infra/` and `platform/` directories under new `cluster/` directory (`git mv infra/ cluster/infra/`, `git mv platform/ cluster/platform/`).
    - Updated all `path:` values in `cluster/infra/bootstrap/values.yaml` (11 entries) to include `cluster/` prefix.
    - Fixed hardcoded `path: platform/bootstrap` in `cluster/infra/bootstrap/templates/application-bootstrap-platform.yaml` → `cluster/platform/bootstrap`.
    - Updated all `path:` values in `cluster/platform/bootstrap/values.yaml` (10 entries) to include `cluster/` prefix.
    - Updated AgnosticV catalog `summit-getting-started-cluster/common.yaml`: `ocp4_workload_gitops_bootstrap_repo_path: infra/bootstrap` → `cluster/infra/bootstrap`.
    - Updated `docs/enabling-workloads.md`: all path references, code examples, and ASCII tree now reflect `cluster/` prefix.
    - Updated `START_HERE.md`: Quick Reference table paths and links updated.
    - Updated `tenant/START_HERE.md`: prose reference to `infra/` and `platform/` updated.
    - Updated all 13 workload READMEs under `cluster/`: relative links to `docs/enabling-workloads.md` fixed (`../../` → `../../../`), all inline path references and file tree code blocks updated with `cluster/` prefix.
- commit `768d307`
    - Removed obsolete `tenant/bootstrap/templates/example1-inline-resource.yaml`; this file was superseded when Example 1 was split into three files (`example1-inline-resource-pod.yaml`, `-service.yaml`, `-route.yaml`) in commit `79dee45`.
- commit `d465450`
    - Removed `tools/keycloak-debugger.sh` (debug utility, not part of the gitops deployment).
    - Removed `architecture.png` (root-level image, not referenced by any document).
- commit `0527f2c`
    - Renamed `README.adoc` → `README.old.adoc`.
- commit `2d47235`
    - Added GitHub-compatible table of contents to all 16 documentation files: `START_HERE.md`, `docs/enabling-workloads.md`, `docs/release_notes.md`, `tenant/labs/example3-helm-parameterized/README.md`, and all 12 workload READMEs under `cluster/`.
- commit `a5701c1`
    - Removed `bootstrap/` (old top-level bootstrap chart with stale paths, unused by Summit2026_Start_Here).
    - Removed `README.old.adoc` (original upstream README).
    - Removed `cluster/platform/README.adoc` (Keycloak SSO docs with stale paths and references to deleted `tools/`).
    - Replaced `.gitignore` contents (was referencing unrelated repos) with standard patterns (`*.bak`, `*.tmp`, `*~`, `.DS_Store`).

---

## v0.6 — Reference Workloads Library (2026-03-19)

- commit `7773d5c`
    - Moved 16 unused workloads from `cluster/` to `reference_workloads_library/`, preserving `infra/` and `platform/` subdirectory structure:
        - **Infra** (7): `descheduler-operator`, `kubevirt-operator`, `mtc-operator`, `mtv-operator`, `node-health-check-operator`, `rhoai-operator`, `self-node-remediation-operator`
        - **Platform** (9): `descheduler`, `gitlab`, `kubevirt`, `mtc`, `mtv`, `node-health-check`, `odf`, `rhoai`, `webterminal`
    - Updated 7 `path:` entries in `cluster/infra/bootstrap/values.yaml` from `cluster/infra/<workload>` to `reference_workloads_library/infra/<workload>`.
    - Updated 9 `path:` entries in `cluster/platform/bootstrap/values.yaml` from `cluster/platform/<workload>` to `reference_workloads_library/platform/<workload>`.
    - Active workloads unchanged: `defaultStorageclass` (infra), `platform` bootstrap, `platformExampleSharedGitlab` (platform), keycloak entries (infra).
- commit `6c8a55a`
    - Reordered both `cluster/infra/bootstrap/values.yaml` and `cluster/platform/bootstrap/values.yaml`: active workloads first, reference library workloads last (alphabetized), separated by a `### These workloads are in the reference workloads library.` comment. No functional change.
- commit `0a05524`
    - Moved 7 infra and 9 platform Application templates for unused workloads into `templates/reference_workloads_library/` subdirectories. Helm recurses into subdirectories so behavior is unchanged; keeps active templates visually separate.
- commit `f9e9704`
    - Added "Passing Data Back to the Deployer" section to `tenant/START_HERE.md`: documents how to use `configmap-cluster-provisiondata.yaml` with the `demo.redhat.com/infra` label to surface data in RHDP.
- commit `0ee1dfd`
    - Added conditional `gitlab_url` entry to `configmap-cluster-provisiondata.yaml`: when `platformValues.platformExampleSharedGitlab.enabled` is true, the GitLab route URL is included in provision data. Uses nil-safe check for when `platformValues` is `{}`.

---

## v0.7 — Rename to Workloads Library + Documentation Overhaul (2026-03-19)

- Renamed `reference_workloads_library/` → `workloads_library/` throughout:
    - Root directory: `reference_workloads_library/` → `workloads_library/`
    - Template subdirectories: `cluster/infra/bootstrap/templates/reference_workloads_library/` → `workloads_library/`
    - Template subdirectories: `cluster/platform/bootstrap/templates/reference_workloads_library/` → `workloads_library/`
    - All `git.path` entries in `cluster/infra/bootstrap/values.yaml` and `cluster/platform/bootstrap/values.yaml` updated to match.
    - `cluster/infra/default-storageclass/` and `cluster/platform/platform-example-shared-gitlab/` paths unchanged (not part of the library).
- Rewrote all `values.yaml` files with heavy inline comments:
    - `cluster/infra/bootstrap/values.yaml` — documents the deployer injection, platformValues passthrough, and per-workload infra/platform pairs.
    - `cluster/platform/bootstrap/values.yaml` — documents how values reach this chart from infra, and per-workload operator dependencies.
    - `tenant/bootstrap/values.yaml` — documents the three example patterns, namespace requirements, and catalog usage.
- Rewrote all `START_HERE.md` and doc files: TLDR-first structure, trimmed prose, moved detail into inline comments.
- Added CLAUDE.md files at repo root, `cluster/`, and `tenant/` for AI-assisted development context.

---

## To Discuss and TODO

- **Infra always deploys platform — catalog cannot opt out.** Currently `bootstrap-infra` unconditionally spawns `bootstrap-platform` (`platform.enabled: true` is baked into `cluster/infra/bootstrap/values.yaml`). The catalog has no way to deploy infra without platform, or platform without infra. Should the catalog be able to control each layer independently, or is "infra always brings platform" the intended contract?
- **AppProject for platform shared resources.** Platform apps (e.g. `platform-example-shared-gitlab`) use `project: platform`, which is created by `cluster/infra/bootstrap`. This works, but is `platform` the right project for cluster-wide shared resources that tenants may consume? Should there be a separate `shared` or `cluster-services` AppProject, or is `platform` the correct scope?

- Discuss of we should move the non-default workloads outside of the repo (Better for versioning and avoiding drift, worse for complexity and troubleshooting)
- [ ] need to test deployment of the non-default workloads after they were moved. 
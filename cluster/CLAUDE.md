# CLAUDE.md — cluster/

This directory manages everything at the cluster level: operators (infra layer)
and their configuration plus shared services (platform layer).

## Two-chart structure

```
cluster/infra/bootstrap/    — entry point, created by Ansible role
cluster/platform/bootstrap/ — spawned by infra, never created directly by Ansible
```

The infra bootstrap Helm chart produces:
- Three ArgoCD AppProjects: `infra`, `platform`, `tenants`
- A `bootstrap-platform` ArgoCD Application (always, unless `platform.enabled: false`)
- Child Applications for each infra workload with `enabled: true`
- `infra-cluster-provisiondata` ConfigMap (always)
- `job-cluster-provisiondata-secrets` Job (always)

The platform bootstrap Helm chart produces:
- Child Applications for each platform workload with `enabled: true`

## How platform values reach the platform chart

The infra bootstrap template `application-bootstrap-platform.yaml` inlines the
following into the platform Application's `helm.values`:

```yaml
deployer:
  <forwarded from infra's .Values.deployer>
<everything from infra's .Values.platformValues, top-level>
```

So `platformValues.kubevirt.enabled: true` in the catalog becomes `kubevirt.enabled: true`
in the platform bootstrap chart. There is no other way for catalog values to reach platform.
The infra chart does not need to know the names of platform workloads — it forwards blindly.

## workloads_library relationship to bootstrap charts

Each workload in `workloads_library/` has a corresponding Application template in the
bootstrap chart's `templates/workloads_library/` subdirectory. The Application template
references the `git.path` from values.yaml to point ArgoCD at the workload chart.

```
values.yaml entry:
  kubevirtOperator:
    enabled: false
    git:
      path: workloads_library/infra/kubevirt-operator  ← ArgoCD source path

templates/workloads_library/application-kubevirt-operator.yaml:
  {{ if .Values.kubevirtOperator.enabled }}
  source:
    path: {{ .Values.kubevirtOperator.git.path }}      ← uses the value above
  {{ end }}
```

The chart in `workloads_library/infra/kubevirt-operator/` is a standalone Helm chart
with its own `Chart.yaml`, `values.yaml`, and `templates/`. ArgoCD deploys it as an
independent Application — not as a sub-chart of the bootstrap.

## Infra layer specifics

- All infra workloads install operators via OLM: a Subscription and OperatorGroup.
- `defaultStorageclass` is the only infra workload enabled by default.
- The `keycloak/` templates are opt-in automation for Keycloak; most labs use the
  Ansible-based `ocp4_workload_rhsso_*` roles instead.
- The `job-cluster-provisiondata-secrets.yaml` Job runs at deploy time to populate
  secrets from the cluster into ConfigMaps that the deployer reads.

## Platform layer specifics

- Platform workloads configure operators that infra installed. They must run after infra.
  ArgoCD's retry policy (10 retries, backoff) handles the timing gap.
- `platformExampleSharedGitlab` is the only explicitly-active platform workload example.
  Its chart lives at `cluster/platform/platform-example-shared-gitlab/` (not in workloads_library
  — it is the primary example, not a library workload).
- `OAuthAccountOperator` manages identity providers. Its `config.htpasswd.htpasswdSecret`
  must match a Secret that already exists in the cluster.

## Provision data ConfigMap

`infra/bootstrap/templates/configmap-cluster-provisiondata.yaml` — label: `demo.redhat.com/infra: "true"`

To add a new URL or value, add it under `provision_data: |`. Use `.Values.deployer.domain`
for the cluster's wildcard domain.

Conditional entries (only when a platform workload is enabled) require the nil-safe guard
because `platformValues` can be `{}`:
```yaml
{{- if and .Values.platformValues .Values.platformValues.myWorkload .Values.platformValues.myWorkload.enabled }}
my_url: https://my-workload.{{ .Values.deployer.domain }}
{{- end }}
```

Do not use `(.Values.platformValues).myWorkload` — Helm's `and` short-circuits safely.

## Adding a new workload to the infra layer

1. Create `workloads_library/infra/<name>/` with `Chart.yaml`, `values.yaml`, `templates/`
2. Create `cluster/infra/bootstrap/templates/workloads_library/application-<name>.yaml`
   following the pattern of existing Application templates in that directory
3. Add a values block in `cluster/infra/bootstrap/values.yaml` with `enabled: false`
   and a `git.path` pointing at `workloads_library/infra/<name>`
4. If the workload has a platform-layer companion, repeat for platform and note the pair
   in both values.yaml files

## Adding a new workload to the platform layer

Same as above, but:
1. Chart goes in `workloads_library/platform/<name>/`
2. Application template in `cluster/platform/bootstrap/templates/workloads_library/`
3. Values block in `cluster/platform/bootstrap/values.yaml`
4. Catalog enables it via `platformValues.<workloadKey>.enabled: true`

## Sync policy notes

All child Applications in both layers use:
- `automated.enabled: true` (sync automatically when ArgoCD detects drift)
- `CreateNamespace=true` (operator namespaces are created by ArgoCD)
- `SkipDryRunOnMissingResource=true` (required because CRDs appear after operator install)
- `RespectIgnoreDifferences=true` (operators mutate their own CRs; ArgoCD must not fight them)
- Retry: 10 attempts, 5s initial backoff × 2, max 3m

The retry policy is essential for platform workloads that depend on CRDs installed by
an infra workload. Without retries, ArgoCD would fail on the first sync.

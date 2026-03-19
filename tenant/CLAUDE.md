# CLAUDE.md — tenant/

This directory manages per-user lab workloads. Each provisioned user gets one
ArgoCD Application (`bootstrap-tenant-<GUID>`) pointing at `tenant/bootstrap/`.

## Key distinction: ArgoCD project vs. OpenShift namespace

- **ArgoCD project** (`project: tenants`) — cluster-wide ArgoCD concept that controls
  which Applications can deploy to which clusters/namespaces. The `tenants` AppProject
  is created by the infra bootstrap (cluster/infra/bootstrap/). It must exist before
  any tenant Application can be created — infra must run before tenant.
- **OpenShift namespace** — the actual K8s namespace where workload resources land.
  Created by the `ocp4_workload_tenant_namespace` Ansible workload before ArgoCD runs.
  Must already exist when ArgoCD syncs (tenant bootstrap uses `CreateNamespace=false`
  for inline resources).

## Three example patterns

### Pattern 1: Inline manifests (`example1InlineResource`)

Resources (Deployment, Service, Route) are rendered directly by the bootstrap chart.
No child ArgoCD Application. No sub-chart.

- Template files: `bootstrap/templates/example1-inline-resource-*.yaml`
- All three files share the same `{{ if .Values.example1InlineResource.enabled }}` gate.
- **Namespace must be explicit on every resource.** ArgoCD's Application destination
  namespace is `openshift-gitops` (where the bootstrap runs), not a tenant namespace.
  Any resource without an explicit `namespace:` field lands there.

### Pattern 2: Helm sub-chart (`example2HelmBasic`)

The bootstrap chart renders one ArgoCD `Application` resource pointing at
`tenant/example2-helm-basic/`. ArgoCD then deploys that chart as a separate Application.

- Bootstrap template: `bootstrap/templates/example2-application-helm-basic.yaml`
- Child chart: `tenant/example2-helm-basic/`
- Values threaded from bootstrap into child via inline `helm.values` in the Application spec.
  The bootstrap template explicitly passes `deployer`, `tenant`, and `example2HelmBasic`.
- The child chart has its own `values.yaml` with defaults. Catalog values override them
  via the inline helm.values block in the Application.

### Pattern 3: Parameterized Helm sub-chart (`labs.example3HelmParameterized`)

Same as Pattern 2 but every meaningful parameter (message, replicas, imageTag) is
explicitly threaded from the catalog → bootstrap chart → Application spec → child chart.

- Bootstrap template: `bootstrap/templates/example3-application-helm-parameterized.yaml`
- Child chart: `tenant/labs/example3-helm-parameterized/`
- `namespace` has no safe default (`NAMESPACE-MUST-BE-SET-BY-CATALOG`) intentionally.
  This causes a loud ArgoCD render failure rather than a silent wrong-namespace deploy.

## Values structure for nested keys

Example 3 is nested under `labs:` in values.yaml. In the catalog, this means:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  labs:
    example3HelmParameterized:
      enabled: true
```

This is purely an organizational choice — `labs` groups examples that represent
realistic lab patterns. There is no special Helm behavior for the nesting.

## How provision data works in the tenant layer

Tenant provision data uses a different ConfigMap label than cluster provision data:
- Label: `demo.redhat.com/tenant-<GUID>: "true"`
- The deployer merges all matching ConfigMaps for that tenant and adds the data to
  `agnosticd_user_info` for that specific user.
- ConfigMaps can live in any namespace — the label is what matters.

The `tenant/example2-helm-basic/templates/configmap-provisiondata.yaml` is the
reference implementation. It uses `tenant.name` for the GUID in the label.

Do not put tenant provision data in the cluster-level `configmap-cluster-provisiondata.yaml`.
That ConfigMap is labeled `demo.redhat.com/infra: "true"` and is read by the cluster CI,
not the per-user CI.

## Adding a new tenant workload

The recommended approach follows Pattern 2 or Pattern 3:

1. Create a Helm chart under `tenant/labs/<your-workload>/` with `Chart.yaml`,
   `values.yaml`, and `templates/`
2. Add an ArgoCD Application template to `tenant/bootstrap/templates/`
   (use `example2-application-helm-basic.yaml` as the model)
3. Add a values block to `tenant/bootstrap/values.yaml` with `enabled: false`,
   a `namespace:` placeholder that fails loudly, and `git.path` pointing at your chart
4. If the workload produces a URL or credential, add a
   `configmap-provisiondata.yaml` to the chart with the tenant label

For a minimal one-off resource (Pattern 1): add the manifest directly to
`tenant/bootstrap/templates/` gated by `{{ if .Values.myWorkload.enabled }}`.
Always set `namespace: {{ .Values.myWorkload.namespace }}` on every resource.

## Sync policy for tenant applications

The `bootstrap-tenant-<GUID>` Application (created by the Ansible role) uses:
- `automated.prune: false`, `automated.selfHeal: false` — conservative defaults
  for tenant Applications (the Ansible role sets these; they are not in this repo)

Child Applications created by the bootstrap chart (Examples 2 and 3) use:
- `automated.enabled: true`
- `CreateNamespace=true` — so ArgoCD can create the namespace if it doesn't exist yet
  (belt-and-suspenders; the namespace workload should have already created it)
- `SkipDryRunOnMissingResource=true`
- `RespectIgnoreDifferences=true`
- Retry: 10 attempts, 5s × 2, max 3m

## Tenant namespace naming convention

Namespaces follow the pattern: `<username>-<suffix>`, where username is typically
`user-<GUID>`. The `ocp4_workload_tenant_namespace` role creates them using:
```yaml
ocp4_workload_tenant_namespace_username: "user-{{ guid }}"
ocp4_workload_tenant_namespace_suffixes:
- suffix: myapp-lab
# → creates namespace: user-<GUID>-myapp-lab
```

The `namespace:` value in the catalog's `helm_values` block must match exactly.

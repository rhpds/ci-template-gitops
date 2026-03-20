# Cluster Layer

The `cluster/` directory manages everything that runs at the cluster level — operators,
cluster-wide configuration, and shared platform services. It is split into two sub-layers
that deploy in sequence: **infra** installs operators, **platform** configures them.

---

## TLDR

```yaml
# Enable an infra-layer operator from the catalog:
ocp4_workload_gitops_bootstrap_helm_values:
  kubevirtOperator:
    enabled: true

# Enable a platform-layer workload from the catalog:
ocp4_workload_gitops_bootstrap_helm_values:
  platformValues:
    kubevirt:
      enabled: true

# Enable both at once (required for most workloads):
ocp4_workload_gitops_bootstrap_helm_values:
  kubevirtOperator:
    enabled: true
  platformValues:
    kubevirt:
      enabled: true
```

All workload flags default to `false`. The `platformValues` key is a passthrough —
anything nested under it becomes a top-level value in `cluster/platform/bootstrap/`.

---

## How it works

```
Ansible role (ocp4_workload_gitops_bootstrap)
  └── bootstrap-infra  →  cluster/infra/bootstrap/
        ├── Creates AppProjects: infra, platform, tenants
        ├── Creates ConfigMap: infra-cluster-provisiondata (provision data back to RHDP)
        ├── default-storageclass Application       (enabled by default)
        └── bootstrap-platform  →  cluster/platform/bootstrap/
              ├── platformExampleSharedGitlab       (disabled by default)
              └── ... other platform workloads      (disabled by default)
```

The Ansible role only creates `bootstrap-infra`. ArgoCD then creates all child
Applications by rendering the infra bootstrap Helm chart. The platform bootstrap
is itself a child Application — infra always spawns it.

---

## File structure

```
cluster/
├── infra/
│   ├── bootstrap/
│   │   ├── values.yaml                   # All infra flags and git paths (heavily commented)
│   │   └── templates/
│   │       ├── application-bootstrap-platform.yaml    # Spawns the platform layer
│   │       ├── application-default-storageclass.yaml
│   │       ├── appproject-{infra,platform,tenants}.yaml
│   │       ├── configmap-cluster-provisiondata.yaml   # Provision data back to RHDP
│   │       ├── job-cluster-provisiondata-secrets.yaml
│   │       ├── keycloak/                              # Opt-in keycloak automation
│   │       └── workloads_library/                    # Templates for library workloads
│   └── default-storageclass/             # Sets the default StorageClass (enabled by default)
│
└── platform/
    ├── bootstrap/
    │   ├── values.yaml                   # All platform flags and git paths (heavily commented)
    │   └── templates/
    │       ├── application-platform-example-shared-gitlab.yaml
    │       ├── application-openshift-oauth-account-operator.yaml
    │       └── workloads_library/        # Templates for library workloads
    └── platform-example-shared-gitlab/  # Example: GitLab shared across all tenants
```

---

## Infra layer

Installs operators via OLM (Subscription + OperatorGroup). One Application per operator.

**Always-on workloads:**

| Workload | Purpose |
|----------|---------|
| `default-storageclass` | Sets the default StorageClass |

Everything else is in `workloads_library/infra/` and disabled by default.
See [`infra/bootstrap/values.yaml`](infra/bootstrap/values.yaml) for the full list and comments.

---

## Platform layer

Configures operators and deploys cluster-wide services. Runs after infra.

**Available workloads (all disabled by default):**

| Workload | Values key | Purpose |
|----------|-----------|---------|
| `platform-example-shared-gitlab` | `platformExampleSharedGitlab` | GitLab CE shared across tenants |
| `openshift-oauth-account-operator` | `OAuthAccountOperator` | HTPasswd/LDAP identity provider |

Everything else is in `workloads_library/platform/` and disabled by default.
See [`platform/bootstrap/values.yaml`](platform/bootstrap/values.yaml) for the full list.

---

## Provision data

[`infra/bootstrap/templates/configmap-cluster-provisiondata.yaml`](infra/bootstrap/templates/configmap-cluster-provisiondata.yaml)
creates a ConfigMap labeled `demo.redhat.com/infra: "true"`. The deployer watches for
this label and surfaces the key-value pairs in RHDP after deployment.

Add a value:

```yaml
data:
  provision_data: |
    openshift_console_url: https://console-openshift-console.{{ .Values.deployer.domain }}
    my_url: https://my-app.{{ .Values.deployer.domain }}
```

Conditionally (only when a workload is enabled):

```yaml
    {{- if and .Values.platformValues .Values.platformValues.myWorkload .Values.platformValues.myWorkload.enabled }}
    my_url: https://my-app.{{ .Values.deployer.domain }}
    {{- end }}
```

The nil-safe chained `and` is required because `platformValues` can be `{}`.

---

## Workloads library

Optional, maintained charts for common operators and their platform configs live in
[`workloads_library/`](../workloads_library/), mirroring the `infra/` and `platform/`
structure. Their ArgoCD Application templates live in `templates/workloads_library/`
inside each bootstrap chart — Helm recurses into subdirectories, so they behave
identically to active workloads.

Most workloads span both layers. Enable both or neither:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  kubevirtOperator:      # infra: installs the operator
    enabled: true
  platformValues:
    kubevirt:            # platform: creates the HyperConverged CR
      enabled: true
```

See [`docs/enabling-workloads.md`](../docs/enabling-workloads.md) for the full pattern.

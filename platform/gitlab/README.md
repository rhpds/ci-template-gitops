# GitLab Workload

## Overview

Deploys a self-hosted GitLab CE instance with PostgreSQL and Redis on OpenShift. This is a **platform-only** workload — no operator is installed; GitLab runs as plain Deployments. After deployment, an init Job runs an Ansible playbook that waits for GitLab to become healthy, creates a root API token, provisions users, and optionally creates groups with imported repositories.

> For background on the layer system, bootstrap chain, and common enable/disable pattern, see [docs/enabling-workloads.md](../../docs/enabling-workloads.md).

## File Inventory

```
platform/gitlab/
├── Chart.yaml                               # appVersion 12.5.7
├── values.yaml                              # All defaults (host, users, SMTP, DB creds)
└── templates/
    ├── sa-gitlab.yaml                       # ServiceAccount (sync-wave -2)
    ├── crb-gitlab-anyuid.yaml               # anyuid SCC (sync-wave -1)
    ├── crb-gitlab-privileged.yaml           # privileged SCC (sync-wave -1)
    ├── crb-gitlab-admin-ns.yaml             # admin in namespace (sync-wave -1)
    ├── cm-gitlab.yaml                       # GitLab env ConfigMap (sync-wave 0)
    ├── sct-gitlab.yaml                      # Secrets (sync-wave 0)
    ├── pvc-postgresql.yaml                  # 10Gi PVC (sync-wave 1)
    ├── pvc-redis.yaml                       # 10Gi PVC (sync-wave 1)
    ├── deploy-postgresql.yaml               # PostgreSQL Deployment (sync-wave 1)
    ├── deploy-redis.yaml                    # Redis Deployment (sync-wave 1)
    ├── svc-postgresql.yaml                  # PostgreSQL Service (sync-wave 1)
    ├── svc-redis.yaml                       # Redis Service (sync-wave 1)
    ├── pvc-gitlab.yaml                      # 10Gi PVC (sync-wave 2)
    ├── deploy-gitlab.yaml                   # GitLab Deployment (sync-wave 2)
    ├── svc-gitlab.yaml                      # GitLab Service (sync-wave 2)
    ├── rt-gitlab.yaml                       # OpenShift Route (sync-wave 2)
    ├── cm-gitlab-root-pat.yaml              # Root PAT script (sync-wave 1)
    ├── cm-gitlab-init.yaml                  # Ansible init playbook (sync-wave 3)
    └── job-gitlab-init.yaml                 # Init Job (sync-wave 3)

platform/bootstrap/templates/
└── application-gitlab.yaml                  # ArgoCD Application, gated by gitlab.enabled
```

## How to Enable

> Full explanation of the enable pattern and AgnosticV integration: [docs/enabling-workloads.md](../../docs/enabling-workloads.md).

Single-layer workload — one flag:

| Flag | File | Default |
|------|------|---------|
| `gitlab.enabled` | `platform/bootstrap/values.yaml` | `false` |

The platform flag can be set from the catalog via `platformValues`:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  platformValues:
    gitlab:
      enabled: true
```

## Variables Reference

### Platform chart — `platform/gitlab/values.yaml`

**GitLab settings:**

| Variable | Default | Description |
|----------|---------|-------------|
| `gitlab.image` | `quay.io/redhat-gpte/gitlab:16.0.4` | GitLab container image |
| `gitlab.host` | `gitlab-gitlab.apps.cluster-br9rv...` | GitLab FQDN — **must override** |
| `gitlab.https` | `"true"` | Whether GitLab uses HTTPS |
| `gitlab.rootPassword` | `openshift` | Root user password |
| `gitlab.rootEmail` | `treddy@redhat.com` | Root user email |
| `gitlab.keyBase.db` | `0123456789` | `GITLAB_SECRETS_DB_KEY_BASE` — **should override** |
| `gitlab.keyBase.otp` | `0123456789` | `GITLAB_SECRETS_OTP_KEY_BASE` — **should override** |
| `gitlab.keyBase.secret` | `0123456789` | `GITLAB_SECRETS_SECRET_KEY_BASE` — **should override** |
| `gitlab.users.base` | `user` | Username prefix |
| `gitlab.users.password` | `openshift` | Password for created users |
| `gitlab.users.count` | `2` | Number of users to create |
| `gitlab.groups` | `[]` | List of groups with repos to import |

**PostgreSQL settings:**

| Variable | Default | Description |
|----------|---------|-------------|
| `postgresql.dbUser` | `gitlab` | Database username |
| `postgresql.dbPassword` | `passw0rd` | Database password |
| `postgresql.dbName` | `gitlab_production` | Database name |

## Gotchas

1. **The Application path is hardcoded to `gitlab`.** The Application template has `path: gitlab` hardcoded, meaning ArgoCD looks for the chart at `<repoRoot>/gitlab`, not `platform/gitlab`. If your chart is at `platform/gitlab`, this will fail.

2. **Missing `git` defaults.** The `gitlab` entry in `platform/bootstrap/values.yaml` only has `enabled: false` — no `git:` block with `<<: *git_defaults`. The Application template references `.Values.gitlab.git.repoURL` which will be empty unless you add the defaults.

3. **`gitlab.host` must match your cluster.** The defaults are hardcoded to a specific sandbox cluster FQDN. Override to match your actual cluster's ingress domain.

4. **`keyBase` values are placeholder.** The defaults (`0123456789`) are insecure. Override for shared environments.

5. **Init Job waits 5 minutes, then polls.** The init Job first pauses 5 minutes, then polls the GitLab API. Expect 5–15 minutes for full initialization.

6. **Privileged containers.** GitLab, PostgreSQL, and Redis all run with `securityContext.privileged: true`.

7. **Vestigial `operator` helm values.** The Application template passes `operator.startingCSV` and `operator.installPlanApproval` as helm overrides, but GitLab has no operator — these values are unused.

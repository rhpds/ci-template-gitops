# ODF (OpenShift Data Foundation) Patches Workload

## Overview

Applies post-install patches to OpenShift Data Foundation's CSI driver. Specifically, it patches the Ceph RBD CSI driver to add tolerations for `node.kubernetes.io/out-of-service` and `medik8s.io/remediation` taints, which are applied by the [Node Health Check / Self Node Remediation](../../infra/node-health-check-operator/README.md) operators when fencing unhealthy nodes.

This is a **platform-only** workload — no infra layer (ODF itself is assumed to be already installed on the cluster).

> For background on the layer system, bootstrap chain, and common enable/disable pattern, see [docs/enabling-workloads.md](../../../docs/enabling-workloads.md).

## File Inventory

```
cluster/platform/odf/
├── Chart.yaml
├── values.yaml                              # tolerations, external_ceph (neither currently used in templates)
└── templates/
    └── csi-tolerations-job.yaml             # Job that patches the Ceph RBD CSI Driver with node remediation tolerations (sync-wave -4)

cluster/platform/bootstrap/templates/
└── application-odf.yaml                     # ArgoCD Application, gated by odf.enabled
```

## How to Enable

> Full explanation of the enable pattern and AgnosticV integration: [docs/enabling-workloads.md](../../../docs/enabling-workloads.md).

Single-layer workload — one flag:

| Flag | File | Default |
|------|------|---------|
| `odf.enabled` | `cluster/platform/bootstrap/values.yaml` | `false` |

The platform flag can be set from the catalog via `platformValues`:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  platformValues:
    odf:
      enabled: true
```

## Variables Reference

### Platform chart — `cluster/platform/odf/values.yaml`

| Variable | Default | Description |
|----------|---------|-------------|
| `ocp4_workload_openshift_virtualization_workload_tolerations` | `[]` | Not currently used in any template |
| `external_ceph` | `true` | Not currently used in any template |

Note: both values exist in `values.yaml` but are not referenced by any template. The CSI toleration patch is unconditional.

## Gotchas

1. **Depends on ODF being installed.** This chart does not install ODF — it only patches the existing CSI driver. If ODF/Ceph is not present, the Job will fail.

2. **Pairs with Node Health Check.** The tolerations this Job adds are for the taints applied by the Self Node Remediation operator. Enable this workload when you also enable NHC/SNR.

3. **Job uses `cluster-admin`.** Creates a ServiceAccount and ClusterRoleBinding with `cluster-admin` in the `default` namespace. Note the typo in resource names (`csi-tolersions-job`).

4. **Values are unused.** The `values.yaml` defines values but neither is referenced in the templates. The patch is always applied unconditionally.

5. **Runs at sync-wave `-4`.** Ensures CSI tolerations are set before VMs or other storage consumers are created.

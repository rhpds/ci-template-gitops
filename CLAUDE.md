# Three layer system

three layers:
/infra - operator installation (Subscriptions, OperatorGroups via OLM)
/platform - cluster-wide resources that USE those operators (CRs, patches, configurations)
/tenant - per-tenant resources

Secondary system called "deployer" creates bootstrap apps that are not present in this gitops repo:

APP NAME  | PATH
bootstrap-infra | /infra/bootstrap
bootstrap-tenant-GUID | /tenant/bootstrap

bootstrap-platform also deploys bootstrap-infra, if necessary

There's also an app named just 'bootstrap' that deploys all of the above.

# Variable Scoping

Variables and values must remained scoped to their layer - /infra/, /tenant/, /platform/

It is not guaranteed that /bootstrap/ app will be run, so settings necessary for other layers may not be defined there, or may not be defined there exclusivelyr.

# Sync-waves

Sync-waves are annotations on **resources**, never on Applications or ApplicationSets. Do not put sync-wave annotations in Application or ApplicationSet definitions.

The ArgoCD default sync-wave for un-annotated resources is `0`.

| Layer | Wave range | Purpose |
|-------|-----------|---------|
| infra | `-50` | Cluster-wide infra requirements (e.g. default StorageClass) |
| infra | `-20` | Operators, their namespaces and prerequisites |
| infra | `-10` | Operator Custom Resources |
| platform | `-10` | Custom resources unique to your lab |
| platform | `0` | ArgoCD default (un-annotated resources) |
| platform | `1` to `10` | Further resources and patches |
| tenant | `0` | ArgoCD default (un-annotated resources) |
| tenant | `1` to `100` | Per-tenant and per-user resources and patches |

Keycloak occupies `-20` to `-7` in infra so authentication infrastructure is ready before platform or tenant resources deploy.

Use `SkipDryRunOnMissingResource=true` on CRs whose CRDs are installed by an operator, since the CRD may not exist during dry-run.

# Data round trip

ConfigMaps in the `openshift-gitops` namespace pass data back to the deployer system. The label key encodes the layer and GUID:

- Tenant userdata: label `demo.redhat.com/tenant-<GUID>: "true"`
  - Name: `tenant-<GUID>-userdata-keycloak`
  - Empty ConfigMap created by: tenant bootstrap (tenant/bootstrap/templates/configmap-userdata.yaml)
  - Populated by: user-provisioner Job (infra/keycloak/keycloak-realm)
  - Cleaned up by: ArgoCD finalizer (automatic when tenant bootstrap app is deleted)

- Infra userdata: label `demo.redhat.com/infra: "true"`
  - Name: `infra-userdata-keycloak`
  - Created by: hub-provisioner Job (infra/keycloak/keycloak-resources)

Data format (YAML in the `provision_data` field):

```yaml
users:
  <username>:
    username: <username>@<realm>
```

All data is merged together by the deployer, non-destructively.

## infra/ charts
/keycloak/keycloak-infra
/keycloak/keycloak-resources
/keycloak/keycloak-realm (referenced by tenant bootstrap)
/kubevirt-operator
/mtc-operator
/mtv-operator
/node-health-check-operator
/self-node-remediation-operator
/rhoai-operator
/descheduler-operator

## platform/ charts
/descheduler
/gitlab
/kubevirt
/mtc
/mtv
/node-health-check
/odf
/rhoai
/webterminal



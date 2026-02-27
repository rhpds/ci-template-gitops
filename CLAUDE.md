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

# Data round trip

ConfigMaps in the `openshift-gitops` namespace pass data back to the deployer system. The label key encodes the layer and GUID:

- Tenant userdata: label `demo.redhat.com/tenant-<GUID>: "true"`
  - Name: `tenant-<realm>-userdata-keycloak`
  - Created by: user-provisioner Job (infra/keycloak-realm)
  - Cleaned up by: idp-and-realm-cleanup CronJob (infra/keycloak-resources)

- Infra userdata: label `demo.redhat.com/infra: "true"`
  - Name: `infra-userdata-keycloak`
  - Created by: hub-provisioner Job (infra/keycloak-resources)

Data format (YAML in the `provision_data` field):

```yaml
users:
  <realm-or-tenant-id>:
    accounts:
    - accountName: "<username>"
      accountPassword: "<password>"
```

All data is merged together by the deployer, non-destructively.

## infra/ charts
/keycloak-infra
/keycloak-resources
/keycloak-realm (referenced by tenant bootstrap)
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



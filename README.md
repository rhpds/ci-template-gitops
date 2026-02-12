# CI Template GitOps

NOTE: This replaces ocp-cluster-addons

A GitOps template repository for managing RHDP CI environments using Helm charts and ArgoCD ApplicationSets.

## Demonstrates use of our bootstrapping system

There are three major components to this system:

1. Platform (not implemented yet)
2. Infrastructure
3. Tenant
4. Bootstrap complete solution (to pre-deploy infra and all tenants. For an event, for example).

## Demonstrates three basic ways to deploy services

- Deploying an app via simple OpenShift/Kubernetes YAML Manifests
- Deploying Helm Charts that are local to the repository
- Deploying Helm Charts from an external repository

### Running the major components

* Running the helm chart `/bootstrap` will deploy *both* the cluster-wide shared services and tenant-specific resources.

* Running the helm chart `/platform/bootstrap` will set up the OCP cluster's preliminaries. FOR DEMO STAFF ONLY. NOT IMPLEMENTED YET.

* Running the helm chart `/infra/bootstrap` will set up all cluster-wide shared resources.

* Running the helm chart `/tenant/bootstrap` will set up tenant-specific resources for ONE tenant.

* Subsequent runs of the `/tenant/bootstrap` chart will create additional tenants.

NB: Deploying multiple tenants at once is not yet implemented. See bootstrap/scratch/applicationset-tenant.yaml

## Structure

- **`bootstrap/`** - Helm chart for initial environment setup and ArgoCD ApplicationSet generation
  - **`templates/applicationset-workspace.yaml`** - ApplicationSet that generates per-user workspace apps (in `scratch` for now)
- **`infra/bootstrap/`** - Helm chart to set up operators and other infrastructure resources
- **`infra/webterminal/`** - Helm chart to depoy the cluster-wide web terminal
- **`infra/<your helm chart>/`** - Your local helm charts to set resources shared by the tenant
- **`tenant/bootstrap/`** - Helm chart to deploy all tenant resources
- **`tenant/workspace/`** - Helm chart for workspace resources (namespaces, RBAC, etc.)
- **`tenant/<your helm chart>/`** - Your local helm charts for tenant-specific resources

## Usage with AgnosticV

1. Use `core_workloads.ocp4_workload_gitops_bootstrap` to bootstrap the GitOps environment
    1. Indicate the repo_url of your automation repo:
        ```
        ocp4_workload_gitops_bootstrap_repo_url: https://github.com/rhpds/ci-template-gitops.git
        ```
    1. Indicate the revision of your automation repo:
        ```
        ocp4_workload_gitops_bootstrap_repo_revision: gitops-example
        ```
    1. Indicate the name of the bootstrap application.  This will automatically set the path to the proper bootstrap chart.
       1. Possible values are
          1. "bootstrap" to deploy infra and tenant
          1. "bootstrap-infra" to deploy infra
          1. "bootstrap-tenant" to deploy tenant.  ArgoCD Application will be named `boostrap-tenant-GUID`
          ```
          ocp4_workload_gitops_bootstrap_application_name: "bootstrap-infra"
          ```
    1. Indicate appropriate helm values for the bootstrap chart you're addressing:
        ````
        ocp4_workload_gitops_bootstrap_helm_values:
          # For reference: The `deployer` variables are defined by the gitops_boostrap workload
          # deployer:
          #   domain: "{{ lookup('agnosticd_user_data', 'openshift_cluster_ingress_domain') }}"
          #   apiUrl: "{{ lookup('agnosticd_user_data', 'openshift_api_url') }}"
          user:
            count: "{{ user_count }}"
            prefix: "user"
          webterminal:
            #startingCSV: webterminal.v1.13.0
            git:
              repoURL: https://github.com/rhpds/ocp-cluster-addons.git
              targetRevision: v1.5.0
        ```

1. Configure user settings in `bootstrap/values.yaml`
2. Deploy the bootstrap chart to create ArgoCD ApplicationSets and Applications
3. ApplicationSets automatically deploy individual workspaces for each user

The bootstrap chart should generate workspace applications based on user count and prefix configuration, enabling multi-user CI environments.

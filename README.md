# CI Template GitOps

A GitOps template repository for managing RHDP CI environments using Helm charts and ArgoCD ApplicationSets.

## Demonstrates three basic ways to deploy services

- Deploying an app via simple OpenShift/Kubernetes YAML Manifests
- Deploying Helm Charts that are local to the repository
- Deploying Helm Charts from an external repository (https://github.com/rhpds/ocp-cluster-addons.git)

## Demonstrates use of our bootstrapping system

There are three major components to this system:

1. Platform (NOT IMPLEMENTED YET.)
2. Infrastructure
3. Tenant
4. Bootstrap complete solution

### Running the major components

* Running the helm chart `/platform/bootstrap` will set up the OCP cluster's preliminaries. FOR DEMO STAFF ONLY. NOT IMPLEMENTED YET.

* Running the helm chart `/infra/bootstrap` will set up all cluster-wide shared resources.

* Running the helm chart `/tenant/bootstrap` will set up tenant-specific resources for ONE tenant.

* Subsequent runs of the `/tenant/bootstrap` chart will create additional tenants.

* Running the helm chart `/bootstrap` will deploy *both* the cluster-wide shared services and tenant-specific resources.

NB: Deploying multiple tenants at once is not yet implemented.


## Structure

- **`bootstrap/`** - Helm chart for initial environment setup and ArgoCD ApplicationSet generation
  - **`templates/applicationset-workspace.yaml`** - ApplicationSet that generates per-user workspace apps
- **`tenant/bootstrap/`** - Helm chart to deploy all tenant resources
- **`tenant/workspace/`** - Helm chart for workspace resources (namespaces, RBAC, etc.)
- **`tenant/<your helm chart>/`** - Your local helm charts for tenant-specific resources
- **`infra/bootstrap/`** - Helm chart to set up operators and other infrastructure resources
- **`infra/<your helm chart>/`** - Your local helm charts to set resources shared by the tenant


- **`helm-extra-test-values.yml`** - Additional test configuration values

## Usage

1. Configure user settings in `bootstrap/values.yaml`
2. Deploy the bootstrap chart to create ArgoCD ApplicationSets and Applications
3. ApplicationSets automatically deploy individual workspaces for each user

The bootstrap chart generates workspace applications based on user count and prefix configuration, enabling multi-user CI environments.

## Sample Go Application

The bootstrap chart includes an Argo CD Application (`sample-go-app`) that deploys the [devfile-sample-go-basic](https://github.com/devfile-samples/devfile-sample-go-basic) app into the `sample-go-app` namespace. It uses the `deploy.yaml` from that repository, which creates a Deployment and Service for a Go HTTP server on port 8081.

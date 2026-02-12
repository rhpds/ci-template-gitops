# CI Template GitOps

A GitOps template repository for managing RHDP CI environments using Helm charts and ArgoCD ApplicationSets.

## Structure

- **`bootstrap/`** - Helm chart for initial environment setup and ArgoCD ApplicationSet generation
  - **`templates/applicationset-workspace.yaml`** - ApplicationSet that generates per-user workspace apps
  - **`templates/sample-go-app.yaml`** - Argo CD Application that deploys a sample Go application
- **`workspace/`** - Helm chart for individual user workspace resources
- **`helm-extra-test-values.yml`** - Additional test configuration values

## Usage

1. Configure user settings in `bootstrap/values.yaml`
2. Deploy the bootstrap chart to create ArgoCD ApplicationSets and Applications
3. ApplicationSets automatically deploy individual workspaces for each user

The bootstrap chart generates workspace applications based on user count and prefix configuration, enabling multi-user CI environments.

## Sample Go Application

The bootstrap chart includes an Argo CD Application (`sample-go-app`) that deploys the [devfile-sample-go-basic](https://github.com/devfile-samples/devfile-sample-go-basic) app into the `sample-go-app` namespace. It uses the `deploy.yaml` from that repository, which creates a Deployment and Service for a Go HTTP server on port 8081.

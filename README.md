# CI Template GitOps

A GitOps template repository for managing RHDP CI environments using Helm charts and ArgoCD ApplicationSets.

## Structure

- **`bootstrap/`** - Helm chart for initial environment setup and ArgoCD ApplicationSet generation
- **`workspace/`** - Helm chart for individual user workspace resources
- **`helm-extra-test-values.yml`** - Additional test configuration values

## Usage

1. Configure user settings in `bootstrap/values.yaml`
2. Deploy the bootstrap chart to create ArgoCD ApplicationSets
3. ApplicationSets automatically deploy individual workspaces for each user

The bootstrap chart generates workspace applications based on user count and prefix configuration, enabling multi-user CI environments.

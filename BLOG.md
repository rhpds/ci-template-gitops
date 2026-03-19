# Making GitOps Easier: Streamlining ci-template-gitops



The goal was simple: **make it easier for any developer on the team to adopt this repo and create new things with it**, without having to reverse-engineer how everything fits together.

Here's what changed.

## Cleaned up and simplified

We removed files that had accumulated over time but weren't actually used by any deployment — scratch directories, orphaned values files, stale debug scripts, unreferenced images, and editor config files. If it wasn't serving a purpose, it went.

We renamed the example applications from cryptic names like `myapp` and `myotherapp` to numbered examples that tell you exactly what pattern they demonstrate:

- **Example 1** — inline resources (Pod, Service, Route embedded right in the bootstrap chart)
- **Example 2** — a basic Helm chart deployed as its own ArgoCD Application
- **Example 3** — a fully parameterized Helm chart driven by catalog values

Each example now includes a Service and Route so you can actually hit it in a browser. Each one has an explicit `enabled: false` gate so nothing deploys unless you ask for it.

## Consistent patterns across all workloads

Previously, each workload had its own slightly different approach to things like enable/disable flags, path references, sync policies, and retry behavior. We audited every single ArgoCD Application template and fixed the inconsistencies:

- All workloads now use the same `enabled` gate pattern
- All Application templates use templatized paths from `values.yaml` (no more hardcoded paths that break when you change branches)
- All Applications have consistent sync policies and retry backoff
- Values keys actually match what the templates reference (we found a few that didn't!)

When you've seen how one workload is wired up, you've seen them all. That's the whole point.

## Three layers, one clear structure

The repo follows a three-layer architecture, and we made this explicit in both the directory layout and the documentation:

```
ci-template-gitops/
├── cluster/
│   ├── infra/       # Operators — OLM Subscriptions, OperatorGroups
│   └── platform/    # Cluster-wide resources that USE those operators
├── tenant/          # Per-user lab workloads
└── docs/            # Shared documentation
```

**Infra** installs operators. **Platform** configures them. **Tenant** gives each user their own sandbox. ArgoCD's bootstrap chain connects the layers automatically — the deployer creates `bootstrap-infra`, which spawns `bootstrap-platform`, and the catalog creates `bootstrap-tenant-<GUID>` for each user.

We moved `infra/` and `platform/` under a new `cluster/` directory to make this separation visible at the top level. Every path reference — in Helm values, ArgoCD templates, catalog configs, and documentation — was updated to match.

### Platform values passthrough

One feature worth calling out: the infra bootstrap now supports a `platformValues` passthrough. This means you can enable or disable platform-layer workloads directly from your AgnosticV catalog without touching the repo:

```yaml
ocp4_workload_gitops_bootstrap_helm_values:
  # Infra-layer flags go here directly
  deschedulerOperator:
    enabled: true
  # Platform-layer flags go under platformValues
  platformValues:
    descheduler:
      enabled: true
```

Both layers controlled from one place in your catalog.

## A working example deployment

To prove it all works together, we set up a minimal end-to-end example with `summit-getting-started-cluster` and `summit-getting-started-tenant` in the AgnosticV catalog. They deploy:

- **Infra**: default StorageClass configuration (the only workload enabled by default)
- **Platform**: a shared GitLab instance (`platform-example-shared-gitlab`) — demonstrates how cluster-wide services are deployed and made available to all tenants
- **Tenant**: the three example applications showing each deployment pattern

It's intentionally minimal. The idea is that you clone this setup, swap the examples for your actual lab content, and you're off to the races.

## Documented everything

Every workload now has a README following the same format: Overview, File Inventory, How to Enable, Variables Reference, and Gotchas. When a workload spans two layers (like most operators do — infra installs it, platform configures it), each README calls out the companion layer up front so you don't miss it.

There's a shared [docs/enabling-workloads.md](docs/enabling-workloads.md) that explains the common pattern once, and every workload README links to it. The [tenant/START_HERE.md](tenant/START_HERE.md) walks through each example with full catalog snippets you can copy-paste.

## Workload reference library

All workloads that aren't part of the default deployment have been moved to `reference_workloads_library/`, organized by layer (infra/platform). Their Application templates live in a `reference_workloads_library/` subfolder within each bootstrap's `templates/` directory. Everything still works — the `values.yaml` paths point to the new locations and Helm recurses into subdirectories — but the active directory tree is now clean and focused on what actually deploys.

## Built on great work

None of this would exist without the effort that went into the original repo. The operator charts, the bootstrap chain, the Keycloak integration, the ArgoCD patterns — all of that was already here and working. We just tidied it up, made it consistent, and wrote it down.

This was a team effort and it's been a great collaboration. We're excited to see what people build with it next.

## Next steps: 

- Final run through and QA in March 19th, 2026
- Release to RHDP developers, explaining to them that this is an exciting new step in our evolution and is bringing us closer to a more robust deployment method which will reduce our cost, toil and enable us to scale out to larger audiences. 

## Next next steps
- We will remove all non-used workloads either to a "workload-reference-library" folder or a separate repository, users will have an easy way to import/link to these workloads. Our library will grow over time. 
- Claude Skills and claud.md have been created and will be made available after further testing. 


---

*Branch: `Summit2026_Start_Here` — [full release notes](docs/release_notes.md)*

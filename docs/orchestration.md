Deployment Orchestration
===============================================================================

The MAS GitOps Helm Charts have been developed with the aim of simplifying the orchestration of MAS deployments (i.e. ensuring tasks and resources are applied in the proper sequence) as much as possible.

Once a **Target Cluster** has been provisioned and registered with the ArgoCD instance running in the **Management Cluster**, MAS instances can be deployed and managed on that **Target Cluster** solely by registering secrets in the **Secrets Vault** and pushing configuration files to the **Config Repo**.

- There is no need to run any commands against ArgoCD or the **Target Cluster** to initiate or control synchronization.
- To stand up MAS instances, all configuration files for a MAS cluster and its instances can be pushed at once to the **Config Repo** in a single commit .
- To deprovision MAS instances, all configuration files for the instance can be deleted at once from the **Config Repo** in a single commit.

!!! warning

    For automated deprovisioning of MAS instances to work as intended, ArgoCD version 2.11.0 or greater must be used. This is due to a [known issue](https://github.com/argoproj/argo-cd/issues/15074) in older versions of ArgoCD where resources were not being correctly pruned in reverse syncwave order. 

This is achieved using a combination of the following ArgoCD mechanisms:

  - [Automated Sync Policies](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/#automated-sync-policy)
  - [Sync Waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
  - [Resource Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/) that perform various tasks at the appropriate time
  - [Custom resource healthchecks](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/#custom-health-checks)



Automated Sync Policies
-------------------------------------------------------------------------------

All Applications defined in the MAS GitOps have the following sync policy defined:
```yaml
syncPolicy:
  automated:
    selfHeal: true
    prune: true
```

The ArgoCD Application Set git generators will automatically pick up configuration files pushed the the **Config Repo**. The resulting Applications will then be sychronized automatically due to the sync policy above. In addition:

- `selfHeal: true` will make ArgoCD undo any changes made manually to any cluster resources that it is managing. This ensures that proper...
- `prune: true` 

!!! info
  
    We may make `prune` configurable on a per-account basis in future releases. `prune: true` is useful in development systems as it allows MAS instances to be deprovisioned with no manual intervention. This may be too risky for use in production systems though and `prune: false` may be necessary; meaning a request must be made to ArgoCD after configuration files are deleted to explicitly perform a sync with pruning enabled.

Sync Waves
-------------------------------------------------------------------------------


Sync Waves
-------------------------------------------------------------------------------


Custom resource healthchecks
-------------------------------------------------------------------------------

This has been achieved using the ArgoCD [sync wave] mechanism combined with 

No connectivity is required


Once ArgoCD is installed and configured on the **Management Cluster**

- All configuration files for a MAS instance can be pushed to the **Config Repo** at the same time and ArgoCD will ensure that resources are created in **Target Clusters** in the correct order.
- No connectivity is required between 


To ensure that we sync resources in the correct order they are annotated with an  For clarity, we also prefix all resource filenames with the sync wave that they belong to. Note that sync waves are *local* to each ArgoCD application (i.e. each Helm chart).

> TODO: document the various use of ArgoCD hooks for creating secrets / running scripts / etc.

> TODO: we often don't use post-sync hooks - instead we use normal jobs that run last. These jobs often perform pre-requisite steps for subsequent sync waves (e.g. setting up secrets in the **Secrets Vault**) and having them as "normal" jobs ensures that ArgoCD will wait for their completion before allowing Applications in subsequent syncwaves to proceed.

> TODO: Document custom health checks, in particular the Application healthcheck required for the App of Apps pattern to work:  https://argo-cd.readthedocs.io/en/stable/operator-manual/health/#argocd-app


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
  - [Custom Resource Healthchecks](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/#custom-health-checks)
  - [Resource Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/) that perform various tasks at the appropriate time




Automated Sync Policies
-------------------------------------------------------------------------------

All Applications defined in the MAS GitOps have the following sync policy defined:
```yaml
syncPolicy:
  automated:
    selfHeal: true
    prune: true
```

The ArgoCD Application Set git generators will automatically pick up configuration files pushed the the **Config Repo**. The generated Applications will then be sychronized automatically due to the sync policy above. In addition:

- [`selfHeal: true`](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/#automatic-self-healing): causes ArgoCD to trigger a sync if changes are made to a ArgoCD-managed resource in the live cluster by something other than ArgoCD (e.g. a human operator). This forces any updates to MAS configuration to be made by pushing a commit to the **Config Repo**, ensuring that the configuration in the **Config Repo** is always the "source of truth". 
- [`prune: true`](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/#automatic-pruning): this allows ArgoCD to automatically deprovision MAS resources when their corresponding configuration files are deleted from the **Config Repo**.

!!! info
  
    We may make `prune` configurable on a per-account basis in future releases. `prune: true` is useful in development systems as it allows MAS instances to be deprovisioned with no manual intervention. This may be too risky for use in production systems though and `prune: false` may be necessary; meaning a request must be made to ArgoCD after configuration files are deleted to explicitly perform a sync with pruning enabled.

Sync Waves
-------------------------------------------------------------------------------

All Kubernetes resources defined in the MAS GitOps Helm charts are annotated with an ArgoCD [sync wave](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/). This ensures that all resources (including generated ArgoCD Applications on the **Management Cluster** and Kubernetes resources on **Target Cluster**s) are synced in the correct order; a resource is only permitted to being syncing once its dependencies are installed (and healthy).

!!! note

    For clarity, all resource filenames are prefixed with the sync wave that they belong to.

!!! note

    Sync waves are *local* to each ArgoCD application (i.e. each Helm chart).

Custom Resource Healthchecks
-------------------------------------------------------------------------------

MAS GitOps requires a set of [Custom resource healthchecks](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/#custom-health-checks) to be registered with the ArgoCD in the **Management Cluster**. This allows ArgoCD to properly interpret and report the health status of a given resource. This is particularly important to ensure that resources have finished reconciling before allowing subsequent sync waves (which may contain dependent resources) to proceed. The set of custom Resource Healthchecks required by MAS GitOps can be found in the [ibm-mas/cli project](https://github.com/ibm-mas/cli/blob/45cc815ec6244c9d58e050900ec0e27403d9ea92/image/cli/mascli/templates/gitops/bootstrap/argocd.yaml#L83).


Custom Resource Healthchecks
-------------------------------------------------------------------------------

> TODO: document the various use of ArgoCD hooks for creating secrets / running scripts / etc.

> TODO: we often don't use post-sync hooks - instead we use normal jobs that run last. These jobs often perform pre-requisite steps for subsequent sync waves (e.g. setting up secrets in the **Secrets Vault**) and having them as "normal" jobs ensures that ArgoCD will wait for their completion before allowing Applications in subsequent syncwaves to proceed.

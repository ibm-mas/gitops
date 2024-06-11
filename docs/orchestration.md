Deployment Orchestration
===============================================================================

The MAS GitOps Helm Charts have been developed with the aim of simplifying the orchestration of MAS deployments as much as possible. 
Once a **Target Cluster** has been provisioned and registered with the ArgoCD instance running in the **Management Cluster**, MAS instances can be deployed and managed on that **Target Cluster** solely by registering secrets in the **Secrets Vault** and pushing configuration files to the **Config Repo**. There is no need to run any commands against ArgoCD or the **Target Cluster** to initiate or control synchronization.

This is achieved using a combination of the following ArgoCD mechanisms:

  - [Automated Sync Policies](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/#automated-sync-policy)
  - [Sync Waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
  - [Custom Resource Healthchecks](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/#custom-health-checks)
  - [Resource Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/)


Automated Sync Policies
-------------------------------------------------------------------------------

The ArgoCD Application Set git generators poll the **Config Repo** every three minutes and will automatically pick up configuration files pushed the the **Config Repo**.

!!! tip

    If needed, ArgoCD can be configured to [receive webhook events](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/#webhook-configuration) to eliminate the inherent delay introduced by the default polling behaviour.

The resulting MAS GitOps Applications will be automatically synced as they have an automated sync policy:
```yaml
syncPolicy:
  automated:
    selfHeal: true
    prune: true
```
In addition:

- [`selfHeal: true`](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/#automatic-self-healing): causes ArgoCD to trigger a sync if changes are made to a ArgoCD-managed resource in the live cluster by something other than ArgoCD (e.g. a human operator). This forces any updates to MAS configuration to be made by pushing a commit to the **Config Repo**, ensuring that the configuration in the **Config Repo** is always the "source of truth". 
- [`prune: true`](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/#automatic-pruning): this allows ArgoCD to automatically deprovision MAS resources when their corresponding configuration files are deleted from the **Config Repo**.

!!! info
  
    We may make `prune` configurable on a per-account basis in future releases. `prune: true` is useful in development systems as it allows MAS instances to be deprovisioned with no manual intervention. This may be too risky for use in production systems though and `prune: false` may be necessary; meaning a request must be made to ArgoCD after configuration files are deleted to explicitly perform a sync with pruning enabled.

Sync Waves
-------------------------------------------------------------------------------

All Kubernetes resources defined in the MAS GitOps Helm Charts are annotated with an ArgoCD [sync wave](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/). This ensures that resources (including generated ArgoCD Applications on the **Management Cluster** and Kubernetes resources on **Target Cluster**s) are synced in the correct order.

!!! note

    For clarity, all resource filenames are prefixed with the sync wave that they belong to.

!!! note

    Sync waves are *local* to each ArgoCD application (i.e. each Helm chart).

Custom Resource Healthchecks
-------------------------------------------------------------------------------

MAS GitOps requires a set of [Custom Resource Healthchecks](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/#custom-health-checks) to be registered with the ArgoCD in the **Management Cluster**. 

This allows ArgoCD to properly interpret and report the health status of the various custom resources used by MAS. This is a crucial part of ensuring that resources have finished reconciling before allowing subsequent sync waves (which may contain dependent resources) to proceed.

The set of Custom Resource Healthchecks required by MAS GitOps can be found in the [ibm-mas/cli project](https://github.com/ibm-mas/cli/blob/45cc815ec6244c9d58e050900ec0e27403d9ea92/image/cli/mascli/templates/gitops/bootstrap/argocd.yaml#L83).


Resource Hooks
-------------------------------------------------------------------------------

Configuration tasks have to be performed at various points during the MAS synchronization procedure. We achieve this via the use of ArgoCD [Resource Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/).


#### PreSync Hooks
Tasks that must be performed **before** an Application begins syncing are defined as `PreSync` hooks. These are used, for example, to verify that cluster CRDs are present before proceeding with an installation (e.g. [00-presync-await-crd_Job](instance-applications/120-ibm-db2u-database/templates/00-presync-await-crd_Job.yaml)).


### "PostSync" Hooks
Tasks that must be performed **after** an Application finishes syncing (before **before** it can report `Healthy`) are performed by Kubernetes Jobs in the final sync wave of the Application.

Jobs of this kind typically perform some post-install configuration (e.g. [05-postsync-setup-db2_Job](instance-applications/120-ibm-db2u-database/templates/05-postsync-setup-db2_Job.yaml)) and/or register some runtime-generated information as a secret in the **Secrets Vault** for use by downstream applications (e.g. [08-postsync-update-sm_Job](cluster-applications/020-ibm-dro/templates/08-postsync-update-sm_Job.yaml)).


!!! info

    You may notice that we do not actually use the `PostSync` ArgoCD annotation on many of these Jobs. This is because the completion status of Jobs annotated as `PostSync` is not taken into account when computing the overall health status of an application. Since the tasks we perform are typically required steps that must be performed before downstream applications in later sync waves are allowed to sync, we instead use "ordinary" Kuberenetes Jobs. Since the health status of "ordinary" Kubernetes Jobs **is** taken into account, subsequent sync waves will not be allowed to start until the Job has completed successfully.



### PostDelete Hooks

Tasks that must be performed to ensure an orderly teardown of resources when configuration files are deleted from the **Config Repo**.  For example, Suite Config CRs (e.g. `MongoCfg`) cannot be pruned by ArgoCD since they are assigned the `Suite` as an owner during reconciliation. To work around this, we use PostDelete hooks to issue `oc delete` commands (e.g. [postdelete-delete-cr](instance-applications/130-ibm-mas-mongo-config/templates/postdelete-delete-cr.yaml])). 
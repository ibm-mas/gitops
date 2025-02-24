Deployment Orchestration
===============================================================================

The MAS GitOps Helm Charts have been developed with the aim of simplifying the orchestration of MAS deployments as much as possible. 
Once a {{ target_cluster() }} has been provisioned and registered with the ArgoCD instance running in the {{ management_cluster() }}, MAS instances can be deployed and managed on that {{ target_cluster() }} solely by registering secrets in the {{ secrets_vault() }} and pushing configuration files to the {{ config_repo() }}. There is no need to run any commands against ArgoCD or the {{ target_cluster() }} to initiate or control synchronization.

This is achieved using a combination of the following ArgoCD mechanisms:

  - [Automated Sync Policies](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/#automated-sync-policy)
  - [Sync Waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
  - [Custom Resource Healthchecks](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/#custom-health-checks)
  - [Resource Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/)


Automated Sync Policies
-------------------------------------------------------------------------------

The ArgoCD Application Set git generators poll the {{ config_repo() }} every three minutes and will automatically pick up configuration files pushed the the {{ config_repo() }}.

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

- [`selfHeal: true`](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/#automatic-self-healing): causes ArgoCD to trigger a sync if changes are made to a ArgoCD-managed resource in the live cluster by something other than ArgoCD (e.g. a human operator). This forces any updates to MAS configuration to be made by pushing a commit to the {{ config_repo() }}, ensuring that the configuration in the {{ config_repo() }} is always the "source of truth". 
- [`prune: true`](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/#automatic-pruning): this allows ArgoCD to automatically deprovision MAS resources when their corresponding configuration files are deleted from the {{ config_repo() }}.

!!! info
  
    We may make `prune` configurable on a per-account basis in future releases. `prune: true` is useful in development systems as it allows MAS instances to be deprovisioned with no manual intervention. This may be too risky for use in production systems though and `prune: false` may be necessary; meaning a request must be made to ArgoCD after configuration files are deleted to explicitly perform a sync with pruning enabled.

Sync Waves
-------------------------------------------------------------------------------

All Kubernetes resources defined in the MAS GitOps Helm Charts are annotated with an ArgoCD [sync wave](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/). This ensures that resources (including generated ArgoCD Applications on the {{ management_cluster() }} and Kubernetes resources on {{ target_cluster() }}s) are synced in the correct order.

!!! note

    For clarity, all resource filenames are prefixed with the sync wave that they belong to.

!!! note

    Sync waves are *local* to each ArgoCD application (i.e. each Helm chart).

Custom Resource Healthchecks
-------------------------------------------------------------------------------

MAS GitOps requires a set of [Custom Resource Healthchecks](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/#custom-health-checks) to be registered with the ArgoCD in the {{ management_cluster() }}. 

This allows ArgoCD to properly interpret and report the health status of the various custom resources used by MAS. This is a crucial part of ensuring that resources have finished reconciling before allowing subsequent sync waves (which may contain dependent resources) to proceed.

The set of Custom Resource Healthchecks required by MAS GitOps can be found in the [ibm-mas/cli project](https://github.com/ibm-mas/cli/blob/45cc815ec6244c9d58e050900ec0e27403d9ea92/image/cli/mascli/templates/gitops/bootstrap/argocd.yaml#L83).


Resource Hooks
-------------------------------------------------------------------------------

Configuration tasks have to be performed at various points during the MAS synchronization procedure. We achieve this via the use of Kubernetes Jobs (and supporting resources) annotated as ArgoCD [Resource Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/).


### PreSync Hooks
Jobs that must execute **before** an Application begins syncing are defined as `PreSync` hooks. These are used, for example, to verify that cluster CRDs are present before proceeding with an installation (e.g. {{ gitops_repo_file_link("instance-applications/120-ibm-db2u-database/templates/00-presync-await-crd_Job.yaml", "00-presync-await-crd_Job") }}).


### PostSync Hooks
Jobs that must be execute **after** an Application finishes syncing are defined as `PostSync` hooks. We make use of `PostSync` hooks only in limited cases where the Job is not performing a critical task that another Application in a later syncwave depends upon. This is because ArgoCD deliberately excludes hooks resources -- including `PostSync` hook Jobs -- from the health evaluation of the Application that owns it, meaning that sibling Applications in later syncwaves will be permitted to begin syncing regardless of the `PostSync` hook's completion status.

Where the task being performed *must* occur before Applications in later sync waves are permitted to begin syncing, we use "ordinary" Kubernetes Jobs (i.e. no `argocd.argoproj.io/hook` annotation) assigned to the final sync wave of the Application. When configured in this manner, the completion status of the Job *is* taken into account when evaluating the health of the Application it belongs to; and so will block synchronization of Applications in later sync waves until it completes successfully. Jobs of this kind typically perform post-install configuration (e.g. {{ gitops_repo_file_link("instance-applications/120-ibm-db2u-database/templates/05-postsync-setup-db2_Job.yaml", "05-postsync-setup-db2_Job") }}) and/or register some runtime-generated information as a secret in the {{ secrets_vault() }} for use by Applications in later sync waves (e.g. {{ gitops_repo_file_link("cluster-applications/020-ibm-dro/templates/08-postsync-update-sm_Job.yaml", "08-postsync-update-sm_Job") }}).

### PostDelete Hooks

Tasks that must be performed to ensure an orderly teardown of resources when configuration files are deleted from the {{ config_repo() }}.  For example, Suite Config CRs (e.g. `MongoCfg`) cannot be pruned by ArgoCD since they are assigned the `Suite` as an owner during reconciliation. To work around this, we use PostDelete hooks to issue `oc delete` commands (e.g. {{ gitops_repo_file_link("instance-applications/130-ibm-mas-mongo-config/templates/postdelete-delete-cr.yaml", "postdelete-delete-cr") }}). 


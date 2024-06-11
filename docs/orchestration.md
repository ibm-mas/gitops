Deployment Orchestration
===============================================================================

ArgoCD is solely responsible for ensuring that resources are created in **Target Clusters** in the correct order.

All configuration files can be pushed to the **Git Config** 

To ensure that we sync resources in the correct order they are annotated with an ArgoCD [sync wave](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/). For clarity, we also prefix all resource filenames with the sync wave that they belong to. Note that sync waves are *local* to each ArgoCD application (i.e. each Helm chart).

> TODO: document the various use of ArgoCD hooks for creating secrets / running scripts / etc.

> TODO: we often don't use post-sync hooks - instead we use normal jobs that run last. These jobs often perform pre-requisite steps for subsequent sync waves (e.g. setting up secrets in the **Secrets Vault**) and having them as "normal" jobs ensures that ArgoCD will wait for their completion before allowing Applications in subsequent syncwaves to proceed.

> TODO: Document custom health checks, in particular the Application healthcheck required for the App of Apps pattern to work:  https://argo-cd.readthedocs.io/en/stable/operator-manual/health/#argocd-app


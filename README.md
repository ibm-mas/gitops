# gitops
A GitOps approach to managing Maximo Application Suite



# Root application example

Register one of these applications per account to be managed by the ArgoCD worker:

> Replace the following:
>   - `<source-repo-url>`: The url of the source helm charts and argo apps. e.g. https://github.com/ibm-mas/gitops.
>   - `<source-repo-revision>`: The branch of `<source-repo-url>` to source charts from, e.g. `master`.
>   - `<config-repo>`: The github repo to source cluster/instance configuration from, e.g. `git@github.ibm.com:maximoappsuite/gitops-envs.git`.
>   - `<config-repo>-revision>`: The revision of `<config-repo>` to source cluster/instance configuration from, e.g. `master`.
>   - `<account-id>`: The ID of the account this root ap"plication manages. This also determines the root folder in `<config-repo>`:`<config-repo-revision` to source cluster/instance configuration from, e.g. `aws-dev`.
>   - `<argoapp-namespace>`: The namespace on cluster running ArgoCD in which to create ArgoCD Application resources. E.g. `openshift-gitops` (internal clusters), `argocd-worker` (MCSP)
>   - `<argo-project-rootapps>`: The ArgoCD project in which to create root applications (including this Application and the root applications that it generates). The project must be configured to permit creation of `argoproj.io.Application` and `argoproj.io.ApplicationSet` resources in the `<argoapp-namespace>` of the cluster in which ArgoCD is running (i.e. `https://kubernetes.default.svc`). In fvtsaas, this project is currently `mas`. In the MCSP dev worker, it is `mas-argoproj-resources`.
>   - `<argo-project-apps>`: The ArgoCD project in which to create the applications that deploy MAS resources (and their dependencies) to external MAS clusters. The project must be configured to permit creation of any resource in any namespace of all external MAS clusters targeted by this account. In fvtsaas, this project is currently `mas`. In the MCSP dev worker, it is also `mas`.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root.<account-id>
  namespace: <argoapp-namespace>
spec:
  destination:
    namespace: <argoapp-namespace>
    server: 'https://kubernetes.default.svc'
  project: "<argo-project-rootapps>"
  source:
    path: root-applications/ibm-mas-account-root
    repoURL: <source-repo-url>
    targetRevision: "<source-repo-revision>"
    helm:
      values: |
        {
          "account":{
            "id":"<account-id>"
          },
          "generator": {
            "repoURL": "<config-repo>",
            "revision": "<config-repo-branch>"
          },
          "source": {
            "targetRevision": "<source-repo-revision>",
            "repoURL": "<source-repo-url>"
          },
          "argoapp_namespace": "<argoapp-namespace>",
          "argo_project_rootapps": "<argo-project-rootapps>",
          "argo_project_apps": "<argo-project-apps>",

          "avp": {
            "name": "",
            "secret": "",
            "values_varname": ""
          }
        }
  syncPolicy:
    syncOptions:
      - CreateNamespace=false
```


The following figure shows a simplified view of how MAS Applications and ApplicationSets are laid out. For brevity this shows only a subset of the Applications in the `<argo-project-apps>` project and a single MAS cluster/instance:

![Simplified view of MAS Application layout in MCSP](docs/drawio/mcsp-argocd-mas-layout.png?raw=true "Simplified view of MAS Application layout in MCSP")

# Sync-Waves
To ensure that we sync resources in the correct order they are annotated with an ArgoCD [sync wave](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/). For clarity, we also prefix all resource filenames with the sync wave that they belong to. Note that sync waves are *local* to each ArgoCD application (i.e. each Helm chart).
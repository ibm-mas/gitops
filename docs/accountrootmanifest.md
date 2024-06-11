Account Root Application Manifest
===============================================================================

The **Account Root Application** is created directly on the cluster running ArgoCD. It serves as the "entrypoint" to the MAS Gitops code and is where several key pieces of global configuration values are provided.

### Template

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
          account:
            id: "<account-id>

          generator:
            repo_url: "<config-repo>"
            revision: "<config-repo-revision>"

          source:
            repo_url: "<source-repo-url>"
            revision: "<source-repo-revision>"
          
          argo:
            namespace: "<argo-namespace>"
            projects:
              rootapps: "<argo-project-rootapps>
              apps: "<argo-project-apps>"

          avp:
            name: "<avp-name>"
            secret: "<avp-secret>"
            values_varname: "<val-values-varname>"
    
  syncPolicy:
    syncOptions:
      - CreateNamespace=false
```

### Parameters
#### `<source-repo-url>`
The URL of the Git repository containing the MAS GitOps Helm Charts, e.g. https://github.com/ibm-mas/gitops.

#### `<source-repo-revision>`
The branch of `<source-repo-url>` to source the MAS GitOps Helm Charts from, e.g. `master`.

#### `<config-repo>`
The Git repository to source MAS cluster/instance configuration from

#### `<config-repo-revision>`
The revision of `<config-repo>` to source cluster/instance configuration from

#### `<account-id>`
The ID of the account this root application manages. This also determines the root folder in `<config-repo>`:`<config-repo-revision` to source cluster/instance configuration from, e.g. `dev`.

#### `<argo-namespace>`
The namespace on cluster running ArgoCD. E.g. `openshift-gitops`, `argocd-worker`. This determines where Application and ApplicationSet resources will be created. It will also be used to annotate namespaces created by our charts with [argocd.argoproj.io/managed-by](https://argocd-operator.readthedocs.io/en/stable/usage/deploy-to-different-namespaces/).

#### `<argo-project-rootapps>`
The ArgoCD project in which to create root applications (including this Application and the root applications that it generates). The project must be configured to permit creation of `argoproj.io.Application` and `argoproj.io.ApplicationSet` resources in the `<argoapp-namespace>` of the cluster in which ArgoCD is running (i.e. `https://kubernetes.default.svc`).

#### `<argo-project-apps>`
The ArgoCD project in which to create the applications that deploy MAS resources (and their dependencies) to external MAS clusters. The project must be configured to permit creation of any resource in any namespace of all external MAS clusters targeted by this account.

#### `<avp-name>`
The name assigned to the ArgoCD Vault Plugin used for retrieving secrets. Defaults to `argocd-vault-plugin-helm`.

#### `<avp-secret>`
The name of the k8s secret containing the credentials for accessing the vault that AVP is linked with. Defaults to the empty string, which implies that these credentials have been configured already in the cluster.

#### `<avp-values_varname>`
The name of the environment variable used to pass values inline to AVP. Defaults to `HELM_VALUES`.


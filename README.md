# gitops
A GitOps approach to managing Maximo Application Suite



# Root application example

Register one of these applications per account to be managed by the ArgoCD worker:

> Replace the following:
>   - `<source-repo-revision>`: The branch of https://github.com/ibm-mas/gitops to source charts from, e.g. `master`.
>   - `<config-repo>`: The github repo to source cluster/instance configuration from, e.g. `git@github.ibm.com:maximoappsuite/gitops-envs.git`.
>   - `<config-repo>-revision>`: The revision of `<config-repo>` to source cluster/instance configuration from, e.g. `master`.
>   - `<account-id>`: The ID of the account this root application manages. This also determines the root folder in `<config-repo>`:`<config-repo-revision` to source cluster/instance configuration from, e.g. `aws-dev`.
>   - `<argocd-project>`: The ArgoCD project to register this application in, e.g. `mas`.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root.<account-id>
  namespace: openshift-gitops
spec:
  destination:
    namespace: openshift-gitops
    server: 'https://kubernetes.default.svc'
  project: "<argocd-project>"
  source:
    path: root-applications/ibm-mas-account-root
    repoURL: 'https://github.com/ibm-mas/gitops'
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
            "targetRevision": "<source-repo-revision>"
          }
        }
  syncPolicy:
    syncOptions:
      - CreateNamespace=false
```
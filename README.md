# gitops
A GitOps approach to managing Maximo Application Suite



# Root application example

One per account that should be managed by the ArgoCD worker:

> replace `<accountid>` below

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root.<accountid>
  namespace: openshift-gitops
spec:
  destination:
    namespace: openshift-gitops
    server: 'https://kubernetes.default.svc'
  project: mas
  source:
    path: root-applications/ibm-mas-account-root
    repoURL: 'https://github.com/ibm-mas/gitops'
    targetRevision: master
    helm:
      values: |
        {
          "gitops": {"repoURL": "https://github.com/ibm-mas/gitops", "targetRevision":"master"},
          "account":{"id":"<accountid>"}
        }
  syncPolicy:
    syncOptions:
      - CreateNamespace=false
```
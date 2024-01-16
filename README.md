# gitops
A GitOps approach to managing Maximo Application Suite



# Root application example
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: openshift-gitops
spec:
  destination:
    namespace: openshift-gitops
    server: 'https://kubernetes.default.svc'
  project: mas
  source:
    path: root-applications/ibm-mas-account-root
    repoURL: 'https://github.com/ibm-mas/gitops'
    targetRevision: mascore1032v2
    helm:
      values: |
        {"account":{"id":"<accountid>"}}
  syncPolicy:
    syncOptions:
      - CreateNamespace=false
```
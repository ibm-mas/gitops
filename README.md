# gitops
A GitOps approach to managing Maximo Application Suite



# Root application example
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mas-root
  namespace: openshift-gitops
spec:
    project: mas-argoproj-resources
    source:
        repoURL: 'https://github.com/ibm-mas/gitops'
        path: application-sets
        targetRevision: mascore1032
    destination:
        server: 'https://kubernetes.default.svc'
        namespace: openshift-gitops
    syncPolicy:
        syncOptions:
            - CreateNamespace=false
```
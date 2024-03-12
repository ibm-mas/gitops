```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sync-test-root
  namespace: argocd
spec:
  destination:
    namespace: argocd
    server: 'https://kubernetes.default.svc'
  project: mas
  source:
    helm:
      values: |
        {}
    path: root-applications/sync-test-appofapps
    repoURL: 'https://github.com/ibm-mas/gitops'
    targetRevision: mascore1839
  syncPolicy:
    syncOptions:
      - CreateNamespace=false
```


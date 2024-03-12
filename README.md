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
>   - `<argoapp-namespace>`: The namespace on cluster running ArgoCD in which to create ArgoCD Application resources. E.g. `openshift-gitops` (internal clusters), `argocd-worker` (MCSP)

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
          },
          "argoapp_namespace": "<argoapp-namespace>"
        }
  syncPolicy:
    syncOptions:
      - CreateNamespace=false
```

# Sync-Waves

Sync-waves are used in the ArgoCD Application and ApplicationSets to ensure that the correct order of syncing occurs to deploy MAS and any MAS Apps. Each root applications has the sync-wave starting range defined in the name of the yaml, and the corresponding helm applications will be part of that range. Below is a summary of the ranges:

| Range | root-application | helm application |
| ----- | ---------------- | ---------------- |
|000 | cluster-appset | |
|000-009 | ibm-operator-catalog-app | ibm-operator-catalog |
|010-019 | ibm-redhat-cert-manager-app | redhat-cert-manager |
|020-029 | ibm-dro-app | ibm-dro |
|040-049 | cis-compliance-app | cis-compliance |
|050-059 | nvidia-gpu-operator-app | nvidia-gpu-operator |
|060-069 | ibm-db2u-app | ibm-db2u |
|099| instance-appset | |
|100-109 | ibm-sls-app | ibm-sls |
|120-129 | db2-database-appset | ibm-db2-database |
|130-199 | ibm-mas-suite-app | ibm-mas-suite |
|130-199 | configs-appset | ibm-mas-mongo-config |
|130-199 | configs-appset | ibm-mas-bas-config |
|130-199 | configs-appset | ibm-mas-sls-config |
|130-199 | configs-appset | ibm-mas-kafka-config |
|130-199 | configs-appset | ibm-mas-db2u-jdbc-config |
|130-199 | configs-appset | ibm-mas-db2u-jdbc-config-rotate-password |
|130-199 | configs-appset | ibm-mas-smtp-config |
|130-199 | configs-appset | ibm-mas-idp-config |
|130-199 | configs-appset | ibm-watson-studio-config |
|130-199 | configs-appset | ibm-objectstorage-config |
|220-229 | ibm-mas-workspace | ibm-mas-workspace |
|500-699 | masapp-appset | ibm-mas-suite-app-install |
|500-699 | masapp-appset | ibm-mas-suite-app-config |

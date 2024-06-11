Secrets
===============================================================================

Sensitive values that should not be exposed in the **Config Repo** are stored in a **Secrets Vault**. They are fetched at runtime using the [ArgoCD Vault Plugin](https://argocd-vault-plugin.readthedocs.io/en/stable/) from some backend implementation (e.g. [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/)).

Secret vaults are referenced in the configuration files in the **Config Repo** as inline-path placeholders. For example:
```yaml
ibm_entitlement_key: "<path:arn:aws:secretsmanager:us-east-1:xxxxxxxxxxxx:secret:dev/cluster1/ibm_entitlement#image_pull_secret_b64>"
```

These are referenced in Helm Chart templates, e.g. [02-ibm-entitlement_Secret](cluster-applications/000-ibm-operator-catalog/templates/02-ibm-entitlement_Secret.yaml):
```yaml
data:
  .dockerconfigjson: >-
    {{ .Values.ibm_entitlement_key }}
```

During rendering of the Helm Chart, the ArgoCD Vault Plugin takes care of fetch the value from the **Secrets Vault** at runtime and substituting it into the template.

!!! info
    MAS GitOps only supports AWS Secrets Manager at present. Support for other backends will be added in future releases.


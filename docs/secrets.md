The {{ secrets_vault() }}
===============================================================================

Sensitive values that should not be exposed in the {{ config_repo() }} are stored as secrets in the {{ secrets_vault() }}. Secrets are fetched at runtime using the [ArgoCD Vault Plugin](https://argocd-vault-plugin.readthedocs.io/en/stable/) from some backend implementation (e.g. [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/)).

Secrets are referenced in the YAML configuration files in the {{ config_repo() }} as inline-path placeholders. For example:
```yaml
ibm_entitlement_key: "<path:arn:aws:secretsmanager:us-east-1:xxxxxxxxxxxx:secret:dev/cluster1/ibm_entitlement#image_pull_secret_b64>"
```

These are referenced in Helm Chart templates, e.g. {{ gitops_repo_file_link("cluster-applications/000-ibm-operator-catalog/templates/02-ibm-entitlement_Secret.yaml", "02-ibm-entitlement_Secret" ) }}:
```yaml
data:
  .dockerconfigjson: >-
    {% raw %}{{ .Values.ibm_entitlement_key }}{% endraw %}
```

During rendering of the Helm Chart, the ArgoCD Vault Plugin will fetch the secret value from the {{ secrets_vault() }} at runtime and substitute it into the template.

!!! info
    MAS GitOps only supports AWS Secrets Manager at present. Support for other backends will be added in future releases.


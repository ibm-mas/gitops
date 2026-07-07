The {{ secrets_vault() }}
===============================================================================

Sensitive values that should not be exposed in the {{ config_repo() }} are stored as secrets in the {{ secrets_vault() }}. Secrets are fetched at runtime using the [ArgoCD Vault Plugin](https://argocd-vault-plugin.readthedocs.io/en/stable/) from one of the supported backend implementations.

## Supported Backends

MAS GitOps supports two secrets backends, configured via `sm.backend` in the base values:

### AWS Secrets Manager (`aws`)

The default backend. Secrets are stored in [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/) and referenced in configuration files using inline-path placeholders. For example:

```yaml
sm:
  backend: aws   # default — can be omitted
  aws_secret_region: us-east-1
  aws_access_key_id: "<path:arn:aws:secretsmanager:us-east-1:xxxxxxxxxxxx:secret:dev/cluster1/aws_access#key_id>"
  aws_secret_access_key: "<path:arn:aws:secretsmanager:us-east-1:xxxxxxxxxxxx:secret:dev/cluster1/aws_access#secret_key>"
```

Secret values elsewhere in the configuration are referenced using the same inline-path format:
```yaml
ibm_entitlement_key: "<path:arn:aws:secretsmanager:us-east-1:xxxxxxxxxxxx:secret:dev/cluster1/ibm_entitlement#image_pull_secret_b64>"
```

### Kubernetes Secrets (`kubernetessecrets`)

An alternative backend that stores secrets as native Kubernetes Secrets. When this backend is used, `sm.secrets_path` must be set to the namespace where secrets will be created, and the `aws_*` fields are not required:

```yaml
sm:
  backend: kubernetessecrets
  secrets_path: mas-dev-core   # namespace to create secrets in
```

## How Secrets Are Resolved

These values are referenced in Helm Chart templates, e.g. {{ gitops_repo_file_link("cluster-applications/000-ibm-operator-catalog/templates/02-ibm-entitlement_Secret.yaml", "02-ibm-entitlement_Secret" ) }}:
```yaml
data:
  .dockerconfigjson: >-
    {% raw %}{{ .Values.ibm_entitlement_key }}{% endraw %}
```

During rendering of the Helm Chart, the ArgoCD Vault Plugin will fetch the secret value from the configured backend at runtime and substitute it into the template.


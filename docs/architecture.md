Architecture
===============================================================================



MAS GitOps employs ArgoCD to deploy MAS instances to {{ target_clusters() }} using information from three sources: the {{ source_repo() }}, the {{ config_repo() }}, and the {{ secrets_vault() }}.

- {{ source_repo() }}: A Git repository containing the MAS GitOps Helm Charts that define the Kubernetes resources needed for MAS deployments.
- {{ config_repo() }}: Contains YAML files with configuration values for rendering the Helm Charts, specifying the number, locations, and configurations of MAS deployments.
- {{ secrets_vault() }}: Stores sensitive values that should not be exposed in the {{ config_repo() }}.

ArgoCD is installed and configured on some {{ management_cluster() }}. A single **Account Root Application** is registered with ArgoCD. This application monitors the {{ config_repo() }} and dynamically generates a hierarchy of applications that manage MAS deployments on the {{ target_clusters() }}.

![Architecture](png/architecture.png)


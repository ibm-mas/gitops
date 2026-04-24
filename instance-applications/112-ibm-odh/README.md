IBM ODH
===============================================================================
Deploy and configure ODH with configurable version

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Namespace` | ODH and serverless namespaces | ODH-related namespaces | Always | `application_admin_role` |
| `OperatorGroup` | ODH operator groups | ODH-related namespaces | Always | `application_admin_role` |
| `Subscription` | ODH/operator subscriptions | ODH-related namespaces | Always | `application_admin_role` |
| `ServiceAccount` | ODH service mesh service account | ODH-related namespaces | Always | `application_admin_role` |
| `DSCInitialization` | ODH DSC initialization CR | ODH namespace | Always | `application_admin_role` |
| `DataScienceCluster` | ODH data science cluster CR | ODH namespace | Always | `application_admin_role` |
| `PeerAuthentication` | Istio peer authentication for ODH | ODH namespace | Always | `application_admin_role` |
| `DestinationRule` | Istio destination rule for ODH | ODH namespace | Always | `application_admin_role` |
| `NetworkPolicy` | ODH network policy | ODH namespace | Always | `application_admin_role` |
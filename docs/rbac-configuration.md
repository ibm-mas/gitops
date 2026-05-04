# MAS GitOps RBAC Configuration

The [rbac](https://github.com/ibm-mas/gitops/tree/main/rbac) directory in the repository contains namespace-scoped RBAC (Role-Based Access Control) configurations for MAS GitOps deployments. This documentation provides comprehensive guidance on configuring RBAC when deploying with limited privileges (`cluster_admin_role=false` and `application_admin_role=true`).


{%
   include-markdown "../rbac/README.md"
   start="<!-- content-start -->"
%}
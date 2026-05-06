# IBM Maximo Application Suite - GitOps

A GitOps-based deployment framework for managing IBM Maximo Application Suite (MAS) at scale using ArgoCD and Helm.

## What is this repository?

This repository provides a complete GitOps solution for deploying and managing MAS across multiple clusters and instances. It uses an **App of Apps** pattern with ArgoCD to orchestrate deployments through a hierarchy of Helm charts, enabling:

- **Declarative infrastructure** - Define your entire MAS deployment in configuration files
- **Multi-cluster management** - Deploy and manage MAS across multiple OpenShift clusters
- **Multi-instance support** - Run multiple MAS instances within a single cluster
- **Automated orchestration** - ArgoCD handles deployment sequencing and dependencies
- **Configuration separation** - Keep deployment logic separate from environment-specific configuration

## Key Features

- **Hierarchical Application Structure** - Account → Cluster → Instance root applications
- **Modular Helm Charts** - Reusable charts for operators, databases, MAS components, and applications
- **Config Repository Pattern** - External configuration with AWS Secrets Manager integration
- **RBAC Management** - Automated generation of role-based access controls
- **Job Naming Conventions** - Standardized patterns for idempotent deployments

## Getting Started

Explore the documentation to understand the architecture and deployment patterns:

- **[Architecture Overview](architecture.md)** - Understand the GitOps structure and component relationships
- **[The Source Repository](helmcharts.md)** - Learn about the Helm chart organization
- **[The Config Repository](configrepo.md)** - Configure your MAS deployments
- **[Deployment Orchestration](orchestration.md)** - How ArgoCD manages the deployment flow

## Demo Repository

This demo repository contains a step-by-step guide to using gitops:
- **[gitops-demo](https://github.com/ibm-mas/gitops-demo/)**

## Quick Links

- **[Helm Charts Index](charts-index.md)** - Browse all available charts
- **[RBAC Configuration](rbac-configuration.md)** - Set up access controls
- **[Known Limitations](limitations.md)** - Current constraints and workarounds
- **[Contributing Guide](https://github.com/ibm-mas/gitops/blob/main/CONTRIBUTING.md)** - How to contribute

## Related Projects

- **[MAS Ansible Collection](https://ibm-mas.github.io/ansible-devops/)** - Ansible-based automation for MAS
- **[MAS CLI](https://ibm-mas.github.io/cli/)** - Command-line tools for MAS management

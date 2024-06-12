
Config Repository
===============================================================================

The {{ config_repo() }} represents the "source of truth" that (along with the Charts in the {{ source_repo() }} and the secrets in the {{ secrets_vault() }}) provides everything ArgoCD needs to install and manage MAS instances across {{ target_clusters() }}.

It is structured as a hierarchy, with "accounts" at the top, followed by "clusters", followed by "instances". Each level contains different types of YAML configuration files. Each YAML configuration file will cause ArgoCD to generate one (or more) application(s), which in turn render Helm charts into the appropriate {{ target_cluster() }}.

Here is the structure of an example {{ config_repo() }} containing configuration for three accounts (`dev`, `staging`, `production`) with a number of clusters and MAS instances:
```
├── dev
│   ├── cluster1
│   │   ├── instance1
│   │   │   └── *.yaml
│   │   ├── instance2
│   │   │   └── *.yaml
│   │   ├── instance3
│   │   │   └── *.yaml
│   │   └── *.yaml
│   └── cluster2
│       ├── *.yaml
│       └── instance1
│           └── *.yaml
├── staging
│   └── cluster1
│       ├── instance1
│       │   └── *.yaml
│       ├── instance2
│       │   └── *.yaml
│       └── *.yaml
└── production
    └── cluster1
        ├── *.yaml
        ├── instance1
        │   └── *.yaml
        └── instance2
            └── *.yaml
```

The current set of YAML configuration files recognised by MAS GitOps at each level is as follows:

```
├── <ACCOUNT_ID>
│   └── <CLUSTER_ID>
│       ├── <INSTANCE_ID>
│       │   ├── ibm-db2u-databases.yaml
│       │   ├── ibm-mas-instance-base.yaml
│       │   ├── ibm-mas-masapp-assist-install.yaml
│       │   ├── ibm-mas-masapp-configs.yaml
│       │   ├── ibm-mas-masapp-iot-install.yaml
│       │   ├── ibm-mas-masapp-manage-install.yaml
│       │   ├── ibm-mas-masapp-monitor-install.yaml
│       │   ├── ibm-mas-masapp-optimizer-install.yaml
│       │   ├── ibm-mas-masapp-visualinspection-install.yaml
│       │   ├── ibm-mas-suite-configs.yaml
│       │   ├── ibm-mas-suite.yaml
│       │   ├── ibm-mas-workspaces.yaml
│       │   └── ibm-sls.yaml
│       ├── ibm-db2u.yaml
│       ├── ibm-dro.yaml
│       ├── ibm-mas-cluster-base.yaml
│       ├── ibm-operator-catalog.yaml
│       ├── nvidia-gpu-operator.yaml
│       └── redhat-cert-manager.yaml
```

!!! info
    See {{ gitops_repo_dir_link("example-config") }} for examples of each of these YAML files for a single account, cluster and MAS instance.


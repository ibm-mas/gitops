
Config Repository
===============================================================================

The **Config Repo** represents the "source of truth" that (along with the Charts in the **Source Repo** and the secrets in the **Secrets Vault**) provides everything ArgoCD needs to install and manage MAS instances across the target clusters.

It is structured as a hierarchy, with "accounts" (e.g. dev/prod/staging) at the top, followed by "clusters", followed by "instances". Each level contains different types of `.yaml` configuration files. Each `.yaml` file will cause ArgoCD to generate one (or more) application(s), which in turn render Helm charts into the appropriate target cluster.

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

> See the `example-config` directory in this repository for some actual examples of each of these `.yaml` files.

Here is the structure of an example **Config Repo** containing configuration for three accounts (`dev`, `staging`, `production`) with a number of clusters and MAS instances. For brevity, the actual `.yaml` file names are not shown here.
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
IBM MAS Cluster Root Application
===============================================================================
Installs various ArgoCD Applications for managing dependencies shared by MAS instances on the target cluster.

Also installs the MAS Instance Root ArgoCD ApplicationSet (`099-instance-appset.yaml`) responsible for generating a set of IBM MAS Instance Root ArgoCD Applications for managing MAS instances on the target cluster.

Also installs the Aibroker Instance Root ArgoCD ApplicationSet (`099-Aibroker-instance-appset.yaml`) responsible for generating a set of IBM Aibroker Instance Root ArgoCD Applications for managing Aibroker instances on the target cluster.
Deployment Timings
===============================================================================

Each ArgoCD Application will take a number of minutes to complete syncing and to show as healthy, before moving onto the next application in the wave. This can vary for each app from a few minutes to mulitple hours. Depending on what configuration is choosen then each environment might not have the application present i.e. you might not have CP4D installed.

Below is a table to show the expected elapsed time for the argocd application to finish syncing. Times are approximate and other factors can vary these times such as performance of the cluster or external dependencies.

| Application | Approximate Duration |
|-|-|
| operator-catalog | 3 minutes |
| redhat-cert-manager | 2 minutes |
| dro | 5 minutes |
| cis-compliance | 3 minutes |
| ibm-sls | 10 minutes |
| ibm-suite | 10 minutes |
| ibm-cp4d-operators | 2 minutes |
| ibm-spss | 80 minutes |
| ibm-openscale | 15 minutes |
| ibm-wml | 25 minutes |
| ibm-wsl | 45 minutes |
| ibm-spark | 15 minutes |
| ibm-db2u-database | 12 minutes |
| ibm-assist | 20 minutes |
| ibm-assist-cfg | 2 minutes |
| ibm-iot | 60 minutes |
| ibm-iot-cfg | 2 minutes |
| ibm-monitor | 12 minutes |
| ibm-monitor-cfg | 30 minutes |
| ibm-optimizer | 5 minutes |
| ibm-optimizer-cfg | 12 minutes |
| ibm-visualinspection | 20 minutes |
| ibm-visualinspection-cfg | 2 minutes |
| ibm-manage | 8 minutes |
| ibm-manage-cfg | 240 minutes |
| ibm-predict | 2 minutes |
| ibm-predict-cfg | 15 minutes |
SPSS Modeler
===============================================================================
Deploys and configures the CP4D Service, SPSS Modeler.

[SPSS Modeler](https://www.ibm.com/docs/en/cloud-paks/cp-data/4.8.x?topic=modeler-installing) optional dependency for [Predict](https://www.ibm.com/docs/en/mas-cd/mhmpmh-and-p-u/continuous-delivery)

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Subscription` | SPSS operator subscriptions | CP4D instance namespace | Always | `application_admin_role` |
| `Spss` | SPSS service CR | CP4D instance namespace | Always | `application_admin_role` |
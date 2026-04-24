IBM CommonServices Control (CS)
===============================================================================
Deploys and configures IBM CS Control that is required for IBM CPD

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | IBM CS control operator group | CP4D operators namespace | Always | `application_admin_role` |
| `Subscription` | IBM licensing/operator subscription | CP4D operators namespace | Always | `application_admin_role` |
| `IBMLicensing` | IBM licensing instance | CP4D operators namespace | Always | `application_admin_role` |

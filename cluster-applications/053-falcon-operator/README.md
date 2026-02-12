CrowdStrike Falcon Operator
===============================================================================
Installs the CrowdStrike Falcon Operator for node monitoring. See https://github.com/CrowdStrike/falcon-operator

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `OperatorGroup` | `falcon-operator` | `falcon-operator` | Always | `cluster_admin_role` |
| `Subscription` | `falcon-operator` | `falcon-operator` | Always | `cluster_admin_role` |
| `FalconNodeSensor` | `falcon-node-sensor` | `falcon-operator` | Always | `cluster_admin_role` |

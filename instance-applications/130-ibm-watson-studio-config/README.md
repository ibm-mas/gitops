WatsonStudio Configuration for MAS Core Platform
===============================================================================
Create a WatsonStudioCfg CR instance and associated credentials secret for use by MAS.

## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Secret` | Watson Studio credential secret | MAS core namespace | Always | `application_admin_role` |
| `WatsonStudioCfg` | MAS Watson Studio configuration CR | MAS core namespace | Always | `application_admin_role` |
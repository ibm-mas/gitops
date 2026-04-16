IBM Watson Machine Learning (WML)
===============================================================================
Deploys and configures the CP4D Service, Watson Machine Learning (WML) needed for `MAS Predict`. Deploys WML operator and its dependencies.


## Resources Created

| Resource Type | Resource Name | Namespace | Condition | Installed By |
|--------------|---------------|-----------|-----------|--------------|
| `Subscription` | WML operator subscription | CP4D instance namespace | Always | `application_admin_role` |
| `WmlBase` | WML service CR | CP4D instance namespace | Always | `application_admin_role` |

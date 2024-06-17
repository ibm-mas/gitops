IDP Configuration for MAS Core Platform
===============================================================================
Create a IdpCfg CR instance and associated credentials secret for use by MAS.
Currently only supports LDAP.

Contains a post-delete hook (`postdelete-delete-cr.yaml`) that will ensure the config CR is deleted when the ArgoCD application managing this chart is deleted (this will not happen by default as the config CR is asserted to be owned by the `Suite` CR by the MAS entity managers).
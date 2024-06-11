Known Limitations
===============================================================================

**A single ArgoCD instance cannot manage more than one Account Root Application.**. This is primarily due to a limitation we have inherited to be compatible with internal IBM systems where we must have everything under a single ArgoCD project. This limitation could be addressed by adding support for multi-project configurations, assigning each **Account Root Application** its own project in ArgoCD. This is something we'd like to do in the long term but it's not a priority at the moment.


**MAS GitOps only supports AWS Secrets Manager at present.** Support for other backends will be added in future releases.

Any modifications made via the MAS admin UI or REST API that result in modifications to existing K8S resources will be undone by ArgoCD. We plan to provide a gitops-specific configuration option in MAS to disable these UI/REST APIs when in being managed by Gitops.


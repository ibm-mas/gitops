MAS Image Mirroring
===============================================================================

Establishes resources necessary to support image mirroring via an ImageDigestMirrorSet:

- `ecr-token-rotator` CronJob that rotates the ECR login token and injects it into the global pull-secret.
- `mas-ecr` `ImageDigestMirrorSet that redirects all image pulls fromn icr.io and cp.icr.io to ECR
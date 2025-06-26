MAS Image Mirroring
===============================================================================

Establishes resources necessary to support image mirroring via an ImageDigestMirrorSet.

Deploys the `ecr-token-rotator` CronJob that rotates the ECR login token and injects it into the global pull-secret. This is necessary since:
1. `ImageDigestMirrorSet` is used to pull images from ECR instead of external repos (e.g. ICR)
2. 

... TODO
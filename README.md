# gitops
A GitOps approach to managing Maximo Application Suite

Execute `bash bootstrap.sh`  to install and configure Openshift Gitops to work with MAS.

The bootstrap script do provide support to work with AWS and IBM Secret Managers as vault backend. The following shows examples using both of them

For AWS Secret Manager:

```bash
bash bootstrap.sh -t aws --avp-aws-secret-region us-east-1 --avp-aws-secret-key <aws_secret_access_key> --avp-aws-access-key <aws_access_key> --github-url <http_git_url> --github-pat <github_personal_access_token>
```

For IBM Cloud Secret Manager:

```bash
bash bootstrap.sh -t ibm --avp-ibm-api-key <ibmcloud_apikey> --avp-ibm-instance-url <url_for_secret_manager_instance>
```


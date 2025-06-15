def define_env(env):
    
  gitops_repo_url = "https://github.com/ibm-mas/gitops"
  gitops_repo_branch = "main"

  env.variables["gitops_repo_url"] = gitops_repo_url
  env.variables["gitops_repo_branch"] = gitops_repo_branch


  def config_repo():
    return "**Config Repository**"
  env.macro(config_repo)

  def source_repo():
    return "**Source Repository**"
  env.macro(source_repo)

  def secrets_vault():
    return "**Secrets Vault**"
  env.macro(secrets_vault)

  def management_cluster():
    return "**Management Cluster**"
  env.macro(management_cluster)


  def target_cluster():
    return "**Target Cluster**"
  env.macro(target_cluster)

  def target_clusters():
    return "**Target Clusters**"
  env.macro(target_clusters)


  def gitops_repo_file_url(path):
      return f"{gitops_repo_url}/blob/{gitops_repo_branch}/{path}"
  env.macro(gitops_repo_file_url)
  
  def gitops_repo_dir_url(path):
      return f"{gitops_repo_url}/tree/{gitops_repo_branch}/{path}"
  env.macro(gitops_repo_dir_url)
  

  def gitops_repo_file_link(path, name=None):
     if name is None: name = path
     return f"[{name}]({gitops_repo_file_url(path)})"
  env.macro(gitops_repo_file_link)

  def gitops_repo_dir_link(path, name=None):
    if name is None: name = path
    return f"[{name}]({gitops_repo_dir_url(path)})"
  env.macro(gitops_repo_dir_link)





  def account_root_chart():
     return gitops_repo_dir_link("root-applications/ibm-mas-account-root", "Account Root Chart")
  env.macro(account_root_chart)


  def cluster_root_chart():
    return gitops_repo_dir_link("root-applications/ibm-mas-cluster-root", "Cluster Root Chart")
  env.macro(cluster_root_chart)

  def instance_root_chart():
    return gitops_repo_dir_link("root-applications/ibm-mas-instance-root", "Instance Root Chart")
  env.macro(instance_root_chart)

  def tenant_root_chart():
    return gitops_repo_dir_link("root-applications/ibm-aibroker-tenant-root", "Tenant Root Chart")
  env.macro(tenant_root_chart)


  def cluster_root_app_set():
     return gitops_repo_file_link("root-applications/ibm-mas-account-root/templates/000-cluster-appset.yaml", "Cluster Root Application Set")
  env.macro(cluster_root_app_set)

  def instance_root_app_set():
     return gitops_repo_file_link("root-applications/ibm-mas-cluster-root/templates/099-instance-appset.yaml", "Instance Root Application Set")
  env.macro(instance_root_app_set)

  def aibroker_instance_root_app_set():
    return gitops_repo_file_link("root-applications/ibm-mas-cluster-root/templates/099-aibroker-instance-appset.yaml", "AiBroker Instance Root Application Set")
  env.macro(aibroker_instance_root_app_set)
  
  def aibroker_tenant_root_app_set():
    return gitops_repo_file_link("root-applications/ibm-aibroker-instance-root/templates/070-aibroker-tenant-appset.yaml", "AiBroker Tenant Root Application Set")
  env.macro(aibroker_tenant_root_app_set)


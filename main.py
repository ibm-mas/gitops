def define_env(env):
    
  gitops_repo_url = "https://github.com/ibm-mas/gitops"
  gitops_repo_branch = "demo2"

  env.variables["gitops_repo_url"] = gitops_repo_url
  env.variables["gitops_repo_branch"] = gitops_repo_branch


  def config_repo():
    return "**Config Repo**"
  env.macro(config_repo)

  def management_cluster():
    return "**Management Cluster**"
  env.macro(management_cluster)


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



  def cluster_root_app_set():
     return gitops_repo_file_link("root-applications/ibm-mas-account-root/templates/000-cluster-appset.yaml", "Cluster Root Application Set")
  env.macro(cluster_root_app_set)



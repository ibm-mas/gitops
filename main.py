def define_env(env):
    
  gitops_repo_url = "https://github.com/ibm-mas/gitops"
  gitops_repo_branch = "demo2"

  env.variables["gitops_repo_url"] = gitops_repo_url
  env.variables["gitops_repo_branch"] = gitops_repo_branch


  def gitops_repo_file_link(path):
      return f"{gitops_repo_url}/blob/{gitops_repo_branch}/{path}"
  
  env.macro(gitops_repo_file_link)
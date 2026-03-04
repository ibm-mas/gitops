Contributing to MAS Gitops
===============================================================================


Documentation
-------------------------------------------------------------------------------

Versioned documentation is published automatically here: [https://ibm-mas.github.io/gitops/](https://ibm-mas.github.io/gitops/).
Documentation source is located in the `docs` folder.

To view your local documentation updates before pushing to git, run the following:

```
python3.12 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install mkdocs
pip install mkdocs-redirects
pip install mkdocs-macros-plugin
pip install mkdocs-drawio-file
mkdocs serve
```

Pre-Commit Hooks
-------------------------------------------------------------------------------

A custom pre-commit hook to automatically verify that various requirements are met in template files can be enabled by running the following commands:

```bash
python -m pip install pre-commit --upgrade
pre-commit install
```

Manually run the pre-commit hooks against changed files
```bash
pre-commit run
```

Manually run the pre-commit hooks against all files
```bash
pre-commit run -a
```

The same logic invoked by the commit hook logic is run and enforced by the "lint" GitHub Action.

GitHub Actions
-------------------------------------------------------------------------------
This repository uses several automated workflows:

### Lint and Check Helm Templates
**Workflow:** [`.github/workflows/lint.yaml`](.github/workflows/lint.yaml)
**Triggers:** Pull requests to `poc`, `main`, or `dev` branches

Validates all Helm charts and Job definitions:
- Runs [`helm-lint.sh`](build/bin/helm-lint.sh) on all charts in `instance-applications/`, `cluster-applications/`, and `root-applications/`
- Runs [`verify-job-definitions.sh`](build/bin/verify-job-definitions.sh) to ensure Job templates comply with naming conventions

### Build Documentation
**Workflow:** [`.github/workflows/docs.yml`](.github/workflows/docs.yml)
**Triggers:** Pushes to `main` or `dev` branches, or version tags (`*.*.*`)

Automatically builds and publishes versioned documentation to GitHub Pages:
- Uses [MkDocs](https://www.mkdocs.org/) with [mike](https://github.com/jimporter/mike) for version management
- Documentation is published to [https://ibm-mas.github.io/gitops/](https://ibm-mas.github.io/gitops/)
- Version tags (`x.x.x`) are grouped by minor release (`x.x`)

### Update Internal GHE Repo
**Workflow:** [`.github/workflows/update-internal-repo.yaml`](.github/workflows/update-internal-repo.yaml)
**Triggers:** Pushes to any branch (excluding tags)

Synchronizes changes to the internal IBM GitHub Enterprise repository:
- Copies files from public repo to `automation-paas-cd-pipeline/mas-gitops` on github.ibm.com
- Uses [`copy-gitops.sh`](build/bin/copy-gitops.sh) to selectively sync files
- Maintains branch parity between public and internal repositories


RBAC
-------------------------------------------------------------------------------
The [rbac](/rbac/) folder contains kustomize scripts to help users apply the RBAC needed for the `application_admin_role` to deploy MAS using ArgoCD. 
If new RBAC is addded to any helm chart then we need to update the roles in the `rbac` folder. We should also ensure that the templates are guarded
with the approtiate condition of `application_admin_role` or `cluster_admin_role`.

### Updating the Role

To update the Role definition:

1. Edit the base Role template [rbac/kustomize/base/application-admin-role.yaml](rbac/kustomize/base/application-admin-role.yaml)


### Adding New Resource Types

When adding new MAS applications that require additional resource types:

1. Identify the resource type and API group
2. Determine if it's cluster-scoped or namespace-scoped
3. If namespace-scoped:
   - Add to [`rbac/kustomize/base/application-admin-role.yaml`](kustomize/base/application-admin-role.yaml)
   - Re-apply the overlay
4. If cluster-scoped and read-only access needed:
   - Add to [`rbac/kustomize/components/cluster-readonly/application-admin-clusterrole-readonly.yaml`](kustomize/components/cluster-readonly/application-admin-clusterrole-readonly.yaml)
   - Reapply the ClusterRole
5. If cluster-scoped and write access needed:
   - Document as requiring `cluster_admin_role=true`
   - Update the README in [rbac](rbac/README.md) accordingly
6. Test in a development environment before production

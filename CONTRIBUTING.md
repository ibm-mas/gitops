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

## GitHub Actions

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
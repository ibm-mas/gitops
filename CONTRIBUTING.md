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

Running Tests
-------------------------------------------------------------------------------

This repository includes Python tests for build scripts and utilities. Tests are located in `build/bin/tests/` and use pytest.

### Setup Test Environment

```bash
python -m pip install --upgrade pip
pip install -r build/bin/tests/requirements.txt
```

### Run All Tests

```bash
pytest
```

### Run Tests with Verbose Output

```bash
pytest -v
```

### Run Specific Test File

```bash
pytest build/bin/tests/test_generate_application_admin_rbac.py
pytest build/bin/tests/test_generate_rbac_overlays.py
```

### Run Tests with Coverage Report

```bash
pytest --cov=build/bin --cov-report=html --cov-report=term
```

### Run Tests for Specific Module

```bash
# Test RBAC generation scripts
pytest build/bin/tests/test_generate_application_admin_rbac.py -v

# Test RBAC overlay generation
pytest build/bin/tests/test_generate_rbac_overlays.py -v

# Test chart README verification
pytest build/bin/tests/test_verify_chart_readme_tables.py -v
```

Tests are automatically run by the "Run Tests" GitHub Action on pull requests.

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

### Adding New Resource Types or new RBAC

Run the script [build/bin/generate_application_admin_rbac.py](build/bin/generate_application_admin_rbac.py) which will update the rbac files that will be
applied. The difference should just include what has been added, updated or removed.

### Generating RBAC Overlays

The [rbac/generate_rbac_overlays.py](rbac/generate_rbac_overlays.py) script generates Kustomize overlay directories for RBAC across MAS instances. This allows applying RBAC resources to multiple namespaces for different service accounts.

```bash
# Generate overlays for instances
./rbac/generate_rbac_overlays.py \
    --service-account mas-argocd-argocd-application-controller \
    inst1 inst2 inst3
```

### Testing RBAC Scripts

Unit tests for RBAC generation scripts are located in `build/bin/tests/`:

- `test_generate_application_admin_rbac.py` - Tests for RBAC rule generation from Helm charts
- `test_generate_rbac_overlays.py` - Tests for Kustomize overlay generation

Run RBAC-specific tests:

```bash
# Test RBAC rule generation
pytest build/bin/tests/test_generate_application_admin_rbac.py -v

# Test RBAC overlay generation
pytest build/bin/tests/test_generate_rbac_overlays.py -v
```


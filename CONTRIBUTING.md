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

The same logic invoked by the commit hook logic is run and enforced by the "lint" Github Action.
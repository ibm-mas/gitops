Contributing to MAS Gitops
===============================================================================

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
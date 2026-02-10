# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Build & Lint Commands

```bash
# Lint a specific Helm chart
./build/bin/helm-lint.sh -p <chart_path>

# Verify Job definitions comply with naming conventions
./build/bin/verify-job-definitions.sh <directory_or_files>

# Update CLI image digest across all charts
./build/bin/set-cli-image-digest.sh --root-dir . --digest 'sha256:...'

# Run pre-commit hooks manually
pre-commit run        # Changed files only
pre-commit run -a     # All files
```

## Documentation

```bash
# Local documentation preview (requires Python 3.12+)
python3.12 -m venv .venv
source .venv/bin/activate
pip install mkdocs mkdocs-redirects mkdocs-macros-plugin mkdocs-drawio-file
mkdocs serve
```

## Critical Job Naming Conventions

**All Job templates using `quay.io/ibmmas/cli` MUST follow these patterns:**

1. **Required constants** (in exact order):
   ```yaml
   {{- $_job_name_prefix := "your-prefix" }}  # Max 52 chars
   {{- $_cli_image_digest := "sha256:..." }}
   {{- $_job_config_values := omit .Values "junitreporter" }}
   {{- $_job_version := "v1" }}
   {{- $_job_hash := print ($_job_config_values | toYaml) $_cli_image_digest $_job_version | adler32sum }}
   {{- $_job_name := join "-" (list $_job_name_prefix $_job_hash )}}
   {{- $_job_cleanup_group := cat $_job_name_prefix | sha1sum }}
   ```

2. **Job metadata requirements:**
   ```yaml
   metadata:
     name: {{ $_job_name }}
     labels:
       mas.ibm.com/job-cleanup-group: {{ $_job_cleanup_group }}
   ```

3. **When to increment `$_job_version`:** Any change to immutable Job fields (env vars, volumes, etc.)

4. **Exemptions:** Jobs with `argocd.argoproj.io/hook` annotation (except those with ONLY `HookFailed` delete policy)

5. **Validation:** Run `./build/bin/verify-job-definitions.sh .` before committing

## ArgoCD Application Hierarchy

- **Account Root** → generates **Cluster Root Applications** (via ApplicationSet)
- **Cluster Root** → generates **Instance Root Applications** (via ApplicationSet)
- **Instance Root** → generates MAS instance deployments

Charts are organized by deployment target:
- `root-applications/` → ArgoCD management cluster (App of Apps pattern)
- `cluster-applications/` → Target cluster prerequisites
- `instance-applications/` → MAS instance resources

## Config Repository Pattern

Configuration files use `merge-key` to identify deployment targets:
```yaml
merge-key: "account/cluster/instance"  # Hierarchical path structure
```

Secrets reference AWS Secrets Manager using special syntax:
```yaml
key: "<path:arn:aws:secretsmanager:region:account:secret:path#field>"
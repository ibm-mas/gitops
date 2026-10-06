# Unit Tests for Build Scripts

This directory contains comprehensive unit tests for the Python scripts in `build/bin/`.

## Overview

The test suite provides coverage for:
- **`generate_application_admin_rbac.py`**: RBAC rule generation from Helm charts
- **`verify_chart_readme_tables.py`**: README table validation for Helm charts

## Test Structure

```
build/bin/tests/
├── __init__.py                              # Package initialization
├── conftest.py                              # Shared pytest fixtures
├── test_generate_application_admin_rbac.py  # Tests for RBAC generation
├── test_verify_chart_readme_tables.py       # Tests for README validation
└── README.md                                # This file
```

## Running Tests

### Prerequisites

Install pytest and dependencies:

```bash
pip install pytest pytest-cov pyyaml
```

### Run All Tests

```bash
# From repository root
pytest

# With verbose output
pytest -v

# With coverage report
pytest --cov=build/bin --cov-report=html --cov-report=term
```

### Run Specific Test Files

```bash
# Test RBAC generation only
pytest build/bin/tests/test_generate_application_admin_rbac.py

# Test README validation only
pytest build/bin/tests/test_verify_chart_readme_tables.py
```

### Run Specific Test Classes or Functions

```bash
# Run a specific test class
pytest build/bin/tests/test_generate_application_admin_rbac.py::TestResourceExtraction

# Run a specific test function
pytest build/bin/tests/test_generate_application_admin_rbac.py::TestResourceExtraction::test_extract_simple_kind
```

### Run Tests by Marker

```bash
# Run only unit tests
pytest -m unit

# Run only integration tests
pytest -m integration

# Skip slow tests
pytest -m "not slow"
```

## Test Categories

### Unit Tests (`@pytest.mark.unit`)
Test individual functions in isolation with mocked dependencies.

### Integration Tests (`@pytest.mark.integration`)
Test complete workflows with real file I/O and multiple components.

### Slow Tests (`@pytest.mark.slow`)
Tests that take longer to execute (>1 second).

### Filesystem Tests (`@pytest.mark.requires_filesystem`)
Tests that require actual filesystem operations.

## Test Coverage

### `test_generate_application_admin_rbac.py`

**TestResourceExtraction**
- Extracting Kubernetes Kinds from YAML files
- Handling single and multi-document YAML
- Detecting Helm conditionals (cluster_admin_role, application_admin_role)
- Extracting RBAC resources from Role/ClusterRole rules
- Skipping subresources (e.g., pods/exec)
- Handling invalid YAML with regex fallback
- Error handling for missing files

**TestParentAppConditional**
- Detecting conditionals from parent ArgoCD Application files
- Handling missing parent Applications

**TestRBACRuleGeneration**
- Generating RBAC rules from categorized resources
- Excluding cluster-admin-only resources
- Including resources from 'both' and 'none' categories
- Grouping resources by API group
- Correct pluralization of resource names

**TestHelmTemplateGeneration**
- Generating Helm templates with correct structure
- Including RBAC rules in templates

**TestErrorHandling**
- Custom exception handling
- I/O error handling
- Validation of constants

**TestIntegration**
- End-to-end processing of simple charts
- Handling charts with mixed conditionals

### `test_verify_chart_readme_tables.py`

**TestChartDiscovery**
- Finding charts in empty directories
- Finding single and multiple charts
- Handling incomplete charts

**TestReadmeTableParsing**
- Parsing ArgoCD Applications sections
- Parsing Resources Created sections
- Error handling for missing sections/tables

**TestTableEntryParsing**
- Parsing root application table entries
- Parsing resource table entries
- Handling malformed entries

**TestKindExtraction**
- Extracting single and multiple Kinds
- Deduplication of Kinds
- Handling Helm templates

**TestRootTemplateClassification**
- Classifying Application templates
- Classifying ApplicationSet templates
- Handling non-Application templates

**TestRootChartValidation**
- Validating complete root charts
- Detecting undocumented templates
- Detecting missing templates
- Detecting ApplicationSet marking mismatches

**TestResourceChartValidation**
- Validating complete resource charts
- Detecting undocumented resources
- Detecting stale resources in README

**TestChartValidation**
- Overall chart validation for root and resource charts

## Fixtures

The `conftest.py` file provides shared fixtures:

- **`temp_repo_structure`**: Creates temporary repository directory structure
- **`sample_helm_chart`**: Creates a basic Helm chart
- **`sample_configmap_template`**: Creates a ConfigMap template
- **`sample_role_template`**: Creates a Role template with RBAC rules
- **`sample_application_template`**: Creates an ArgoCD Application template
- **`sample_readme_root_chart`**: Creates a README for root charts
- **`sample_readme_resource_chart`**: Creates a README for resource charts
- **`sample_conditional_template`**: Creates a template with Helm conditionals
- **`mock_yaml_files`**: Creates various YAML files for testing

## Writing New Tests

### Test Naming Convention

- Test files: `test_<module_name>.py`
- Test classes: `Test<FeatureName>`
- Test functions: `test_<specific_behavior>`

### Example Test

```python
import pytest

def test_extract_simple_kind(tmp_path):
    """Test extracting a simple Kind from YAML."""
    yaml_content = """
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-config
"""
    yaml_file = tmp_path / "test.yaml"
    yaml_file.write_text(yaml_content)
    
    kinds, rbac_resources = extract_resources_from_yaml(yaml_file)
    
    assert len(kinds) == 1
    assert kinds[0][0] == "ConfigMap"
    assert kinds[0][1] == "v1"
```

### Using Fixtures

```python
def test_with_fixture(sample_helm_chart):
    """Test using a fixture."""
    chart_dir = sample_helm_chart
    assert (chart_dir / "Chart.yaml").exists()
    assert (chart_dir / "templates").is_dir()
```

## Continuous Integration

Tests are automatically run:
- **Pre-commit**: Via `.pre-commit-config.yaml` hook
- **Manual**: Run `pytest` before committing changes

## Troubleshooting

### Import Errors

If you see import errors, ensure you're running pytest from the repository root:

```bash
cd /path/to/gitops
pytest
```

### Path Issues

The tests add the parent directory to `sys.path` to import the scripts:

```python
sys.path.insert(0, str(Path(__file__).parent.parent))
```

### Fixture Not Found

Ensure `conftest.py` is in the same directory as your test files.

## Contributing

When adding new functionality to build scripts:

1. Write tests first (TDD approach)
2. Ensure tests cover edge cases and error conditions
3. Run full test suite before committing
4. Update this README if adding new test categories

## References

- [pytest documentation](https://docs.pytest.org/)
- [pytest fixtures](https://docs.pytest.org/en/stable/fixture.html)
- [pytest markers](https://docs.pytest.org/en/stable/mark.html)
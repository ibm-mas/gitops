#!/usr/bin/env python3
"""
Unit tests for verify_chart_readme_tables.py

Tests cover:
- Chart directory discovery
- README table parsing
- Template file validation
- Resource kind extraction
- Error handling
"""

import pytest
import sys
from pathlib import Path
from unittest.mock import Mock, patch

# Import the module under test
# pytest.ini sets pythonpath to build/bin
import verify_chart_readme_tables
from verify_chart_readme_tables import (
    find_chart_dirs,
    parse_readme_table,
    parse_root_table_entries,
    parse_resource_table_entries,
    extract_kinds_from_template,
    classify_root_template,
    validate_root_chart,
    validate_resource_chart,
    validate_chart,
)


class TestChartDiscovery:
    """Test chart directory discovery."""
    
    def test_find_chart_dirs_empty(self, tmp_path):
        """Test finding charts in empty directory."""
        charts = find_chart_dirs(tmp_path)
        assert charts == []
    
    def test_find_chart_dirs_single_chart(self, tmp_path):
        """Test finding a single chart."""
        chart_dir = tmp_path / "root-applications" / "test-chart"
        chart_dir.mkdir(parents=True)
        (chart_dir / "Chart.yaml").write_text("name: test")
        (chart_dir / "README.md").write_text("# Test")
        (chart_dir / "templates").mkdir()
        
        charts = find_chart_dirs(tmp_path)
        assert len(charts) == 1
        assert charts[0].name == "test-chart"
    
    def test_find_chart_dirs_multiple_directories(self, tmp_path):
        """Test finding charts across multiple directories."""
        for dir_name in ["root-applications", "instance-applications", "cluster-applications"]:
            chart_dir = tmp_path / dir_name / "test-chart"
            chart_dir.mkdir(parents=True)
            (chart_dir / "Chart.yaml").write_text("name: test")
            (chart_dir / "README.md").write_text("# Test")
            (chart_dir / "templates").mkdir()
        
        charts = find_chart_dirs(tmp_path)
        assert len(charts) == 3
    
    def test_find_chart_dirs_incomplete_chart(self, tmp_path):
        """Test that incomplete charts are skipped."""
        chart_dir = tmp_path / "root-applications" / "incomplete"
        chart_dir.mkdir(parents=True)
        (chart_dir / "Chart.yaml").write_text("name: test")
        # Missing README.md and templates directory
        
        charts = find_chart_dirs(tmp_path)
        assert len(charts) == 0


class TestReadmeTableParsing:
    """Test README table parsing."""
    
    def test_parse_readme_root_application_section(self, tmp_path):
        """Test parsing README with ArgoCD Applications section."""
        readme_content = """
# Test Chart

## ArgoCD Applications

| Template | Application Name | Description |
|----------|------------------|-------------|
| [test.yaml](templates/test.yaml) | test-app | Test application |
"""
        readme_file = tmp_path / "README.md"
        readme_file.write_text(readme_content)
        
        section_type, table_lines = parse_readme_table(readme_file)
        
        assert section_type == "root"
        assert len(table_lines) >= 2
        assert "Template" in table_lines[0]
    
    def test_parse_readme_resources_section(self, tmp_path):
        """Test parsing README with Resources Created section."""
        readme_content = """
# Test Chart

## Resources Created

| Resource Type | API Group | Namespaced | Description | Example |
|---------------|-----------|------------|-------------|---------|
| `ConfigMap` | core | Yes | Configuration | test-config |
"""
        readme_file = tmp_path / "README.md"
        readme_file.write_text(readme_content)
        
        section_type, table_lines = parse_readme_table(readme_file)
        
        assert section_type == "resource"
        assert len(table_lines) >= 2
        assert "Resource Type" in table_lines[0]
    
    def test_parse_readme_missing_section(self, tmp_path):
        """Test error when README is missing required section."""
        readme_content = """
# Test Chart

Some content but no table section.
"""
        readme_file = tmp_path / "README.md"
        readme_file.write_text(readme_content)
        
        with pytest.raises(ValueError) as exc_info:
            parse_readme_table(readme_file)
        
        assert "Missing supported README section" in str(exc_info.value)
    
    def test_parse_readme_missing_table(self, tmp_path):
        """Test error when section exists but table is missing."""
        readme_content = """
# Test Chart

## ArgoCD Applications

No table here, just text.
"""
        readme_file = tmp_path / "README.md"
        readme_file.write_text(readme_content)
        
        with pytest.raises(ValueError) as exc_info:
            parse_readme_table(readme_file)
        
        assert "Missing markdown table" in str(exc_info.value)


class TestTableEntryParsing:
    """Test parsing of table entries."""
    
    def test_parse_root_table_entries(self):
        """Test parsing root application table entries."""
        table_lines = [
            "| Template | Application Name | Description |",
            "|----------|------------------|-------------|",
            "| [test.yaml](templates/test.yaml) | test-app | Test |",
            "| [app.yaml](templates/app.yaml) | my-app (ApplicationSet) | App Set |",
        ]
        
        entries = parse_root_table_entries(table_lines)
        
        assert len(entries) == 2
        assert entries[0]["template"] == "test.yaml"
        assert entries[0]["application_name"] == "test-app"
        assert entries[1]["template"] == "app.yaml"
        assert "(ApplicationSet)" in entries[1]["application_name"]
    
    def test_parse_resource_table_entries(self):
        """Test parsing resource table entries."""
        table_lines = [
            "| Resource Type | API Group | Namespaced | Description | Example |",
            "|---------------|-----------|------------|-------------|---------|",
            "| `ConfigMap` | core | Yes | Config | test |",
            "| `Deployment` | apps | Yes | Deploy | app |",
        ]
        
        entries = parse_resource_table_entries(table_lines)
        
        assert len(entries) == 2
        assert entries[0]["resource_type"] == "ConfigMap"
        assert entries[1]["resource_type"] == "Deployment"
    
    def test_parse_root_table_entries_malformed(self):
        """Test handling of malformed table entries."""
        table_lines = [
            "| Template | Application Name |",
            "|----------|------------------|",
            "| invalid row without link |",
            "| [valid.yaml](templates/valid.yaml) | valid-app |",
        ]
        
        entries = parse_root_table_entries(table_lines)
        
        # Should only parse valid entries
        assert len(entries) == 1
        assert entries[0]["template"] == "valid.yaml"


class TestKindExtraction:
    """Test Kubernetes Kind extraction from templates."""
    
    def test_extract_kinds_single(self, tmp_path):
        """Test extracting a single Kind."""
        template_content = """
apiVersion: v1
kind: ConfigMap
metadata:
  name: test
"""
        template_file = tmp_path / "test.yaml"
        template_file.write_text(template_content)
        
        kinds = extract_kinds_from_template(template_file)
        
        assert kinds == ["ConfigMap"]
    
    def test_extract_kinds_multiple(self, tmp_path):
        """Test extracting multiple Kinds."""
        template_content = """
apiVersion: v1
kind: Service
---
apiVersion: apps/v1
kind: Deployment
---
apiVersion: v1
kind: ConfigMap
"""
        template_file = tmp_path / "test.yaml"
        template_file.write_text(template_content)
        
        kinds = extract_kinds_from_template(template_file)
        
        assert len(kinds) == 3
        assert "Service" in kinds
        assert "Deployment" in kinds
        assert "ConfigMap" in kinds
    
    def test_extract_kinds_deduplication(self, tmp_path):
        """Test that duplicate Kinds are deduplicated."""
        template_content = """
kind: ConfigMap
---
kind: ConfigMap
---
kind: Secret
"""
        template_file = tmp_path / "test.yaml"
        template_file.write_text(template_content)
        
        kinds = extract_kinds_from_template(template_file)
        
        assert len(kinds) == 2
        assert "ConfigMap" in kinds
        assert "Secret" in kinds
    
    def test_extract_kinds_with_helm_templates(self, tmp_path):
        """Test extracting Kinds from Helm templates."""
        template_content = """
{{- if .Values.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.name }}
{{- end }}
"""
        template_file = tmp_path / "test.yaml"
        template_file.write_text(template_content)
        
        kinds = extract_kinds_from_template(template_file)
        
        assert "Service" in kinds


class TestRootTemplateClassification:
    """Test classification of root templates."""
    
    def test_classify_application(self, tmp_path):
        """Test classifying Application template."""
        template_content = """
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-app
"""
        template_file = tmp_path / "test.yaml"
        template_file.write_text(template_content)
        
        app_kinds = classify_root_template(template_file)
        
        assert app_kinds == ["Application"]
    
    def test_classify_applicationset(self, tmp_path):
        """Test classifying ApplicationSet template."""
        template_content = """
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: test-appset
"""
        template_file = tmp_path / "test.yaml"
        template_file.write_text(template_content)
        
        app_kinds = classify_root_template(template_file)
        
        assert app_kinds == ["ApplicationSet"]
    
    def test_classify_non_app_template(self, tmp_path):
        """Test classifying non-Application template."""
        template_content = """
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-config
"""
        template_file = tmp_path / "test.yaml"
        template_file.write_text(template_content)
        
        app_kinds = classify_root_template(template_file)
        
        assert app_kinds == []


class TestRootChartValidation:
    """Test validation of root charts."""
    
    def test_validate_root_chart_valid(self, tmp_path):
        """Test validation of valid root chart."""
        chart_dir = tmp_path / "test-chart"
        templates_dir = chart_dir / "templates"
        templates_dir.mkdir(parents=True)
        
        # Create template
        template_file = templates_dir / "app.yaml"
        template_file.write_text("""
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-app
""")
        
        # Create README entry
        readme_entries = [
            {
                "template": "app.yaml",
                "application_name": "test-app",
                "raw": "| [app.yaml](templates/app.yaml) | test-app | Test |"
            }
        ]
        
        errors = validate_root_chart(chart_dir, readme_entries)
        
        assert errors == []
    
    def test_validate_root_chart_missing_from_readme(self, tmp_path):
        """Test detection of template not documented in README."""
        chart_dir = tmp_path / "test-chart"
        templates_dir = chart_dir / "templates"
        templates_dir.mkdir(parents=True)
        
        # Create template
        (templates_dir / "app.yaml").write_text("kind: Application")
        (templates_dir / "undocumented.yaml").write_text("kind: Application")
        
        readme_entries = [
            {
                "template": "app.yaml",
                "application_name": "test-app",
                "raw": "| [app.yaml](templates/app.yaml) | test-app | Test |"
            }
        ]
        
        errors = validate_root_chart(chart_dir, readme_entries)
        
        assert len(errors) == 1
        assert "undocumented.yaml" in errors[0]
        assert "not documented in README" in errors[0]
    
    def test_validate_root_chart_missing_template(self, tmp_path):
        """Test detection of README referencing missing template."""
        chart_dir = tmp_path / "test-chart"
        templates_dir = chart_dir / "templates"
        templates_dir.mkdir(parents=True)
        
        readme_entries = [
            {
                "template": "missing.yaml",
                "application_name": "test-app",
                "raw": "| [missing.yaml](templates/missing.yaml) | test-app | Test |"
            }
        ]
        
        errors = validate_root_chart(chart_dir, readme_entries)
        
        assert len(errors) == 1
        assert "missing.yaml" in errors[0]
        assert "missing template file" in errors[0]
    
    def test_validate_root_chart_applicationset_mismatch(self, tmp_path):
        """Test detection of ApplicationSet marking mismatch."""
        chart_dir = tmp_path / "test-chart"
        templates_dir = chart_dir / "templates"
        templates_dir.mkdir(parents=True)
        
        # Create ApplicationSet template
        template_file = templates_dir / "appset.yaml"
        template_file.write_text("""
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: test-appset
""")
        
        # README doesn't mark it as ApplicationSet
        readme_entries = [
            {
                "template": "appset.yaml",
                "application_name": "test-app",  # Missing (ApplicationSet)
                "raw": "| [appset.yaml](templates/appset.yaml) | test-app | Test |"
            }
        ]
        
        errors = validate_root_chart(chart_dir, readme_entries)
        
        assert len(errors) == 1
        assert "should mark" in errors[0]
        assert "ApplicationSet" in errors[0]


class TestResourceChartValidation:
    """Test validation of resource charts."""
    
    def test_validate_resource_chart_valid(self, tmp_path):
        """Test validation of valid resource chart."""
        chart_dir = tmp_path / "test-chart"
        templates_dir = chart_dir / "templates"
        templates_dir.mkdir(parents=True)
        
        # Create templates
        (templates_dir / "configmap.yaml").write_text("kind: ConfigMap")
        (templates_dir / "secret.yaml").write_text("kind: Secret")
        
        readme_entries = [
            {"resource_type": "ConfigMap", "raw": "| `ConfigMap` | core | Yes | Config | test |"},
            {"resource_type": "Secret", "raw": "| `Secret` | core | Yes | Secret | test |"},
        ]
        
        errors = validate_resource_chart(chart_dir, readme_entries)
        
        assert errors == []
    
    def test_validate_resource_chart_missing_from_readme(self, tmp_path):
        """Test detection of resource not documented in README."""
        chart_dir = tmp_path / "test-chart"
        templates_dir = chart_dir / "templates"
        templates_dir.mkdir(parents=True)
        
        (templates_dir / "configmap.yaml").write_text("kind: ConfigMap")
        (templates_dir / "deployment.yaml").write_text("kind: Deployment")
        
        readme_entries = [
            {"resource_type": "ConfigMap", "raw": "| `ConfigMap` | core | Yes | Config | test |"},
        ]
        
        errors = validate_resource_chart(chart_dir, readme_entries)
        
        assert len(errors) == 1
        assert "Deployment" in errors[0]
        assert "not documented in README" in errors[0]
    
    def test_validate_resource_chart_stale_in_readme(self, tmp_path):
        """Test detection of stale resource in README."""
        chart_dir = tmp_path / "test-chart"
        templates_dir = chart_dir / "templates"
        templates_dir.mkdir(parents=True)
        
        (templates_dir / "configmap.yaml").write_text("kind: ConfigMap")
        
        readme_entries = [
            {"resource_type": "ConfigMap", "raw": "| `ConfigMap` | core | Yes | Config | test |"},
            {"resource_type": "Deployment", "raw": "| `Deployment` | apps | Yes | Deploy | test |"},
        ]
        
        errors = validate_resource_chart(chart_dir, readme_entries)
        
        assert len(errors) == 1
        assert "Deployment" in errors[0]
        assert "not found in templates" in errors[0]


class TestChartValidation:
    """Test overall chart validation."""
    
    def test_validate_chart_root(self, tmp_path):
        """Test validating a root chart."""
        chart_dir = tmp_path / "test-chart"
        templates_dir = chart_dir / "templates"
        templates_dir.mkdir(parents=True)
        
        # Create README with ArgoCD Applications section
        readme_content = """
## ArgoCD Applications

| Template | Application Name | Description |
|----------|------------------|-------------|
| [app.yaml](templates/app.yaml) | test-app | Test |
"""
        (chart_dir / "README.md").write_text(readme_content)
        
        # Create template
        (templates_dir / "app.yaml").write_text("kind: Application")
        
        errors = validate_chart(chart_dir)
        
        assert errors == []
    
    def test_validate_chart_resource(self, tmp_path):
        """Test validating a resource chart."""
        chart_dir = tmp_path / "test-chart"
        templates_dir = chart_dir / "templates"
        templates_dir.mkdir(parents=True)
        
        # Create README with Resources Created section
        readme_content = """
## Resources Created

| Resource Type | API Group | Namespaced | Description | Example |
|---------------|-----------|------------|-------------|---------|
| `ConfigMap` | core | Yes | Config | test |
"""
        (chart_dir / "README.md").write_text(readme_content)
        
        # Create template
        (templates_dir / "configmap.yaml").write_text("kind: ConfigMap")
        
        errors = validate_chart(chart_dir)
        
        assert errors == []


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

# Made with Bob

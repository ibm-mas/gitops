#!/usr/bin/env python3
"""
Unit tests for generate_application_admin_rbac.py

Tests cover:
- Resource extraction from YAML files
- Conditional detection (cluster_admin_role, application_admin_role)
- RBAC rule generation
- File I/O operations
- Error handling
"""

import pytest
import sys
import yaml
from pathlib import Path
from unittest.mock import Mock, patch, mock_open, MagicMock
from io import StringIO

# Import the module under test
# pytest.ini sets pythonpath to build/bin
import generate_application_admin_rbac
from generate_application_admin_rbac import (
    RBACGenerationError,
    CLUSTER_ADMIN_ONLY_RESOURCES,
    get_parent_app_conditional,
    extract_resources_from_yaml,
    scan_helm_charts,
    generate_rbac_rules,
    generate_helm_template,
)


class TestResourceExtraction:
    """Test resource extraction from YAML files."""
    
    def test_extract_simple_kind(self, tmp_path):
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
        assert kinds[0][2] is None  # No conditional
    
    def test_extract_multiple_kinds(self, tmp_path):
        """Test extracting multiple Kinds from multi-document YAML."""
        yaml_content = """
apiVersion: v1
kind: Service
metadata:
  name: test-service
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
"""
        yaml_file = tmp_path / "test.yaml"
        yaml_file.write_text(yaml_content)
        
        kinds, rbac_resources = extract_resources_from_yaml(yaml_file)
        
        assert len(kinds) == 2
        kind_names = [k[0] for k in kinds]
        assert "Service" in kind_names
        assert "Deployment" in kind_names
    
    def test_extract_with_cluster_admin_conditional(self, tmp_path):
        """Test extracting resources with cluster_admin_role conditional."""
        yaml_content = """
{{- if .Values.cluster_admin_role }}
apiVersion: v1
kind: Secret
metadata:
  name: test-secret
{{- end }}
"""
        yaml_file = tmp_path / "test.yaml"
        yaml_file.write_text(yaml_content)
        
        kinds, rbac_resources = extract_resources_from_yaml(yaml_file)
        
        assert len(kinds) == 1
        assert kinds[0][2] == "cluster_admin_role"
    
    def test_extract_with_application_admin_conditional(self, tmp_path):
        """Test extracting resources with application_admin_role conditional."""
        yaml_content = """
{{- if .Values.application_admin_role }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-config
{{- end }}
"""
        yaml_file = tmp_path / "test.yaml"
        yaml_file.write_text(yaml_content)
        
        kinds, rbac_resources = extract_resources_from_yaml(yaml_file)
        
        assert len(kinds) == 1
        assert kinds[0][2] == "application_admin_role"
    
    def test_extract_with_both_conditionals(self, tmp_path):
        """Test extracting resources with both role conditionals (AND)."""
        yaml_content = """
{{- if and .Values.cluster_admin_role .Values.application_admin_role }}
apiVersion: v1
kind: Service
metadata:
  name: test-service
{{- end }}
"""
        yaml_file = tmp_path / "test.yaml"
        yaml_file.write_text(yaml_content)
        
        kinds, rbac_resources = extract_resources_from_yaml(yaml_file)
        
        assert len(kinds) == 1
        assert kinds[0][2] == "both"
    
    def test_extract_rbac_resources_from_role(self, tmp_path):
        """Test extracting resources from Role rules."""
        yaml_content = """
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: test-role
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - services
  verbs:
  - get
  - list
- apiGroups:
  - apps
  resources:
  - deployments
  verbs:
  - create
"""
        yaml_file = tmp_path / "test.yaml"
        yaml_file.write_text(yaml_content)
        
        kinds, rbac_resources = extract_resources_from_yaml(yaml_file)
        
        assert len(rbac_resources) == 3
        resource_names = [r[0] for r in rbac_resources]
        assert "pods" in resource_names
        assert "services" in resource_names
        assert "deployments" in resource_names
    
    def test_extract_skips_subresources(self, tmp_path):
        """Test that subresources (e.g., pods/exec) are skipped."""
        yaml_content = """
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: test-role
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - pods/exec
  - pods/log
  verbs:
  - get
"""
        yaml_file = tmp_path / "test.yaml"
        yaml_file.write_text(yaml_content)
        
        kinds, rbac_resources = extract_resources_from_yaml(yaml_file)
        
        # Should only have 'pods', not 'pods/exec' or 'pods/log'
        resource_names = [r[0] for r in rbac_resources]
        assert "pods" in resource_names
        assert "pods/exec" not in resource_names
        assert "pods/log" not in resource_names
    
    def test_extract_handles_invalid_yaml(self, tmp_path):
        """Test handling of invalid YAML with fallback to regex."""
        yaml_content = """
{{- $var := "test" }}
kind: ConfigMap
apiVersion: v1
metadata:
  name: {{ $var }}
"""
        yaml_file = tmp_path / "test.yaml"
        yaml_file.write_text(yaml_content)
        
        # Should not raise exception, should use regex fallback
        kinds, rbac_resources = extract_resources_from_yaml(yaml_file)
        
        assert len(kinds) >= 1
        kind_names = [k[0] for k in kinds]
        assert "ConfigMap" in kind_names
    
    def test_extract_file_not_found(self, tmp_path):
        """Test error handling when file doesn't exist."""
        non_existent = tmp_path / "does-not-exist.yaml"
        
        with pytest.raises(RBACGenerationError) as exc_info:
            extract_resources_from_yaml(non_existent)
        
        assert "Cannot read template file" in str(exc_info.value)


class TestParentAppConditional:
    """Test detection of conditionals from parent Application files."""
    
    def test_no_parent_app_found(self, tmp_path):
        """Test when no parent Application file is found."""
        template_file = tmp_path / "cluster-applications" / "test-chart" / "templates" / "test.yaml"
        template_file.parent.mkdir(parents=True)
        template_file.write_text("kind: ConfigMap")
        
        result = get_parent_app_conditional(template_file)
        assert result is None
    
    @patch('generate_application_admin_rbac.REPO_ROOT')
    def test_parent_app_with_cluster_admin(self, mock_repo_root, tmp_path):
        """Test detecting cluster_admin_role from parent Application."""
        mock_repo_root.__truediv__ = lambda self, x: tmp_path / x
        
        # Create template file
        template_file = tmp_path / "cluster-applications" / "test-chart" / "templates" / "test.yaml"
        template_file.parent.mkdir(parents=True)
        template_file.write_text("kind: ConfigMap")
        
        # Create parent Application file
        app_dir = tmp_path / "root-applications" / "test-root"
        app_dir.mkdir(parents=True)
        app_file = app_dir / "test-app.yaml"
        app_content = """
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    path: cluster-applications/test-chart
{{- if .Values.cluster_admin_role }}
  syncPolicy:
    automated: {}
{{- end }}
"""
        app_file.write_text(app_content)
        
        result = get_parent_app_conditional(template_file)
        assert result == "cluster_admin_role"


class TestRBACRuleGeneration:
    """Test RBAC rule generation logic."""
    
    def test_generate_rules_basic(self):
        """Test basic RBAC rule generation."""
        kinds_categorized = {
            'cluster_admin': set(),
            'application_admin': {('ConfigMap', 'v1'), ('Secret', 'v1')},
            'both': set(),
            'none': set()
        }
        rbac_resources_categorized = {
            'cluster_admin': set(),
            'application_admin': set(),
            'both': set(),
            'none': set()
        }
        
        rules = generate_rbac_rules(kinds_categorized, rbac_resources_categorized)
        
        assert len(rules) > 0
        # Check that core API group rule exists
        core_rule = next((r for r in rules if "" in r['apiGroups']), None)
        assert core_rule is not None
        assert 'configmaps' in core_rule['resources']
        assert 'secrets' in core_rule['resources']
    
    def test_generate_rules_excludes_cluster_admin_only(self):
        """Test that cluster-admin-only resources are excluded."""
        kinds_categorized = {
            'cluster_admin': {('ClusterRole', 'rbac.authorization.k8s.io/v1')},
            'application_admin': {('ConfigMap', 'v1')},
            'both': set(),
            'none': set()
        }
        rbac_resources_categorized = {
            'cluster_admin': set(),
            'application_admin': set(),
            'both': set(),
            'none': set()
        }
        
        rules = generate_rbac_rules(kinds_categorized, rbac_resources_categorized)
        
        # ClusterRole should not be in any rule
        for rule in rules:
            assert 'clusterroles' not in rule['resources']
    
    def test_generate_rules_includes_both_and_none(self):
        """Test that 'both' and 'none' categories are included."""
        kinds_categorized = {
            'cluster_admin': set(),
            'application_admin': set(),
            'both': {('Service', 'v1')},
            'none': {('Pod', 'v1')}
        }
        rbac_resources_categorized = {
            'cluster_admin': set(),
            'application_admin': set(),
            'both': set(),
            'none': set()
        }
        
        rules = generate_rbac_rules(kinds_categorized, rbac_resources_categorized)
        
        core_rule = next((r for r in rules if "" in r['apiGroups']), None)
        assert core_rule is not None
        assert 'services' in core_rule['resources']
        assert 'pods' in core_rule['resources']
    
    def test_generate_rules_groups_by_api_group(self):
        """Test that resources are grouped by API group."""
        kinds_categorized = {
            'cluster_admin': set(),
            'application_admin': {
                ('Deployment', 'apps/v1'),
                ('StatefulSet', 'apps/v1'),
                ('ConfigMap', 'v1')
            },
            'both': set(),
            'none': set()
        }
        rbac_resources_categorized = {
            'cluster_admin': set(),
            'application_admin': set(),
            'both': set(),
            'none': set()
        }
        
        rules = generate_rbac_rules(kinds_categorized, rbac_resources_categorized)
        
        # Should have separate rules for core and apps API groups
        api_groups = [r['apiGroups'][0] for r in rules]
        assert "" in api_groups  # Core API
        assert "apps" in api_groups
    
    def test_generate_rules_pluralization(self):
        """Test correct pluralization of resource names."""
        kinds_categorized = {
            'cluster_admin': set(),
            'application_admin': {
                ('Policy', 'v1'),  # -> policies
                ('Ingress', 'networking.k8s.io/v1'),  # -> ingresses
                ('Box', 'v1'),  # -> boxes
            },
            'both': set(),
            'none': set()
        }
        rbac_resources_categorized = {
            'cluster_admin': set(),
            'application_admin': set(),
            'both': set(),
            'none': set()
        }
        
        rules = generate_rbac_rules(kinds_categorized, rbac_resources_categorized)
        
        core_rule = next((r for r in rules if "" in r['apiGroups']), None)
        assert core_rule is not None
        assert 'policies' in core_rule['resources']
        assert 'boxes' in core_rule['resources']
        
        networking_rule = next((r for r in rules if "networking.k8s.io" in r['apiGroups']), None)
        assert networking_rule is not None
        assert 'ingresses' in networking_rule['resources']


class TestHelmTemplateGeneration:
    """Test Helm template generation."""
    
    def test_generate_helm_template_structure(self):
        """Test that generated Helm template has correct structure."""
        rules = [
            {
                "apiGroups": [""],
                "resources": ["configmaps", "secrets"],
                "verbs": ["create", "delete", "get", "list", "patch", "update", "watch"]
            }
        ]
        
        template = generate_helm_template(rules)
        
        assert "{{- $inst := .Values.instance_id }}" in template
        assert "kind: Role" in template
        assert "kind: RoleBinding" in template
        assert "mas-application-admin" in template
        assert "rules:" in template
    
    def test_generate_helm_template_includes_rules(self):
        """Test that rules are properly included in template."""
        rules = [
            {
                "apiGroups": ["apps"],
                "resources": ["deployments"],
                "verbs": ["get", "list"]
            }
        ]
        
        template = generate_helm_template(rules)
        
        assert "apiGroups:" in template
        assert "- apps" in template
        assert "resources:" in template
        assert "- deployments" in template


class TestErrorHandling:
    """Test error handling and edge cases."""
    
    def test_rbac_generation_error_inheritance(self):
        """Test that RBACGenerationError is properly defined."""
        error = RBACGenerationError("Test error")
        assert isinstance(error, Exception)
        assert str(error) == "Test error"
    
    def test_cluster_admin_only_resources_defined(self):
        """Test that CLUSTER_ADMIN_ONLY_RESOURCES is properly defined."""
        assert isinstance(CLUSTER_ADMIN_ONLY_RESOURCES, set)
        assert "ClusterRole" in CLUSTER_ADMIN_ONLY_RESOURCES
        assert "SecurityContextConstraints" in CLUSTER_ADMIN_ONLY_RESOURCES
        assert "CustomResourceDefinition" in CLUSTER_ADMIN_ONLY_RESOURCES
    
    def test_extract_resources_io_error(self, tmp_path):
        """Test handling of I/O errors during file reading."""
        yaml_file = tmp_path / "test.yaml"
        yaml_file.write_text("kind: ConfigMap")
        yaml_file.chmod(0o000)  # Remove read permissions
        
        try:
            with pytest.raises(RBACGenerationError) as exc_info:
                extract_resources_from_yaml(yaml_file)
            
            assert "Cannot read template file" in str(exc_info.value)
        finally:
            yaml_file.chmod(0o644)  # Restore permissions for cleanup


class TestIntegration:
    """Integration tests for complete workflows."""
    
    def test_end_to_end_simple_chart(self, tmp_path):
        """Test end-to-end processing of a simple chart."""
        # Create a minimal chart structure
        chart_dir = tmp_path / "cluster-applications" / "test-chart"
        templates_dir = chart_dir / "templates"
        templates_dir.mkdir(parents=True)
        
        # Create a simple template
        template_file = templates_dir / "configmap.yaml"
        template_content = """
{{- if .Values.application_admin_role }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-config
data:
  key: value
{{- end }}
"""
        template_file.write_text(template_content)
        
        # Extract resources
        kinds, rbac_resources = extract_resources_from_yaml(template_file)
        
        assert len(kinds) == 1
        assert kinds[0][0] == "ConfigMap"
        assert kinds[0][2] == "application_admin_role"
    
    def test_mixed_conditionals_chart(self, tmp_path):
        """Test chart with mixed conditional resources."""
        chart_dir = tmp_path / "instance-applications" / "mixed-chart"
        templates_dir = chart_dir / "templates"
        templates_dir.mkdir(parents=True)
        
        # Template with cluster_admin_role
        cluster_template = templates_dir / "cluster-resource.yaml"
        cluster_template.write_text("""
{{- if .Values.cluster_admin_role }}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: test-cluster-role
{{- end }}
""")
        
        # Template with application_admin_role
        app_template = templates_dir / "app-resource.yaml"
        app_template.write_text("""
{{- if .Values.application_admin_role }}
apiVersion: v1
kind: Service
metadata:
  name: test-service
{{- end }}
""")
        
        # Extract from both
        cluster_kinds, _ = extract_resources_from_yaml(cluster_template)
        app_kinds, _ = extract_resources_from_yaml(app_template)
        
        assert cluster_kinds[0][2] == "cluster_admin_role"
        assert app_kinds[0][2] == "application_admin_role"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

# Made with Bob

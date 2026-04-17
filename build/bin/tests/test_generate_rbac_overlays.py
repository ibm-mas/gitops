#!/usr/bin/env python3
"""
Unit tests for rbac/generate_rbac_overlays.py

Tests cover:
- Namespace generation from instance IDs
- Service account namespace derivation
- Kustomization file generation
- Overlay directory creation
- Main kustomization.yaml updates
- Command-line argument parsing
- Error handling
"""

import pytest
import sys
import re
from pathlib import Path
from unittest.mock import Mock, patch, call
from io import StringIO

# Import the module under test
# pytest.ini sets pythonpath to include rbac directory
import generate_rbac_overlays
from generate_rbac_overlays import (
    NAMESPACE_PATTERNS,
    generate_namespace_overlay,
    _derive_sa_namespace,
    _create_main_kustomization,
    update_main_kustomization,
    generate_overlays,
)


class TestNamespacePatterns:
    """Test namespace pattern definitions."""
    
    def test_namespace_patterns_defined(self):
        """Test that NAMESPACE_PATTERNS is properly defined."""
        assert isinstance(NAMESPACE_PATTERNS, list)
        assert len(NAMESPACE_PATTERNS) > 0
        
    def test_namespace_patterns_contain_placeholder(self):
        """Test that all patterns contain {inst} placeholder."""
        for pattern in NAMESPACE_PATTERNS:
            assert "{inst}" in pattern, f"Pattern '{pattern}' missing {{inst}} placeholder"
    
    def test_namespace_patterns_expected_namespaces(self):
        """Test that expected namespace patterns are present."""
        expected_patterns = [
            "db2u-{inst}",
            "mas-{inst}-core",
            "mas-{inst}-manage",
            "mas-{inst}-sls",
        ]
        for expected in expected_patterns:
            assert expected in NAMESPACE_PATTERNS, f"Missing expected pattern: {expected}"


class TestServiceAccountNamespaceDerivation:
    """Test service account namespace derivation logic."""
    
    def test_derive_namespace_with_suffix(self):
        """Test deriving namespace from SA with standard suffix."""
        sa_name = "mas-argocd-argocd-application-controller"
        result = _derive_sa_namespace(sa_name)
        assert result == "mas-argocd"
    
    def test_derive_namespace_without_suffix(self):
        """Test deriving namespace from SA without suffix."""
        sa_name = "custom-service-account"
        result = _derive_sa_namespace(sa_name)
        assert result == "custom-service-account"
    
    def test_derive_namespace_partial_suffix(self):
        """Test SA name with partial suffix match."""
        sa_name = "my-argocd-application"
        result = _derive_sa_namespace(sa_name)
        # Should not strip partial match
        assert result == "my-argocd-application"
    
    def test_derive_namespace_empty_string(self):
        """Test handling of empty string."""
        result = _derive_sa_namespace("")
        assert result == ""
    
    def test_derive_namespace_only_suffix(self):
        """Test SA name that is only the suffix."""
        sa_name = "-argocd-application-controller"
        result = _derive_sa_namespace(sa_name)
        assert result == ""


class TestNamespaceOverlayGeneration:
    """Test generation of individual namespace overlay directories."""
    
    def test_generate_namespace_overlay_creates_directory(self, tmp_path):
        """Test that overlay directory is created."""
        overlay_dir = tmp_path / "overlays" / "test-sa"
        namespace = "mas-inst1-core"
        
        generate_namespace_overlay(overlay_dir, namespace)
        
        ns_dir = overlay_dir / namespace
        assert ns_dir.exists()
        assert ns_dir.is_dir()
    
    def test_generate_namespace_overlay_creates_kustomization(self, tmp_path):
        """Test that kustomization.yaml is created."""
        overlay_dir = tmp_path / "overlays" / "test-sa"
        namespace = "mas-inst1-core"
        
        generate_namespace_overlay(overlay_dir, namespace)
        
        kustomization_file = overlay_dir / namespace / "kustomization.yaml"
        assert kustomization_file.exists()
    
    def test_generate_namespace_overlay_kustomization_content(self, tmp_path):
        """Test kustomization.yaml content is correct."""
        overlay_dir = tmp_path / "overlays" / "test-sa"
        namespace = "mas-inst1-core"
        
        generate_namespace_overlay(overlay_dir, namespace)
        
        kustomization_file = overlay_dir / namespace / "kustomization.yaml"
        content = kustomization_file.read_text()
        
        assert "apiVersion: kustomize.config.k8s.io/v1beta1" in content
        assert "kind: Kustomization" in content
        assert f"namespace: {namespace}" in content
        assert "- ../../../base" in content
    
    def test_generate_namespace_overlay_idempotent(self, tmp_path):
        """Test that generating overlay twice doesn't fail."""
        overlay_dir = tmp_path / "overlays" / "test-sa"
        namespace = "mas-inst1-core"
        
        # Generate twice
        generate_namespace_overlay(overlay_dir, namespace)
        generate_namespace_overlay(overlay_dir, namespace)
        
        # Should still exist and be valid
        kustomization_file = overlay_dir / namespace / "kustomization.yaml"
        assert kustomization_file.exists()


class TestMainKustomizationCreation:
    """Test creation of main kustomization.yaml file."""
    
    def test_create_main_kustomization_structure(self, tmp_path):
        """Test that main kustomization has correct structure."""
        kustomization_file = tmp_path / "kustomization.yaml"
        service_account = "test-sa-argocd-application-controller"
        namespaces = ["mas-inst1-core", "mas-inst1-manage"]
        
        _create_main_kustomization(kustomization_file, service_account, namespaces)
        
        content = kustomization_file.read_text()
        assert "apiVersion: kustomize.config.k8s.io/v1beta1" in content
        assert "kind: Kustomization" in content
        assert "resources:" in content
        assert "components:" in content
        assert "patches:" in content
    
    def test_create_main_kustomization_includes_namespaces(self, tmp_path):
        """Test that all namespaces are included in resources."""
        kustomization_file = tmp_path / "kustomization.yaml"
        service_account = "test-sa"
        namespaces = ["ns1", "ns2", "ns3"]
        
        _create_main_kustomization(kustomization_file, service_account, namespaces)
        
        content = kustomization_file.read_text()
        for ns in namespaces:
            assert f"- ./{ns}" in content
    
    def test_create_main_kustomization_sorted_namespaces(self, tmp_path):
        """Test that namespaces are sorted in resources list."""
        kustomization_file = tmp_path / "kustomization.yaml"
        service_account = "test-sa"
        namespaces = ["zebra-ns", "alpha-ns", "beta-ns"]
        
        _create_main_kustomization(kustomization_file, service_account, namespaces)
        
        content = kustomization_file.read_text()
        # Extract resources section
        resources_match = re.search(r"resources:(.*?)components:", content, re.DOTALL)
        assert resources_match
        resources_section = resources_match.group(1)
        
        # Check order
        assert resources_section.index("alpha-ns") < resources_section.index("beta-ns")
        assert resources_section.index("beta-ns") < resources_section.index("zebra-ns")
    
    def test_create_main_kustomization_patches_service_account(self, tmp_path):
        """Test that patches reference correct service account."""
        kustomization_file = tmp_path / "kustomization.yaml"
        service_account = "my-custom-sa-argocd-application-controller"
        namespaces = ["ns1"]
        
        _create_main_kustomization(kustomization_file, service_account, namespaces)
        
        content = kustomization_file.read_text()
        assert f"value: {service_account}" in content
        assert "value: my-custom-sa" in content  # Derived namespace
    
    def test_create_main_kustomization_includes_cluster_readonly(self, tmp_path):
        """Test that cluster-readonly component is included."""
        kustomization_file = tmp_path / "kustomization.yaml"
        service_account = "test-sa"
        namespaces = ["ns1"]
        
        _create_main_kustomization(kustomization_file, service_account, namespaces)
        
        content = kustomization_file.read_text()
        assert "- ../../components/cluster-readonly" in content


class TestMainKustomizationUpdate:
    """Test updating existing main kustomization.yaml file."""
    
    def test_update_creates_if_not_exists(self, tmp_path):
        """Test that update creates file if it doesn't exist."""
        overlay_dir = tmp_path / "overlays" / "test-sa"
        overlay_dir.mkdir(parents=True)
        service_account = "test-sa"
        namespaces = ["ns1"]
        
        update_main_kustomization(overlay_dir, service_account, namespaces)
        
        kustomization_file = overlay_dir / "kustomization.yaml"
        assert kustomization_file.exists()
    
    def test_update_merges_existing_namespaces(self, tmp_path):
        """Test that update merges with existing namespaces."""
        overlay_dir = tmp_path / "overlays" / "test-sa"
        overlay_dir.mkdir(parents=True)
        kustomization_file = overlay_dir / "kustomization.yaml"
        
        # Create initial kustomization with some namespaces
        initial_content = """---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./existing-ns1
  - ./existing-ns2
components:
  - ../../components/cluster-readonly
patches:
  - target:
      kind: RoleBinding
"""
        kustomization_file.write_text(initial_content)
        
        # Update with new namespaces
        service_account = "test-sa"
        new_namespaces = ["new-ns1", "existing-ns1"]
        
        update_main_kustomization(overlay_dir, service_account, new_namespaces)
        
        content = kustomization_file.read_text()
        # Should have all namespaces (merged and deduplicated)
        assert "./existing-ns1" in content
        assert "./existing-ns2" in content
        assert "./new-ns1" in content
    
    def test_update_preserves_components_and_patches(self, tmp_path):
        """Test that update preserves components and patches sections."""
        overlay_dir = tmp_path / "overlays" / "test-sa"
        overlay_dir.mkdir(parents=True)
        kustomization_file = overlay_dir / "kustomization.yaml"
        
        initial_content = """---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./ns1
components:
  - ../../components/cluster-readonly
patches:
  - target:
      kind: RoleBinding
    patch: |-
      - op: replace
        path: /subjects/0/name
        value: test-sa
"""
        kustomization_file.write_text(initial_content)
        
        service_account = "test-sa"
        namespaces = ["ns1", "ns2"]
        
        update_main_kustomization(overlay_dir, service_account, namespaces)
        
        content = kustomization_file.read_text()
        assert "components:" in content
        assert "patches:" in content
        assert "cluster-readonly" in content
    
    def test_update_handles_missing_resources_section(self, tmp_path):
        """Test error handling when resources section is missing."""
        overlay_dir = tmp_path / "overlays" / "test-sa"
        overlay_dir.mkdir(parents=True)
        kustomization_file = overlay_dir / "kustomization.yaml"
        
        # Create kustomization without resources section
        invalid_content = """---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
components:
  - ../../components/cluster-readonly
"""
        kustomization_file.write_text(invalid_content)
        
        service_account = "test-sa"
        namespaces = ["ns1"]
        
        with pytest.raises(SystemExit):
            update_main_kustomization(overlay_dir, service_account, namespaces)


class TestGenerateOverlays:
    """Test the main generate_overlays function."""
    
    @patch('generate_rbac_overlays.generate_namespace_overlay')
    @patch('generate_rbac_overlays.update_main_kustomization')
    def test_generate_overlays_creates_all_namespaces(
        self, mock_update, mock_generate, tmp_path
    ):
        """Test that overlays are generated for all namespace patterns."""
        with patch('generate_rbac_overlays.REPO_ROOT', tmp_path):
            service_account = "test-sa"
            instances = ["inst1"]
            
            generate_overlays(service_account, instances)
            
            # Should call generate_namespace_overlay for each pattern
            expected_calls = len(NAMESPACE_PATTERNS)
            assert mock_generate.call_count == expected_calls
    
    @patch('generate_rbac_overlays.generate_namespace_overlay')
    @patch('generate_rbac_overlays.update_main_kustomization')
    def test_generate_overlays_multiple_instances(
        self, mock_update, mock_generate, tmp_path
    ):
        """Test generating overlays for multiple instances."""
        with patch('generate_rbac_overlays.REPO_ROOT', tmp_path):
            service_account = "test-sa"
            instances = ["inst1", "inst2", "inst3"]
            
            generate_overlays(service_account, instances)
            
            # Should generate for all instances * all patterns
            expected_calls = len(instances) * len(NAMESPACE_PATTERNS)
            assert mock_generate.call_count == expected_calls
    
    @patch('generate_rbac_overlays.generate_namespace_overlay')
    @patch('generate_rbac_overlays.update_main_kustomization')
    def test_generate_overlays_namespace_formatting(
        self, mock_update, mock_generate, tmp_path
    ):
        """Test that namespaces are formatted correctly."""
        with patch('generate_rbac_overlays.REPO_ROOT', tmp_path):
            service_account = "test-sa"
            instances = ["myinst"]
            
            generate_overlays(service_account, instances)
            
            # Check that namespaces were formatted correctly
            called_namespaces = [
                call[0][1] for call in mock_generate.call_args_list
            ]
            
            # Should have namespaces like "mas-myinst-core", "db2u-myinst", etc.
            assert "mas-myinst-core" in called_namespaces
            assert "db2u-myinst" in called_namespaces
            assert "mas-myinst-manage" in called_namespaces
    
    @patch('generate_rbac_overlays.generate_namespace_overlay')
    @patch('generate_rbac_overlays.update_main_kustomization')
    def test_generate_overlays_calls_update_kustomization(
        self, mock_update, mock_generate, tmp_path
    ):
        """Test that main kustomization is updated."""
        with patch('generate_rbac_overlays.REPO_ROOT', tmp_path):
            service_account = "test-sa"
            instances = ["inst1"]
            
            generate_overlays(service_account, instances)
            
            # Should call update_main_kustomization once
            assert mock_update.call_count == 1
            
            # Check arguments
            call_args = mock_update.call_args[0]
            assert call_args[1] == service_account
            assert len(call_args[2]) == len(NAMESPACE_PATTERNS)


class TestCommandLineInterface:
    """Test command-line argument parsing and validation."""
    
    def test_main_requires_service_account(self):
        """Test that --service-account is required."""
        with patch('sys.argv', ['generate_rbac_overlays.py', 'inst1']):
            with pytest.raises(SystemExit):
                generate_rbac_overlays.main()
    
    def test_main_requires_instances(self):
        """Test that at least one instance is required."""
        with patch('sys.argv', [
            'generate_rbac_overlays.py',
            '--service-account', 'test-sa'
        ]):
            with pytest.raises(SystemExit):
                generate_rbac_overlays.main()
    
    @patch('generate_rbac_overlays.generate_overlays')
    def test_main_valid_arguments(self, mock_generate):
        """Test main with valid arguments."""
        with patch('sys.argv', [
            'generate_rbac_overlays.py',
            '--service-account', 'test-sa',
            'inst1', 'inst2'
        ]):
            generate_rbac_overlays.main()
            
            mock_generate.assert_called_once_with('test-sa', ['inst1', 'inst2'])
    
    def test_main_validates_instance_ids(self):
        """Test that instance IDs are validated."""
        with patch('sys.argv', [
            'generate_rbac_overlays.py',
            '--service-account', 'test-sa',
            'invalid@instance'
        ]):
            with pytest.raises(SystemExit):
                generate_rbac_overlays.main()
    
    @patch('generate_rbac_overlays.generate_overlays')
    def test_main_accepts_valid_instance_ids(self, mock_generate):
        """Test that valid instance IDs are accepted."""
        valid_instances = ['inst1', 'my-inst', 'inst_123', 'INST-ABC']
        
        with patch('sys.argv', [
            'generate_rbac_overlays.py',
            '--service-account', 'test-sa'
        ] + valid_instances):
            generate_rbac_overlays.main()
            
            mock_generate.assert_called_once()
            assert mock_generate.call_args[0][1] == valid_instances


class TestIntegration:
    """Integration tests for complete workflows."""
    
    def test_end_to_end_single_instance(self, tmp_path):
        """Test complete overlay generation for single instance."""
        with patch('generate_rbac_overlays.REPO_ROOT', tmp_path):
            # Create base directory structure
            base_dir = tmp_path / "rbac" / "kustomize" / "base"
            base_dir.mkdir(parents=True)
            
            service_account = "test-sa-argocd-application-controller"
            instances = ["inst1"]
            
            generate_overlays(service_account, instances)
            
            # Verify overlay directory structure
            overlay_dir = tmp_path / "rbac" / "kustomize" / "overlays" / service_account
            assert overlay_dir.exists()
            
            # Verify main kustomization
            main_kustomization = overlay_dir / "kustomization.yaml"
            assert main_kustomization.exists()
            
            # Verify namespace directories
            for pattern in NAMESPACE_PATTERNS:
                namespace = pattern.format(inst="inst1")
                ns_dir = overlay_dir / namespace
                assert ns_dir.exists()
                assert (ns_dir / "kustomization.yaml").exists()
    
    def test_end_to_end_multiple_instances(self, tmp_path):
        """Test complete overlay generation for multiple instances."""
        with patch('generate_rbac_overlays.REPO_ROOT', tmp_path):
            base_dir = tmp_path / "rbac" / "kustomize" / "base"
            base_dir.mkdir(parents=True)
            
            service_account = "multi-sa"
            instances = ["dev", "test", "prod"]
            
            generate_overlays(service_account, instances)
            
            overlay_dir = tmp_path / "rbac" / "kustomize" / "overlays" / service_account
            
            # Verify all instance namespaces were created
            for inst in instances:
                for pattern in NAMESPACE_PATTERNS:
                    namespace = pattern.format(inst=inst)
                    ns_dir = overlay_dir / namespace
                    assert ns_dir.exists(), f"Missing directory for {namespace}"
    
    def test_end_to_end_incremental_updates(self, tmp_path):
        """Test adding instances to existing overlay."""
        with patch('generate_rbac_overlays.REPO_ROOT', tmp_path):
            base_dir = tmp_path / "rbac" / "kustomize" / "base"
            base_dir.mkdir(parents=True)
            
            service_account = "test-sa"
            
            # Generate for first instance
            generate_overlays(service_account, ["inst1"])
            
            overlay_dir = tmp_path / "rbac" / "kustomize" / "overlays" / service_account
            main_kustomization = overlay_dir / "kustomization.yaml"
            content_after_first = main_kustomization.read_text()
            
            # Generate for second instance (should merge)
            generate_overlays(service_account, ["inst2"])
            
            content_after_second = main_kustomization.read_text()
            
            # Both instances should be present
            assert "mas-inst1-core" in content_after_second
            assert "mas-inst2-core" in content_after_second


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

# Made with Bob
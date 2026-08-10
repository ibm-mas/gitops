"""
Pytest configuration and shared fixtures for build/bin tests.

This file provides common fixtures and test utilities used across
multiple test modules.
"""

import pytest
import tempfile
import shutil
from pathlib import Path


@pytest.fixture
def temp_repo_structure(tmp_path):
    """
    Create a temporary repository structure with standard directories.
    
    Returns a dictionary with paths to key directories:
    - root: Repository root
    - cluster_applications: cluster-applications directory
    - instance_applications: instance-applications directory
    - root_applications: root-applications directory
    - sls_applications: sls-applications directory
    """
    structure = {
        'root': tmp_path,
        'cluster_applications': tmp_path / 'cluster-applications',
        'instance_applications': tmp_path / 'instance-applications',
        'root_applications': tmp_path / 'root-applications',
        'sls_applications': tmp_path / 'sls-applications',
    }
    
    # Create directories
    for path in structure.values():
        if path != tmp_path:
            path.mkdir(parents=True, exist_ok=True)
    
    return structure


@pytest.fixture
def sample_helm_chart(tmp_path):
    """
    Create a sample Helm chart with basic structure.
    
    Returns the chart directory path.
    """
    chart_dir = tmp_path / "test-chart"
    chart_dir.mkdir()
    
    # Chart.yaml
    (chart_dir / "Chart.yaml").write_text("""
apiVersion: v2
name: test-chart
version: 1.0.0
description: Test chart for unit tests
""")
    
    # values.yaml
    (chart_dir / "values.yaml").write_text("""
cluster_admin_role: false
application_admin_role: true
""")
    
    # templates directory
    templates_dir = chart_dir / "templates"
    templates_dir.mkdir()
    
    return chart_dir


@pytest.fixture
def sample_configmap_template(tmp_path):
    """
    Create a sample ConfigMap template file.
    
    Returns the template file path.
    """
    template_file = tmp_path / "configmap.yaml"
    template_file.write_text("""
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-config
  namespace: test-namespace
data:
  key: value
""")
    return template_file


@pytest.fixture
def sample_role_template(tmp_path):
    """
    Create a sample Role template with RBAC rules.
    
    Returns the template file path.
    """
    template_file = tmp_path / "role.yaml"
    template_file.write_text("""
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: test-role
  namespace: test-namespace
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - services
  - configmaps
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - apps
  resources:
  - deployments
  - statefulsets
  verbs:
  - create
  - update
  - delete
""")
    return template_file


@pytest.fixture
def sample_application_template(tmp_path):
    """
    Create a sample ArgoCD Application template.
    
    Returns the template file path.
    """
    template_file = tmp_path / "application.yaml"
    template_file.write_text("""
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/repo
    path: charts/test-chart
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: test-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
""")
    return template_file


@pytest.fixture
def sample_readme_root_chart(tmp_path):
    """
    Create a sample README for a root chart (with ArgoCD Applications section).
    
    Returns the README file path.
    """
    readme_file = tmp_path / "README.md"
    readme_file.write_text("""
# Test Root Chart

This is a test chart for ArgoCD Applications.

## ArgoCD Applications

| Template | Application Name | Description |
|----------|------------------|-------------|
| [app1.yaml](templates/app1.yaml) | test-app-1 | First test application |
| [app2.yaml](templates/app2.yaml) | test-app-2 (ApplicationSet) | Second test application |

## Configuration

Some configuration details here.
""")
    return readme_file


@pytest.fixture
def sample_readme_resource_chart(tmp_path):
    """
    Create a sample README for a resource chart (with Resources Created section).
    
    Returns the README file path.
    """
    readme_file = tmp_path / "README.md"
    readme_file.write_text("""
# Test Resource Chart

This chart creates various Kubernetes resources.

## Resources Created

| Resource Type | API Group | Namespaced | Description | Example |
|---------------|-----------|------------|-------------|---------|
| `ConfigMap` | core | Yes | Configuration data | test-config |
| `Secret` | core | Yes | Sensitive data | test-secret |
| `Deployment` | apps | Yes | Application deployment | test-app |
| `Service` | core | Yes | Network service | test-service |

## Usage

Instructions for using this chart.
""")
    return readme_file


@pytest.fixture
def sample_conditional_template(tmp_path):
    """
    Create a template with Helm conditionals.
    
    Returns the template file path.
    """
    template_file = tmp_path / "conditional.yaml"
    template_file.write_text("""
{{- if .Values.application_admin_role }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-admin-config
data:
  role: application-admin
{{- end }}

{{- if .Values.cluster_admin_role }}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-admin-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
{{- end }}

{{- if and .Values.cluster_admin_role .Values.application_admin_role }}
apiVersion: v1
kind: Service
metadata:
  name: both-roles-service
spec:
  type: ClusterIP
  ports:
  - port: 80
{{- end }}
""")
    return template_file


@pytest.fixture
def mock_yaml_files(tmp_path):
    """
    Create a set of mock YAML files for testing.
    
    Returns a dictionary mapping file names to their paths.
    """
    files = {}
    
    # Valid YAML
    files['valid'] = tmp_path / "valid.yaml"
    files['valid'].write_text("apiVersion: v1\nkind: ConfigMap\n")
    
    # Invalid YAML
    files['invalid'] = tmp_path / "invalid.yaml"
    files['invalid'].write_text("{{- invalid yaml syntax\n")
    
    # Empty file
    files['empty'] = tmp_path / "empty.yaml"
    files['empty'].write_text("")
    
    # Multi-document YAML
    files['multi'] = tmp_path / "multi.yaml"
    files['multi'].write_text("""
apiVersion: v1
kind: ConfigMap
---
apiVersion: v1
kind: Secret
---
apiVersion: apps/v1
kind: Deployment
""")
    
    return files


@pytest.fixture
def rbac_overlay_structure(tmp_path):
    """
    Create a temporary RBAC overlay directory structure.
    
    Returns a dictionary with paths to key directories:
    - root: Repository root
    - rbac: rbac directory
    - kustomize: kustomize directory
    - base: kustomize base directory
    - overlays: kustomize overlays directory
    - components: kustomize components directory
    """
    structure = {
        'root': tmp_path,
        'rbac': tmp_path / 'rbac',
        'kustomize': tmp_path / 'rbac' / 'kustomize',
        'base': tmp_path / 'rbac' / 'kustomize' / 'base',
        'overlays': tmp_path / 'rbac' / 'kustomize' / 'overlays',
        'components': tmp_path / 'rbac' / 'kustomize' / 'components',
    }
    
    # Create directories
    for path in structure.values():
        path.mkdir(parents=True, exist_ok=True)
    
    # Create minimal base kustomization
    base_kustomization = structure['base'] / 'kustomization.yaml'
    base_kustomization.write_text("""---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - application-admin-role.yaml
  - application-admin-rolebinding.yaml
""")
    
    # Create minimal base role
    base_role = structure['base'] / 'application-admin-role.yaml'
    base_role.write_text("""---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: mas-application-admin
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
""")
    
    # Create minimal base rolebinding
    base_rolebinding = structure['base'] / 'application-admin-rolebinding.yaml'
    base_rolebinding.write_text("""---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: mas-application-admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: mas-application-admin
subjects:
- kind: ServiceAccount
  name: placeholder
  namespace: placeholder
""")
    
    # Create cluster-readonly component
    cluster_readonly_dir = structure['components'] / 'cluster-readonly'
    cluster_readonly_dir.mkdir(parents=True, exist_ok=True)
    
    cluster_readonly_kustomization = cluster_readonly_dir / 'kustomization.yaml'
    cluster_readonly_kustomization.write_text("""---
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
resources:
  - application-admin-clusterrole-readonly.yaml
  - application-admin-clusterrolebinding.yaml
""")
    
    return structure


@pytest.fixture
def sample_service_accounts():
    """
    Provide sample service account names for testing.
    
    Returns a dictionary with various service account scenarios.
    """
    return {
        'standard': 'mas-argocd-argocd-application-controller',
        'custom': 'custom-service-account',
        'short': 'sa',
        'with_namespace': 'my-namespace-argocd-application-controller',
        'no_suffix': 'plain-service-account',
    }


@pytest.fixture
def sample_instance_ids():
    """
    Provide sample instance IDs for testing.
    
    Returns a list of valid instance IDs.
    """
    return ['inst1', 'dev', 'test', 'prod', 'my-inst', 'inst_123']


@pytest.fixture
def sample_kustomization_with_resources(tmp_path):
    """
    Create a sample kustomization.yaml with existing resources.
    
    Returns the kustomization file path.
    """
    kustomization_file = tmp_path / 'kustomization.yaml'
    kustomization_file.write_text("""---
# Kustomize overlay for test-sa in test-namespace
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./existing-ns1
  - ./existing-ns2
  - ./existing-ns3
components:
  - ../../components/cluster-readonly
patches:
  - target:
      kind: ClusterRoleBinding
      name: mas-application-admin-readonly
    patch: |-
      - op: replace
        path: /metadata/name
        value: mas-application-admin-readonly-test-sa
  - target:
      kind: RoleBinding
      name: mas-application-admin-binding
    patch: |-
      - op: replace
        path: /subjects/0/name
        value: test-sa
      - op: replace
        path: /subjects/0/namespace
        value: test-namespace
""")
    return kustomization_file


# Pytest markers for test categorization
def pytest_configure(config):
    """Register custom markers."""
    config.addinivalue_line(
        "markers", "unit: Unit tests for individual functions"
    )
    config.addinivalue_line(
        "markers", "integration: Integration tests for complete workflows"
    )
    config.addinivalue_line(
        "markers", "slow: Tests that take longer to run"
    )
    config.addinivalue_line(
        "markers", "requires_filesystem: Tests that require filesystem access"
    )

# Made with Bob

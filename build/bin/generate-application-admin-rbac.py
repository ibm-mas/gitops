#!/usr/bin/env python3
"""
Generate RBAC ClusterRole for application_admin_role deployments.

This script analyzes all Helm charts in cluster-applications,
instance-applications, root-applications, and sls-applications to
identify OpenShift resources that need permissions when
cluster_admin_role=false and application_admin_role=true.
"""

import re
import yaml
from pathlib import Path
from collections import defaultdict
from typing import Set, Dict, List, Tuple, Optional

# Base directory
REPO_ROOT = Path(__file__).parent.parent.parent

# Directories to scan
SCAN_DIRS = [
    "cluster-applications",
    "instance-applications", 
    "root-applications",
    "sls-applications"
]

# Resource types that require cluster-admin (excluded from application-admin)
CLUSTER_ADMIN_ONLY_RESOURCES = {
    "ClusterRole",
    "ClusterRoleBinding",
    "SecurityContextConstraints",
    "CustomResourceDefinition",
    "MutatingWebhookConfiguration",
    "ValidatingWebhookConfiguration",
    "APIService",
    "ClusterOperator",
    "Console",
    "ConsoleCLIDownload",
    "ConsoleLink",
    "ConsoleNotification",
    "ConsoleQuickStart",
    "ConsoleYAMLSample",
    "ImageContentSourcePolicy",
    "ImageDigestMirrorSet",
    "ImageTagMirrorSet",
    "OperatorHub",
    "Proxy",
    "Scheduler",
    "StorageClass",
    "CSIDriver",
    "CSINode",
    "VolumeAttachment",
    "PriorityClass",
    "RuntimeClass",
    "PodSecurityPolicy",
    "ClusterIssuer",  # cert-manager
    "IngressController",  # OpenShift ingress
}


def get_parent_app_conditional(template_file: Path) -> Optional[str]:
    """
    Find the parent ArgoCD Application file and check for conditionals.
    Returns 'cluster_admin_role', 'application_admin_role', or None.
    """
    # Determine which chart this template belongs to
    chart_path = None
    scan_dir = None
    for parent in template_file.parents:
        if parent.name in SCAN_DIRS:
            # Get chart directory (e.g., cluster-applications/020-ibm-dro)
            chart_path = template_file.relative_to(parent).parts[0]
            scan_dir = parent.name
            break
    
    if not chart_path or not scan_dir:
        return None
    
    # Look for parent Application in root-applications
    root_apps_dir = REPO_ROOT / "root-applications"
    if not root_apps_dir.exists():
        return None
    
    # Search for Application files that reference this chart
    for app_file in root_apps_dir.rglob("*.yaml"):
        try:
            with open(app_file, 'r') as f:
                content = f.read()
                
            # Check if this app references our chart
            chart_ref = f"{scan_dir}/{chart_path}"
            if chart_ref not in content:
                continue
            
            # Check for conditionals in the Application file
            # Look for {{- if .Values.cluster_admin_role }} or similar
            cluster_pattern = (
                r'\{\{-\s*if\s+.*\.Values\.cluster_admin_role\s*\}\}'
            )
            app_pattern = (
                r'\{\{-\s*if\s+.*\.Values\.application_admin_role\s*\}\}'
            )
            cluster_and_pattern = (
                r'\{\{-\s*if\s+and\s+.*\.Values\.cluster_admin_role'
            )
            app_and_pattern = (
                r'\{\{-\s*if\s+and\s+.*\.Values\.application_admin_role'
            )
            
            if re.search(cluster_pattern, content):
                return 'cluster_admin_role'
            elif re.search(app_pattern, content):
                return 'application_admin_role'
            # Check for 'and' conditions
            elif re.search(cluster_and_pattern, content):
                return 'cluster_admin_role'
            elif re.search(app_and_pattern, content):
                return 'application_admin_role'
                
        except Exception:
            continue
    
    return None


def extract_resources_from_yaml(
    file_path: Path
) -> Tuple[List[Tuple[str, str, str]], List[Tuple[str, str, str]]]:
    """
    Extract Kubernetes resource types from a YAML file.
    Returns tuple of (kinds, rbac_resources) where:
    - kinds: list of (kind, apiVersion, conditional) tuples
    - rbac_resources: list of (resource_name, apiGroup, conditional) tuples
      extracted from Role/ClusterRole rules
    """
    kinds = []
    rbac_resources = []
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            
        # Check for helm conditionals at file level
        # Scan the entire file, not just the first few lines
        file_conditional = None
        for line in content.split('\n'):
            if '{{- if' in line:
                # Check for both conditions in the same line
                has_cluster = 'cluster_admin_role' in line
                has_app = 'application_admin_role' in line
                
                if has_cluster and has_app:
                    # Both conditions present - check if it's AND or OR
                    if ' and ' in line.lower():
                        # For 'and', both must be true, so it's in 'both'
                        file_conditional = 'both'
                    else:
                        # For 'or' or other cases, also treat as 'both'
                        file_conditional = 'both'
                elif has_cluster:
                    file_conditional = 'cluster_admin_role'
                elif has_app:
                    file_conditional = 'application_admin_role'
                break
        
        # If no conditional found in template, check parent Application
        if file_conditional is None:
            parent_conditional = get_parent_app_conditional(file_path)
            if parent_conditional:
                file_conditional = parent_conditional
        
        # Parse YAML documents
        try:
            docs = yaml.safe_load_all(content)
            for doc in docs:
                if doc and isinstance(doc, dict):
                    kind = doc.get('kind')
                    api_version = doc.get('apiVersion', '')
                    if kind:
                        kinds.append((kind, api_version, file_conditional))
                        
                        # If Role or ClusterRole, extract resources from rules
                        if kind in ('Role', 'ClusterRole'):
                            rules = doc.get('rules', [])
                            for rule in rules:
                                if isinstance(rule, dict):
                                    api_groups = rule.get('apiGroups', [])
                                    rule_resources = rule.get('resources', [])
                                    
                                    for resource in rule_resources:
                                        # Skip subresources (e.g., pods/exec)
                                        if '/' in resource:
                                            continue
                                        
                                        # Add resource for each API group
                                        for api_group in api_groups:
                                            rbac_resources.append((
                                                resource,
                                                api_group,
                                                file_conditional
                                            ))
        except yaml.YAMLError:
            # YAML parsing failed - use regex for Kinds
            kind_matches = re.findall(
                r'^kind:\s+(\w+)', content, re.MULTILINE
            )
            api_matches = re.findall(
                r'^apiVersion:\s+([\w./]+)', content, re.MULTILINE
            )
            
            for i, kind in enumerate(kind_matches):
                api_version = api_matches[i] if i < len(api_matches) else ''
                kinds.append((kind, api_version, file_conditional))
        
        # Always try regex extraction for RBAC resources from
        # Role/ClusterRole rules (works even with Helm templates)
        if 'kind: Role' in content or 'kind: ClusterRole' in content:
            # Extract rules sections using regex
            # Match: - apiGroups: ... resources: ...
            rules_pattern = (
                r'- apiGroups:\s*\n\s*-\s*["\']?([^"\'\n]*)["\']?\s*\n'
                r'(?:.*\n)*?'
                r'\s*resources:\s*\n((?:\s*-\s*[^\n]+\n)+)'
            )
            
            for match in re.finditer(rules_pattern, content):
                api_group = match.group(1).strip()
                resources_block = match.group(2)
                
                # Extract individual resources
                resource_matches = re.findall(
                    r'^\s*-\s*["\']?([^"\'\s#]+)["\']?',
                    resources_block,
                    re.MULTILINE
                )
                
                for resource in resource_matches:
                    # Skip subresources, comments, and template vars
                    if ('/' in resource or resource.startswith('#') or
                            resource.startswith('{{')):
                        continue
                    
                    rbac_resources.append((
                        resource,
                        api_group,
                        file_conditional
                    ))
                
    except Exception as e:
        print(f"Warning: Could not process {file_path}: {e}")
    
    return kinds, rbac_resources


def scan_helm_charts() -> Tuple[
    Dict[str, Set[Tuple[str, str]]],
    Dict[str, Set[Tuple[str, str]]]
]:
    """
    Scan all Helm charts and categorize resources by their conditions.
    Returns tuple of (kinds_categorized, rbac_resources_categorized).
    Each dict has keys: 'cluster_admin', 'application_admin',
    'both', 'none'
    """
    kinds_categorized = {
        'cluster_admin': set(),
        'application_admin': set(),
        'both': set(),
        'none': set()
    }
    
    rbac_resources_categorized = {
        'cluster_admin': set(),
        'application_admin': set(),
        'both': set(),
        'none': set()
    }
    
    for scan_dir in SCAN_DIRS:
        dir_path = REPO_ROOT / scan_dir
        if not dir_path.exists():
            continue
            
        # Find all template files (.yaml and .yml)
        yaml_files = list(dir_path.rglob('templates/*.yaml'))
        yml_files = list(dir_path.rglob('templates/*.yml'))
        for template_file in yaml_files + yml_files:
            kinds, rbac_resources = extract_resources_from_yaml(template_file)
            
            # Process Kinds
            for kind, api_version, conditional in kinds:
                resource_tuple = (kind, api_version)
                
                # Categorize based on conditional
                if conditional == 'cluster_admin_role':
                    kinds_categorized['cluster_admin'].add(resource_tuple)
                elif conditional == 'application_admin_role':
                    kinds_categorized['application_admin'].add(resource_tuple)
                elif conditional == 'both':
                    kinds_categorized['both'].add(resource_tuple)
                elif conditional is None:
                    kinds_categorized['none'].add(resource_tuple)
            
            # Process RBAC resources
            for resource_name, api_group, conditional in rbac_resources:
                resource_tuple = (resource_name, api_group)
                
                # Categorize based on conditional
                if conditional == 'cluster_admin_role':
                    rbac_resources_categorized['cluster_admin'].add(
                        resource_tuple
                    )
                elif conditional == 'application_admin_role':
                    rbac_resources_categorized['application_admin'].add(
                        resource_tuple
                    )
                elif conditional == 'both':
                    rbac_resources_categorized['both'].add(resource_tuple)
                elif conditional is None:
                    rbac_resources_categorized['none'].add(resource_tuple)
    
    return kinds_categorized, rbac_resources_categorized


def generate_rbac_rules(
    kinds_categorized: Dict[str, Set[Tuple[str, str]]],
    rbac_resources_categorized: Dict[str, Set[Tuple[str, str]]]
) -> List[Dict]:
    """Generate RBAC rules for application_admin_role."""
    
    # Resources that application_admin can manage from Kinds
    # Include: application_admin, both, and none
    # Only exclude resources that are ONLY in cluster_admin
    # (not in application_admin)
    manageable_kinds = (
        kinds_categorized['application_admin'] |
        kinds_categorized['both'] |
        kinds_categorized['none']
    )
    
    # Resources from RBAC rules
    # Only exclude resources that are ONLY in cluster_admin
    # (not in application_admin)
    manageable_rbac_resources = (
        rbac_resources_categorized['application_admin'] |
        rbac_resources_categorized['both'] |
        rbac_resources_categorized['none']
    )
    
    # Group by API group
    api_groups = defaultdict(set)
    
    # Process Kinds (convert to resource names)
    for kind, api_version in manageable_kinds:
        if kind in CLUSTER_ADMIN_ONLY_RESOURCES:
            continue
            
        # Extract API group from apiVersion
        if '/' in api_version:
            group = api_version.split('/')[0]
        else:
            group = ""  # Core API group
        
        # Convert Kind to resource name (lowercase, pluralized)
        resource = kind.lower()
        if not resource.endswith('s'):
            # Simple pluralization
            if resource.endswith('y'):
                resource = resource[:-1] + 'ies'
            elif resource.endswith(('s', 'x', 'z', 'ch', 'sh')):
                resource = resource + 'es'
            else:
                resource = resource + 's'
        
        api_groups[group].add(resource)
    
    # Process RBAC resources (already in resource name format)
    for resource_name, api_group in manageable_rbac_resources:
        api_groups[api_group].add(resource_name)
    
    # Generate rules
    rules = []
    
    # Core resources (empty API group)
    if "" in api_groups:
        rules.append({
            "apiGroups": [""],
            "resources": sorted(list(api_groups[""])),
            "verbs": [
                "create", "delete", "get", "list",
                "patch", "update", "watch"
            ]
        })
    
    # Other API groups
    for group in sorted(api_groups.keys()):
        if group == "":
            continue
        rules.append({
            "apiGroups": [group],
            "resources": sorted(list(api_groups[group])),
            "verbs": [
                "create", "delete", "get", "list",
                "patch", "update", "watch"
            ]
        })
    
    return rules


def main():
    print("Scanning Helm charts for OpenShift resources...")
    kinds_cat, rbac_res_cat = scan_helm_charts()
    
    print("\nFound Kinds:")
    print(f"  - Cluster admin only: {len(kinds_cat['cluster_admin'])}")
    print(f"  - Application admin: {len(kinds_cat['application_admin'])}")
    print(f"  - Both roles: {len(kinds_cat['both'])}")
    print(f"  - No condition: {len(kinds_cat['none'])}")
    
    print("\nFound RBAC resources:")
    print(f"  - Cluster admin only: {len(rbac_res_cat['cluster_admin'])}")
    print(f"  - Application admin: "
          f"{len(rbac_res_cat['application_admin'])}")
    print(f"  - Both roles: {len(rbac_res_cat['both'])}")
    print(f"  - No condition: {len(rbac_res_cat['none'])}")
    
    print("\nGenerating RBAC rules...")
    rules = generate_rbac_rules(kinds_cat, rbac_res_cat)
    
    # Create Role YAML for namespace-scoped resources
    role = {
        "apiVersion": "rbac.authorization.k8s.io/v1",
        "kind": "Role",
        "metadata": {
            "name": "mas-application-admin",
            "annotations": {
                "description": (
                    "Role for MAS GitOps deployments when "
                    "cluster_admin_role=false and "
                    "application_admin_role=true"
                )
            }
        },
        "rules": rules
    }
    
    # Create ClusterRole YAML for read-only cluster access
    cluster_role = {
        "apiVersion": "rbac.authorization.k8s.io/v1",
        "kind": "ClusterRole",
        "metadata": {
            "name": "mas-application-admin-readonly",
            "annotations": {
                "description": (
                    "ClusterRole for read-only cluster access when "
                    "cluster_admin_role=false and "
                    "application_admin_role=true"
                )
            }
        },
        "rules": [
            {
                "apiGroups": [""],
                "resources": ["namespaces", "nodes"],
                "verbs": ["get", "list", "watch"]
            },
            {
                "apiGroups": ["storage.k8s.io"],
                "resources": ["storageclasses"],
                "verbs": ["get", "list", "watch"]
            }
        ]
    }
    
    # Write Role to kustomize base
    role_file = (
        REPO_ROOT / "rbac" / "kustomize" / "base" /
        "application-admin-role.yaml"
    )
    role_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(role_file, 'w') as f:
        f.write("# Generated by "
                "build/bin/generate-application-admin-rbac.py\n")
        f.write("# This Role defines permissions needed for MAS GitOps "
                "deployments\n")
        f.write("# when cluster_admin_role=false and "
                "application_admin_role=true\n")
        f.write("---\n")
        yaml.dump(role, f, default_flow_style=False, sort_keys=False)
    
    # Write ClusterRole to kustomize component
    cluster_role_file = (
        REPO_ROOT / "rbac" / "kustomize" / "components" /
        "cluster-readonly" /
        "application-admin-clusterrole-readonly.yaml"
    )
    cluster_role_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(cluster_role_file, 'w') as f:
        f.write("# Generated by "
                "build/bin/generate-application-admin-rbac.py\n")
        f.write("# This ClusterRole provides read-only cluster access\n")
        f.write("# when cluster_admin_role=false and "
                "application_admin_role=true\n")
        f.write("---\n")
        yaml.dump(cluster_role, f, default_flow_style=False,
                  sort_keys=False)
    
    print("\nGenerated RBAC files:")
    print(f"  - Role: {role_file}")
    print(f"  - ClusterRole: {cluster_role_file}")
    print(f"Total rules in Role: {len(rules)}")
    
    # Print summary
    print("\nKind summary by condition:")
    for category, resources in kinds_cat.items():
        if resources:
            print(f"\n{category.upper()}:")
            for kind, api_version in sorted(resources):
                print(f"  - {kind} ({api_version})")
    
    print("\nRBAC resource summary by condition:")
    for category, resources in rbac_res_cat.items():
        if resources:
            print(f"\n{category.upper()}:")
            for resource, api_group in sorted(resources):
                print(f"  - {resource} ({api_group})")


if __name__ == "__main__":
    main()

# Made with Bob

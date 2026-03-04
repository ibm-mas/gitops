#!/usr/bin/env python3
"""
Generate RBAC ClusterRole for application_admin_role deployments.

This script analyzes all Helm charts in cluster-applications, instance-applications,
root-applications, and sls-applications to identify OpenShift resources that need
permissions when cluster_admin_role=false and application_admin_role=true.
"""

import os
import re
import yaml
from pathlib import Path
from collections import defaultdict
from typing import Set, Dict, List, Tuple

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

def extract_resources_from_yaml(file_path: Path) -> List[Tuple[str, str, str]]:
    """
    Extract Kubernetes resource types from a YAML file.
    Returns list of (kind, apiVersion, conditional) tuples.
    """
    resources = []
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            
        # Check for helm conditionals at file level
        file_conditional = None
        first_lines = content.split('\n')[:5]
        for line in first_lines:
            if '{{- if' in line:
                if 'cluster_admin_role' in line:
                    file_conditional = 'cluster_admin_role'
                elif 'application_admin_role' in line:
                    file_conditional = 'application_admin_role'
                break
        
        # Parse YAML documents
        try:
            docs = yaml.safe_load_all(content)
            for doc in docs:
                if doc and isinstance(doc, dict):
                    kind = doc.get('kind')
                    api_version = doc.get('apiVersion', '')
                    if kind:
                        resources.append((kind, api_version, file_conditional))
        except yaml.YAMLError:
            # If YAML parsing fails due to templates, try regex extraction
            kind_matches = re.findall(r'^kind:\s+(\w+)', content, re.MULTILINE)
            api_matches = re.findall(r'^apiVersion:\s+([\w./]+)', content, re.MULTILINE)
            
            for i, kind in enumerate(kind_matches):
                api_version = api_matches[i] if i < len(api_matches) else ''
                resources.append((kind, api_version, file_conditional))
                
    except Exception as e:
        print(f"Warning: Could not process {file_path}: {e}")
    
    return resources

def scan_helm_charts() -> Dict[str, Set[Tuple[str, str]]]:
    """
    Scan all Helm charts and categorize resources by their conditions.
    Returns dict with keys: 'cluster_admin', 'application_admin', 'both', 'none'
    """
    categorized = {
        'cluster_admin': set(),
        'application_admin': set(),
        'both': set(),
        'none': set()
    }
    
    for scan_dir in SCAN_DIRS:
        dir_path = REPO_ROOT / scan_dir
        if not dir_path.exists():
            continue
            
        # Find all template files
        for template_file in dir_path.rglob('templates/*.yaml'):
            resources = extract_resources_from_yaml(template_file)
            
            for kind, api_version, conditional in resources:
                resource_tuple = (kind, api_version)
                
                # Categorize based on conditional
                if conditional == 'cluster_admin_role':
                    categorized['cluster_admin'].add(resource_tuple)
                elif conditional == 'application_admin_role':
                    categorized['application_admin'].add(resource_tuple)
                elif conditional is None:
                    categorized['none'].add(resource_tuple)
                else:
                    categorized['both'].add(resource_tuple)
        
        # Also scan .yml files
        for template_file in dir_path.rglob('templates/*.yml'):
            resources = extract_resources_from_yaml(template_file)
            
            for kind, api_version, conditional in resources:
                resource_tuple = (kind, api_version)
                
                if conditional == 'cluster_admin_role':
                    categorized['cluster_admin'].add(resource_tuple)
                elif conditional == 'application_admin_role':
                    categorized['application_admin'].add(resource_tuple)
                elif conditional is None:
                    categorized['none'].add(resource_tuple)
                else:
                    categorized['both'].add(resource_tuple)
    
    return categorized

def generate_rbac_rules(categorized: Dict[str, Set[Tuple[str, str]]]) -> List[Dict]:
    """Generate RBAC rules for application_admin_role."""
    
    # Resources that application_admin can manage
    # (excludes cluster_admin_only and resources with cluster_admin_role condition)
    manageable_resources = (
        categorized['application_admin'] | 
        categorized['both'] | 
        categorized['none']
    ) - categorized['cluster_admin']
    
    # Group by API group
    api_groups = defaultdict(set)
    for kind, api_version in manageable_resources:
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
    
    # Generate rules
    rules = []
    
    # Core resources (empty API group)
    if "" in api_groups:
        rules.append({
            "apiGroups": [""],
            "resources": sorted(list(api_groups[""])),
            "verbs": ["create", "delete", "get", "list", "patch", "update", "watch"]
        })
    
    # Other API groups
    for group in sorted(api_groups.keys()):
        if group == "":
            continue
        rules.append({
            "apiGroups": [group],
            "resources": sorted(list(api_groups[group])),
            "verbs": ["create", "delete", "get", "list", "patch", "update", "watch"]
        })
    
    return rules

def main():
    print("Scanning Helm charts for OpenShift resources...")
    categorized = scan_helm_charts()
    
    print(f"\nFound resources:")
    print(f"  - Cluster admin only: {len(categorized['cluster_admin'])}")
    print(f"  - Application admin: {len(categorized['application_admin'])}")
    print(f"  - Both roles: {len(categorized['both'])}")
    print(f"  - No condition: {len(categorized['none'])}")
    
    print("\nGenerating RBAC rules...")
    rules = generate_rbac_rules(categorized)
    
    # Create ClusterRole YAML
    cluster_role = {
        "apiVersion": "rbac.authorization.k8s.io/v1",
        "kind": "ClusterRole",
        "metadata": {
            "name": "mas-application-admin",
            "annotations": {
                "description": "ClusterRole for MAS GitOps deployments when cluster_admin_role=false and application_admin_role=true"
            }
        },
        "rules": rules
    }
    
    # Write to file
    output_file = REPO_ROOT / "cluster-applications" / "061-ibm-rbac" / "templates" / "cluster-roles" / "application-admin.yaml"
    output_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_file, 'w') as f:
        f.write("# Generated by build/bin/generate-application-admin-rbac.py\n")
        f.write("# This ClusterRole defines permissions needed for MAS GitOps deployments\n")
        f.write("# when cluster_admin_role=false and application_admin_role=true\n")
        f.write("---\n")
        yaml.dump(cluster_role, f, default_flow_style=False, sort_keys=False)
    
    print(f"\nGenerated RBAC file: {output_file}")
    print(f"Total rules: {len(rules)}")
    
    # Print summary
    print("\nResource summary by condition:")
    for category, resources in categorized.items():
        if resources:
            print(f"\n{category.upper()}:")
            for kind, api_version in sorted(resources):
                print(f"  - {kind} ({api_version})")

if __name__ == "__main__":
    main()

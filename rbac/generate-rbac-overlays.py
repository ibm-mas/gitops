#!/usr/bin/env python3
"""
Generate Kustomize overlay directories for RBAC across MAS instances.

This script creates namespace-specific overlay directories for each instance,
allowing Kustomize to apply RBAC resources to multiple namespaces.

Usage:
    ./rbac/generate-rbac-overlays.py \
        --service-account <sa-name> inst1 inst2 inst3

The --service-account argument is required.  It should be the name of the
ArgoCD service account that will be granted access, e.g.:

    mas-argocd-argocd-application-controller

The namespace for the service account is derived automatically by stripping
the trailing '-argocd-application-controller' suffix (if present).

This will generate overlay directories for all namespaces across the
specified instances.
"""

import argparse
import re
import sys
import textwrap
from pathlib import Path

# Repository root (parent of rbac/)
REPO_ROOT = Path(__file__).parent.parent

# Namespace patterns per instance ({inst} is replaced with the instance ID)
NAMESPACE_PATTERNS = [
    "db2u-{inst}",
    "mas-{inst}-core",
    "mas-{inst}-manage",
    "mas-{inst}-sls",
    "mas-{inst}-syncres",
    "mas-{inst}-visualinspection",
]


def generate_namespace_overlay(overlay_dir: Path, namespace: str) -> None:
    """
    Generate a single namespace overlay directory with kustomization.yaml.
    """
    ns_dir = overlay_dir / namespace
    ns_dir.mkdir(parents=True, exist_ok=True)
    
    kustomization = textwrap.dedent(f"""\
        ---
        apiVersion: kustomize.config.k8s.io/v1beta1
        kind: Kustomization
        namespace: {namespace}
        resources:
          - ../../../base

        
        """)
    
    (ns_dir / "kustomization.yaml").write_text(kustomization)
    print(f"  ✓ Created {ns_dir}/kustomization.yaml")


def _derive_sa_namespace(service_account: str) -> str:
    """
    Derive the Kubernetes namespace that owns the service account.

    Strips the trailing '-argocd-application-controller' suffix if present,
    otherwise returns the service account name unchanged.
    """
    suffix = "-argocd-application-controller"
    if service_account.endswith(suffix):
        return service_account[: -len(suffix)]
    return service_account


def _create_main_kustomization(
    kustomization_file: Path, service_account: str, namespaces: list[str]
) -> None:
    """
    Create a new root kustomization.yaml from the standard template.
    """
    sa_namespace = _derive_sa_namespace(service_account)
    resources_block = "\n".join(
        f"  - ./{ns}" for ns in sorted(namespaces)
    )
    header = textwrap.dedent(f"""\
        ---
        # Kustomize overlay for {service_account} in {sa_namespace}
        #
        # This overlay generates:
        #   - Role in each target namespace
        #   - RoleBinding in each target namespace (bound to {service_account})
        #   - ClusterRoleBinding for read-only cluster access
        #
        # To add more instances, use the generator script:
        #   ./rbac/generate-rbac-overlays.py inst1 inst2 inst3
        #
        # This will automatically create namespace overlay directories
        # and update the resources list below.
        #
        # Apply with:
        #   kubectl apply -k rbac/kustomize/overlays/{service_account}
        #
        apiVersion: kustomize.config.k8s.io/v1beta1
        kind: Kustomization
        resources:
        """)
    footer = textwrap.dedent(f"""\
        components:
          - ../../components/cluster-readonly
        patches:
          # Patch the ClusterRoleBinding name to include the SA name
          # to avoid conflicts when multiple service accounts are configured
          - target:
              kind: ClusterRoleBinding
              name: mas-application-admin-readonly
            patch: |-
              - op: replace
                path: /metadata/name
                value: mas-application-admin-readonly-{service_account}
          # Patch the RoleBinding subjects to use the correct service account
          - target:
              kind: RoleBinding
              name: mas-application-admin-binding
            patch: |-
              - op: replace
                path: /subjects/0/name
                value: {service_account}
              - op: replace
                path: /subjects/0/namespace
                value: {sa_namespace}
          # Patch the ClusterRoleBinding subjects to use the correct SA
          - target:
              kind: ClusterRoleBinding
              name: mas-application-admin-readonly
            patch: |-
              - op: replace
                path: /subjects/0/name
                value: {service_account}
              - op: replace
                path: /subjects/0/namespace
                value: {sa_namespace}

        
        """)
    content = header + resources_block + "\n" + footer
    kustomization_file.write_text(content)
    print(f"  ✓ Created {kustomization_file}")


def update_main_kustomization(
    overlay_dir: Path, service_account: str, namespaces: list[str]
) -> None:
    """
    Update the main kustomization.yaml with the list of namespace
    directories, merging with any existing entries.  If the file does not
    yet exist it is created from the standard template.
    """
    kustomization_file = overlay_dir / "kustomization.yaml"

    if not kustomization_file.exists():
        _create_main_kustomization(
            kustomization_file, service_account, namespaces
        )
        return

    content = kustomization_file.read_text()
    
    # Extract existing resources entries from the current resources block
    pattern = r"resources:(.*?)(?=components:)"
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print(
            f"Error: Could not find 'resources:' section in "
            f"{kustomization_file}"
        )
        sys.exit(1)
    
    existing_block = match.group(1)
    existing_entries = re.findall(
        r"^\s+-\s+(\S+)", existing_block, re.MULTILINE
    )
    
    # Merge existing entries with new namespaces (deduplicate, preserve order)
    new_entries = {f"./{ns}" for ns in namespaces}
    merged = sorted(set(existing_entries) | new_entries)
    
    # Build updated resources block
    resources_lines = ["resources:"]
    for entry in merged:
        resources_lines.append(f"  - {entry}")
    new_resources = "\n".join(resources_lines) + "\n"
    
    updated_content = re.sub(pattern, new_resources, content, flags=re.DOTALL)
    kustomization_file.write_text(updated_content)
    print(f"  ✓ Updated {kustomization_file}")


def generate_overlays(service_account: str, instances: list[str]) -> None:
    """Generate overlay directories for all instances."""
    overlay_dir = (
        REPO_ROOT / "rbac" / "kustomize" / "overlays" / service_account
    )

    if not overlay_dir.exists():
        overlay_dir.mkdir(parents=True, exist_ok=True)
        print(f"  ✓ Created overlay directory {overlay_dir}")
    
    # Generate list of all namespaces across all instances
    namespaces = []
    for inst in instances:
        for pattern in NAMESPACE_PATTERNS:
            namespace = pattern.format(inst=inst)
            namespaces.append(namespace)
    
    print(f"\nGenerating RBAC overlays for {len(instances)} instance(s):")
    print(f"  Instances: {', '.join(instances)}")
    print(f"  Total namespaces: {len(namespaces)}")
    print()
    
    # Generate each namespace overlay
    for namespace in namespaces:
        generate_namespace_overlay(overlay_dir, namespace)
    
    # Update main kustomization.yaml
    update_main_kustomization(overlay_dir, service_account, namespaces)
    
    print(
        f"\n✅ Successfully generated overlays for "
        f"{len(namespaces)} namespaces"
    )
    print("\nTo apply:")
    print(f"  kubectl apply -k {overlay_dir}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate Kustomize RBAC overlays for MAS instances",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            Examples:
              # Generate overlays for inst1 (ArgoCD in mas-argocd namespace)
              ./rbac/generate-rbac-overlays.py \\
                  --service-account \\
                  mas-argocd-argocd-application-controller inst1

              # Generate overlays for multiple instances
              ./rbac/generate-rbac-overlays.py \\
                  --service-account \\
                  mas-argocd-argocd-application-controller inst1 inst2 inst3

              # Custom service account overlay
              ./rbac/generate-rbac-overlays.py \\
                  --service-account my-custom-sa inst1

            This will create overlay directories for:
              - db2u-{inst}
              - mas-{inst}-core
              - mas-{inst}-manage
              - mas-{inst}-sls
              - mas-{inst}-syncres
              - mas-{inst}-visualinspection
            """)
    )
    
    parser.add_argument(
        "instances",
        nargs="+",
        help="Instance IDs to generate overlays for (e.g., inst1 inst2)"
    )
    
    parser.add_argument(
        "--service-account",
        required=True,
        help=(
            "Service account name (required). "
            "The namespace is derived by stripping the trailing "
            "'-argocd-application-controller' suffix, e.g. "
            "'mas-argocd-argocd-application-controller' "
            "-> namespace 'mas-argocd'."
        ),
    )
    
    args = parser.parse_args()
    
    # Validate instance IDs (simple alphanumeric check)
    for inst in args.instances:
        if not re.match(r'^[a-zA-Z0-9_-]+$', inst):
            print(
                f"Error: Invalid instance ID '{inst}'. "
                f"Use alphanumeric characters, hyphens, or underscores."
            )
            sys.exit(1)
    
    generate_overlays(args.service_account, args.instances)


if __name__ == "__main__":
    main()
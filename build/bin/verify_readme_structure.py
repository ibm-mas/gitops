#!/usr/bin/env python3
"""
Verify README structure compliance with documentation standards.

This script validates that README.md files follow the standardized template
structure defined in docs/root-application-readme-template.md.

Usage:
    python build/bin/verify_readme_structure.py [files...]
    
    If no files are specified, validates all README.md files in the repository.
"""

import argparse
import re
import sys
from pathlib import Path
from typing import List, Dict, Set, Tuple


class ReadmeValidator:
    """Validates README.md files against template requirements."""
    
    # Required sections for root applications
    ROOT_APP_REQUIRED_SECTIONS = [
        "# ",  # Title
        "## Overview",
        "## Configuration Files",
        "## Helm Parameters",
        "## Values Configuration",
        "## ArgoCD Applications",
        "## Examples",
    ]
    
    # Required sections for cluster/instance applications
    CHART_REQUIRED_SECTIONS = [
        "# ",  # Title
        "## Overview",
        "## Configuration",
        "## Resources Created",
        "## Examples",
    ]
    
    # Optional but recommended sections
    RECOMMENDED_SECTIONS = [
        "## Prerequisites",
        "## Troubleshooting",
        "## Related Documentation",
    ]
    
    def __init__(self, strict: bool = False):
        """
        Initialize validator.
        
        Args:
            strict: If True, treat warnings as errors
        """
        self.strict = strict
        self.errors: List[str] = []
        self.warnings: List[str] = []
    
    def validate_file(self, filepath: Path) -> bool:
        """
        Validate a single README file.
        
        Args:
            filepath: Path to README.md file
            
        Returns:
            True if validation passes, False otherwise
        """
        self.errors = []
        self.warnings = []
        
        if not filepath.exists():
            self.errors.append(f"File not found: {filepath}")
            return False
        
        content = filepath.read_text()
        
        # Determine chart type based on directory
        is_root_app = self._is_root_application(filepath)
        
        # Validate sections
        if is_root_app:
            self._validate_sections(content, self.ROOT_APP_REQUIRED_SECTIONS, filepath)
        else:
            self._validate_sections(content, self.CHART_REQUIRED_SECTIONS, filepath)
        
        # Validate tables
        self._validate_tables(content, filepath)
        
        # Validate links
        self._validate_links(content, filepath)
        
        # Check for recommended sections
        self._check_recommended_sections(content, filepath)
        
        # Report results
        has_errors = len(self.errors) > 0
        has_warnings = len(self.warnings) > 0
        
        if has_errors or (self.strict and has_warnings):
            return False
        
        return True
    
    def _is_root_application(self, filepath: Path) -> bool:
        """Check if README is for a root application."""
        return "root-applications" in str(filepath)
    
    def _validate_sections(self, content: str, required_sections: List[str], filepath: Path):
        """Validate that required sections exist."""
        for section in required_sections:
            if section not in content:
                self.errors.append(
                    f"{filepath}: Missing required section: {section}"
                )
    
    def _validate_tables(self, content: str, filepath: Path):
        """Validate table formatting."""
        # Find all tables (lines with |)
        table_lines = [line for line in content.split('\n') if '|' in line]
        
        if not table_lines:
            # Check if tables are expected
            if "## Configuration Files" in content or "## Helm Parameters" in content:
                self.warnings.append(
                    f"{filepath}: Expected tables in Configuration Files or Helm Parameters sections"
                )
            return
        
        # Basic table validation
        in_table = False
        prev_col_count = 0
        
        for i, line in enumerate(content.split('\n')):
            if '|' not in line:
                in_table = False
                continue
            
            # Count columns
            col_count = len([c for c in line.split('|') if c.strip()])
            
            if in_table and col_count != prev_col_count:
                self.warnings.append(
                    f"{filepath}:{i+1}: Inconsistent table column count"
                )
            
            in_table = True
            prev_col_count = col_count
    
    def _validate_links(self, content: str, filepath: Path):
        """Validate markdown links."""
        # Find all markdown links [text](url)
        link_pattern = r'\[([^\]]+)\]\(([^\)]+)\)'
        links = re.findall(link_pattern, content)
        
        for text, url in links:
            # Check for relative links to files
            if url.startswith('../') or url.startswith('./'):
                # Resolve relative path
                target = filepath.parent / url
                if not target.exists() and not url.startswith('#'):
                    self.warnings.append(
                        f"{filepath}: Broken link to {url}"
                    )
    
    def _check_recommended_sections(self, content: str, filepath: Path):
        """Check for recommended but optional sections."""
        missing_recommended = []
        for section in self.RECOMMENDED_SECTIONS:
            if section not in content:
                missing_recommended.append(section)
        
        if missing_recommended:
            self.warnings.append(
                f"{filepath}: Missing recommended sections: {', '.join(missing_recommended)}"
            )
    
    def get_errors(self) -> List[str]:
        """Get list of validation errors."""
        return self.errors
    
    def get_warnings(self) -> List[str]:
        """Get list of validation warnings."""
        return self.warnings


def find_readme_files(root_dir: Path) -> List[Path]:
    """
    Find all README.md files in the repository.
    
    Args:
        root_dir: Root directory to search
        
    Returns:
        List of README.md file paths
    """
    readme_files = []
    
    # Search in specific directories
    search_dirs = [
        root_dir / "root-applications",
        root_dir / "cluster-applications",
        root_dir / "instance-applications",
        root_dir / "sls-applications",
    ]
    
    for search_dir in search_dirs:
        if search_dir.exists():
            readme_files.extend(search_dir.rglob("README.md"))
    
    return readme_files


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Verify README structure compliance"
    )
    parser.add_argument(
        "files",
        nargs="*",
        help="README files to validate (default: all README.md files)"
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat warnings as errors"
    )
    parser.add_argument(
        "--root-dir",
        type=Path,
        default=Path.cwd(),
        help="Repository root directory"
    )
    
    args = parser.parse_args()
    
    # Determine files to validate
    if args.files:
        files_to_validate = [Path(f) for f in args.files]
    else:
        files_to_validate = find_readme_files(args.root_dir)
    
    if not files_to_validate:
        print("No README files found to validate")
        return 0
    
    # Validate files
    validator = ReadmeValidator(strict=args.strict)
    failed_files = []
    
    for filepath in files_to_validate:
        print(f"Validating {filepath}...")
        
        if not validator.validate_file(filepath):
            failed_files.append(filepath)
            
            # Print errors
            for error in validator.get_errors():
                print(f"  ERROR: {error}")
            
            # Print warnings
            for warning in validator.get_warnings():
                if args.strict:
                    print(f"  ERROR: {warning}")
                else:
                    print(f"  WARNING: {warning}")
        else:
            # Print warnings even on success
            for warning in validator.get_warnings():
                print(f"  WARNING: {warning}")
            
            if not validator.get_warnings():
                print(f"  ✓ Valid")
    
    # Summary
    print("\n" + "=" * 70)
    print(f"Validated {len(files_to_validate)} files")
    print(f"Passed: {len(files_to_validate) - len(failed_files)}")
    print(f"Failed: {len(failed_files)}")
    
    if failed_files:
        print("\nFailed files:")
        for filepath in failed_files:
            print(f"  - {filepath}")
        return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

# Made with Bob

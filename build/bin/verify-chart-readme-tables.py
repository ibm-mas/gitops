#!/usr/bin/env python3

import argparse
import re
import sys
from pathlib import Path


ROOT_HEADERS = ("## ArgoCD Applications", "## Resources Created")
ROOT_DIR_NAMES = ("root-applications", "instance-applications", "cluster-applications", "sls-applications")


def find_chart_dirs(base: Path):
    charts = []
    for root_name in ROOT_DIR_NAMES:
        root = base / root_name
        if not root.is_dir():
            continue
        for child in sorted(root.iterdir()):
            if (child / "Chart.yaml").is_file() and (child / "README.md").is_file() and (child / "templates").is_dir():
                charts.append(child)
    return charts


def parse_readme_table(readme_path: Path):
    text = readme_path.read_text(encoding="utf-8")
    lines = text.splitlines()

    header_index = None
    section_type = None
    for idx, line in enumerate(lines):
        stripped = line.strip()
        if stripped == "## ArgoCD Applications":
            header_index = idx
            section_type = "root"
            break
        if stripped == "## Resources Created":
            header_index = idx
            section_type = "resource"
            break

    if header_index is None:
        raise ValueError(f"Missing supported README section in {readme_path}")

    table_lines = []
    in_table = False
    for line in lines[header_index + 1:]:
        if line.strip().startswith("|"):
            table_lines.append(line.rstrip())
            in_table = True
            continue
        if in_table:
            break

    if len(table_lines) < 2:
        raise ValueError(f"Missing markdown table under section in {readme_path}")

    return section_type, table_lines


def parse_root_table_entries(table_lines):
    entries = []
    for row in table_lines[2:]:
        cols = [c.strip() for c in row.strip().strip("|").split("|")]
        if len(cols) < 2:
            continue
        template_match = re.search(r"\]\((templates/[^)]+)\)", cols[0])
        if not template_match:
            continue
        entries.append({
            "template": Path(template_match.group(1)).name,
            "application_name": cols[1],
            "raw": row,
        })
    return entries


def parse_resource_table_entries(table_lines):
    entries = []
    for row in table_lines[2:]:
        cols = [c.strip() for c in row.strip().strip("|").split("|")]
        if len(cols) < 5:
            continue
        resource_type = cols[0].strip("` ").strip()
        entries.append({
            "resource_type": resource_type,
            "raw": row,
        })
    return entries


def extract_kinds_from_template(template_path: Path):
    text = template_path.read_text(encoding="utf-8")
    kinds = []
    seen = set()
    for match in re.finditer(r"(?m)^[ \t]*kind:[ \t]*([A-Za-z0-9]+)[ \t]*$", text):
        kind = match.group(1)
        if kind not in seen:
            kinds.append(kind)
            seen.add(kind)
    return kinds


def classify_root_template(template_path: Path):
    kinds = extract_kinds_from_template(template_path)
    app_kinds = [k for k in kinds if k in ("Application", "ApplicationSet")]
    return app_kinds


def validate_root_chart(chart_dir: Path, readme_entries):
    errors = []
    template_dir = chart_dir / "templates"
    actual_templates = sorted([p.name for p in template_dir.iterdir() if p.is_file() and p.suffix in (".yaml", ".yml")])
    listed_templates = sorted([entry["template"] for entry in readme_entries])

    missing_from_readme = sorted(set(actual_templates) - set(listed_templates))
    missing_from_templates = sorted(set(listed_templates) - set(actual_templates))

    for name in missing_from_readme:
        errors.append(f"{chart_dir}: template not documented in README table: templates/{name}")
    for name in missing_from_templates:
        errors.append(f"{chart_dir}: README references missing template file: templates/{name}")

    for entry in readme_entries:
        template_path = template_dir / entry["template"]
        if not template_path.is_file():
            continue
        app_kinds = classify_root_template(template_path)
        if not app_kinds:
            errors.append(f"{chart_dir}: template {entry['template']} does not define Application/ApplicationSet")
        if len(app_kinds) > 1:
            errors.append(f"{chart_dir}: template {entry['template']} defines multiple app kinds {app_kinds}; README expects one row per template")
        if "(ApplicationSet)" in entry["application_name"] and "ApplicationSet" not in app_kinds:
            errors.append(f"{chart_dir}: README marks {entry['template']} as ApplicationSet but template kind is {app_kinds}")
        if "(ApplicationSet)" not in entry["application_name"] and "ApplicationSet" in app_kinds:
            errors.append(f"{chart_dir}: README should mark {entry['template']} as ApplicationSet")
    return errors


def iter_template_files(template_dir: Path):
    return sorted(
        [
            p for p in template_dir.rglob("*")
            if p.is_file() and p.suffix in (".yaml", ".yml")
        ]
    )


def validate_resource_chart(chart_dir: Path, readme_entries):
    errors = []
    template_dir = chart_dir / "templates"
    actual_templates = iter_template_files(template_dir)
    actual_kinds = []
    seen = set()
    for template_path in actual_templates:
        for kind in extract_kinds_from_template(template_path):
            if kind not in seen:
                actual_kinds.append(kind)
                seen.add(kind)

    documented_kinds = {entry["resource_type"] for entry in readme_entries}
    actual_kinds_set = set(actual_kinds)

    missing_from_readme = sorted(actual_kinds_set - documented_kinds)
    stale_in_readme = sorted(documented_kinds - actual_kinds_set)

    for kind in missing_from_readme:
        errors.append(f"{chart_dir}: resource kind not documented in README table: {kind}")
    for kind in stale_in_readme:
        errors.append(f"{chart_dir}: README documents resource kind not found in templates: {kind}")

    return errors


def validate_chart(chart_dir: Path):
    readme_path = chart_dir / "README.md"
    section_type, table_lines = parse_readme_table(readme_path)

    if section_type == "root":
        return validate_root_chart(chart_dir, parse_root_table_entries(table_lines))
    return validate_resource_chart(chart_dir, parse_resource_table_entries(table_lines))


def main():
    parser = argparse.ArgumentParser(
        description="Verify Helm chart README tables match template files/resource kinds."
    )
    parser.add_argument(
        "paths",
        nargs="*",
        default=["root-applications", "instance-applications", "cluster-applications", "sls-applications"],
        help="Chart directories or parent directories to validate",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    chart_dirs = []

    for raw_path in args.paths:
        path = (repo_root / raw_path).resolve()
        if path.is_file():
            print(f"Skipping file path: {raw_path}", file=sys.stderr)
            continue
        if (path / "Chart.yaml").is_file():
            chart_dirs.append(path)
            continue
        if path.is_dir():
            for child in sorted(path.iterdir()):
                if (child / "Chart.yaml").is_file() and (child / "README.md").is_file() and (child / "templates").is_dir():
                    chart_dirs.append(child)

    if not chart_dirs:
        chart_dirs = find_chart_dirs(repo_root)

    all_errors = []
    for chart_dir in chart_dirs:
        try:
            errors = validate_chart(chart_dir)
            all_errors.extend(errors)
        except Exception as exc:
            all_errors.append(f"{chart_dir}: validation failed: {exc}")

    if all_errors:
        print("README table validation failed:")
        for error in all_errors:
            print(f"- {error}")
        return 1

    print(f"README table validation passed for {len(chart_dirs)} chart(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

# Made with Bob

#!/usr/bin/env python3
"""Dependency-aware recovery planner and guarded restore for the Suite/Manage DR POC.

  restore.py plan  --backup DIR [--include-optin] [--format text|json]
  restore.py apply --backup DIR --target-server URL [--execute] [--overwrite] [--include-optin]

`plan` never touches a cluster.  `apply` is a server-side dry-run unless --execute is also
given, and it refuses to run against the cluster the backup came from.  Only manifest entries
whose recovery method is "backup" (restore_eligible) are ever applied.  GitOps/operator/
cert-manager owned objects, CRDs, CSVs, Subscriptions and CatalogSources are never applied
from a backup: the plan lists the supported way to recreate each of them.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dr_lib as lib  # noqa: E402
import yaml  # noqa: E402

STAGES = {
    1: "Cluster and namespace prerequisites",
    2: "Catalogs, subscriptions, operators and CRDs",
    3: "GitOps / toolchain reconstruction",
    4: "Externally sourced Secrets and manual inputs",
    5: "Explicitly backed-up resources",
    6: "Certificates, issuers and CA continuity",
    7: "Custom resources and operator reconciliation",
    8: "Final validation",
}

BUILTIN_GROUPS = {"", "v1", "apps", "batch", "networking.k8s.io", "rbac.authorization.k8s.io", "route.openshift.io"}


class RestoreError(Exception):
    pass


# --------------------------------------------------------------------------- loading
def load_backup(backup: str) -> dict:
    mpath = os.path.join(backup, "MANIFEST.json")
    if not os.path.isfile(mpath):
        raise RestoreError(f"{mpath} not found: not a backup directory")
    with open(mpath) as fh:
        manifest = json.load(fh)
    if manifest.get("schemaVersion") != lib.SCHEMA_VERSION:
        raise RestoreError(f"unsupported manifest schemaVersion {manifest.get('schemaVersion')}")
    errors = lib.verify_sha256sums(backup)
    e2, _ = lib.validate_manifest(manifest, backup)
    errors += e2
    if errors:
        raise RestoreError("backup failed integrity validation:\n  " + "\n  ".join(errors))
    return manifest


def read_object(backup: str, entry: dict, decrypt_cmd: str = ""):
    with open(os.path.join(backup, entry["file"]), "rb") as fh:
        data = fh.read()
    if entry.get("encrypted"):
        if not decrypt_cmd:
            raise RestoreError(f"{entry['id']} is encrypted; set DR_DECRYPT_CMD")
        try:
            data = lib.decrypt_bytes(data, decrypt_cmd)
        except RuntimeError as exc:
            raise RestoreError(f"{entry['id']}: {exc}") from exc
    return yaml.safe_load(data)


# --------------------------------------------------------------------------- planning
def _stage_for(entry: dict) -> int:
    if entry["kind"] == "Secret" and entry.get("blocked_by") == "ca_continuity_policy":
        return 6
    if entry["kind"] in ("Certificate", "Issuer", "ClusterIssuer"):
        return 6
    if entry["kind"] in ("Secret", "ConfigMap"):
        return 5
    return 7


def static_steps(manifest: dict) -> list:
    """Documented steps performed by other systems.  Paths refer to repositories in this
    workspace; none of these steps has been exercised by this POC."""
    ns = manifest["namespaces"]
    inst = manifest["instance"]
    return [
        (1, "cluster-access", "Provision/identify an ISOLATED target cluster (never the source cluster) and log in.",
         "manual", ""),
        (1, "namespaces", f"Ensure namespaces exist: {ns['core']}, {ns['manage']}, {ns['syncres']}, {ns['cert_manager']}. "
         "Namespace creator not verified; confirm which GitOps chart creates them.",
         "gitops", "gitops: cluster-applications, instance-applications"),
        (1, "storage", "Provide the storage class used by the source (inst03: nfs-client PVC mas-inst03-jmsserver-pvc).",
         "manual", "gitops-envs/fyre-noble8-dev/noble8/inst03"),
        (2, "catalogs", "Install the IBM operator CatalogSource at the same catalog version as the source.",
         "gitops", "gitops: cluster-applications/000-ibm-operator-catalog"),
        (2, "cert-manager", "Install cert-manager (Red Hat operator) so cert-manager CRDs exist.",
         "gitops", "gitops: cluster-applications/010-redhat-cert-manager"),
        (2, "mas-operator", "Subscription/OperatorGroup for ibm-mas are rendered by the Suite chart; OLM installs the CSV and CRDs.",
         "gitops", "gitops: instance-applications/130-ibm-mas-suite/templates/01,02"),
        (3, "gitops-reconstruct", f"Recreate the ArgoCD root/instance applications for {inst} from gitops-envs/saas-envs. "
         "Charts render Suite, config CRs, ManageApp and ManageWorkspace. In the isolated env set mas_wipe_mongo_data=false "
         "and use isolated DB/AWS paths; do NOT let it share the source's databases.",
         "gitops", "gitops-envs/<cluster>/<account>/<instance>/*.yaml via saas-tekton pipelines"),
        (4, "aws-secrets", "Provision externally sourced values (ibm-entitlement, syncres 'aws' Secret, JDBC/DB credentials, "
         "cos-logging) from AWS Secrets Manager paths of the TARGET environment.",
         "external", "AWS Secrets Manager via ArgoCD Vault Plugin"),
        (4, "databases", "Restore Db2/Mongo/SLS data with their own procedures (separate Jira stories). "
         "Manage encryption Secrets below must match the restored data.",
         "external", "database backup stories (not covered here)"),
        (7, "operator-reconcile", "Let the Suite and Manage operators reconcile; do not restore ManageDeployment, bundles or other operator-owned CRs.",
         "operator", "operators"),
        (8, "validate", "Suite and ManageWorkspace Ready; Certificates Ready; ClusterIssuers Ready; Manage pods running; "
         "login and a Manage encrypted-field read succeed; no resource has a stale ownerReference.",
         "manual", "README.md acceptance criteria"),
    ]


def _exclusion_reason(e: dict) -> str:
    if e["backup_mode"] == lib.MODE_OPTIN:
        return "opt-in only (pass --include-optin after review)" + \
               (f"; blocked by {e['blocked_by']}" if e.get("blocked_by") else "")
    return f"recovered by '{e['recovery_action']}', not applied from backup"


def _blockers(manifest: dict, include_optin: bool) -> list:
    b = []
    if not manifest["encryption"]["secrets_and_files_encrypted"]:
        b.append("backup is plaintext; do not move it off the source workstation")
    ca = [e for e in manifest["entries"] if e.get("blocked_by") == "ca_continuity_policy"]
    skipped_ca = [s for s in manifest["skipped"] + manifest.get("not_backed_up", [])
                  if s.get("recovery_action") == "ca_continuity_decision"]
    if ca and not include_optin:
        b.append("CA key pairs are in the backup but not selected: decide CA continuity (see README) and pass --include-optin")
    if skipped_ca:
        b.append("CA key pairs were NOT exported (policy). Without them cert-manager mints a NEW CA and leaf "
                 "certificates/trust are re-issued; the approved continuity method is undecided")
    if any(e["ambiguous"] for e in manifest["entries"]):
        b.append("some entries have ambiguous classification; review MANIFEST.json before apply")
    b.append("operator adoption of restored Secrets and Manage data decryption are unproven until an isolated restore test passes")
    return b


def build_plan(manifest: dict, include_optin: bool = False) -> dict:
    items = []
    for stage, key, desc, kind, src in static_steps(manifest):
        items.append({"id": f"STEP/{stage}/{key}", "kind": "Step", "name": key, "namespace": "", "stage": stage,
                      "phase": stage, "action": kind, "description": desc, "source": src, "depends_on": []})
    selected, excluded = [], []
    for e in manifest["entries"]:
        if e.get("restore_eligible") or (include_optin and e["backup_mode"] == lib.MODE_OPTIN):
            selected.append(e)
        else:
            excluded.append({"id": e["id"], "category": e["category"], "recovery_action": e["recovery_action"],
                             "backup_mode": e["backup_mode"], "reason": _exclusion_reason(e)})
    # Build apply items with their natural stage, then propagate stage forward along dependency
    # edges so a resource is never placed in an earlier stage than any of its prerequisites.
    # Without this, a stable sort-by-stage after topological ordering can invert cross-stage
    # edges (e.g. a stage-5 Secret that depends on a stage-6 cert-manager Secret).
    raw = {}
    for e in selected:
        raw[e["id"]] = {"id": e["id"], "kind": e["kind"], "name": e["name"], "namespace": e["namespace"],
                        "stage": _stage_for(e), "action": "apply", "file": e["file"],
                        "description": f"restore {e['kind']}/{e['name']} ({e['category']}, {e['recovery_action']})",
                        "source": "backup", "depends_on": list(e.get("depends_on", [])),
                        "encrypted": e.get("encrypted", False), "ambiguous": e.get("ambiguous", False),
                        "sensitive": e.get("sensitive", False), "stripped": e.get("stripped", {})}
    # Propagate: if B depends on A and stage(A) > stage(B), raise stage(B) to stage(A).
    # Repeat until stable (at most len(raw) passes for a linear chain).
    changed = True
    while changed:
        changed = False
        for item in raw.values():
            for dep_id in item["depends_on"]:
                if dep_id in raw and raw[dep_id]["stage"] > item["stage"]:
                    item["stage"] = raw[dep_id]["stage"]
                    changed = True
    for item in raw.values():
        item["phase"] = item["stage"]
        items.append(item)
    ordered = lib.order_entries(items)
    # Stage is the primary key; the stable sort preserves topological order within a stage.
    # Because stage propagation above already raised dependent stages to at least their
    # prerequisite's stage, no cross-stage dependency inversion can occur here.
    ordered.sort(key=lambda i: i["stage"])
    position = {i["id"]: n for n, i in enumerate(ordered, 1)}
    problems = []
    for i in ordered:
        i["order"] = position[i["id"]]
        for d in i["depends_on"]:
            if d in position and position[d] > position[i["id"]]:
                problems.append(f"{i['id']} (step {position[i['id']]}) depends on {d} (step {position[d]})")
    recreated = [{"id": n["id"], "recovery_action": n["recovery_action"], "source_of_truth": n["source_of_truth"],
                  "external_source": n.get("external_source", "")} for n in manifest.get("not_backed_up", [])]
    return {"instance": manifest["instance"], "source_server": manifest["source_server"],
            "backup_created": manifest["created"], "stages": STAGES, "steps": ordered,
            "excluded_from_restore": excluded, "recreated_by_owner": recreated, "problems": problems,
            "manual_blockers": _blockers(manifest, include_optin)}


def render_plan(plan: dict) -> str:
    lines = [f"Recovery plan for instance {plan['instance']} (backup created {plan['backup_created']})",
             f"Source cluster (NEVER restore here): {plan['source_server'] or 'unknown'}", ""]
    tags = {"apply": "APPLY ", "gitops": "GITOPS", "manual": "MANUAL", "external": "EXTERN", "operator": "OPER  "}
    for stage, title in plan["stages"].items():
        lines.append(f"== Stage {stage}: {title}")
        steps = [s for s in plan["steps"] if s["stage"] == stage]
        for s in steps:
            extra = (" [ambiguous]" if s.get("ambiguous") else "") + (" [encrypted]" if s.get("encrypted") else "")
            lines.append(f"  {s['order']:>3}. {tags[s['action']]} {s['description']}{extra}")
            if s["action"] != "apply" and s.get("source"):
                lines.append(f"        source: {s['source']}")
        if not steps:
            lines.append("      (none)")
    lines += ["", "== Recreated by their owner (not applied from backup)"]
    lines += [f"  - {r['id']}: {r['recovery_action']}" for r in plan["recreated_by_owner"]]
    lines += ["", "== In backup but excluded from restore"]
    lines += [f"  - {r['id']}: {r['reason']}" for r in plan["excluded_from_restore"]]
    lines += ["", "== Manual blockers / unverified"]
    lines += [f"  - {b}" for b in plan["manual_blockers"]]
    if plan["problems"]:
        lines += ["", "== PLAN PROBLEMS"] + [f"  - {p}" for p in plan["problems"]]
    return "\n".join(lines)


# --------------------------------------------------------------------------- apply
def default_oc(args, input_text=None):
    proc = subprocess.run(["oc", *args], input=input_text, capture_output=True, text=True)
    return proc.returncode, proc.stdout, proc.stderr


def preflight(manifest: dict, target_server: str, run=default_oc) -> list:
    """Return blocking errors; an empty list means the target looks safe.

    If the backup's source_server or source_context was not captured at backup time (empty
    string), the corresponding safety guard cannot fire.  preflight adds a warning error so
    the operator is told explicitly rather than silently relying on a degraded check.
    """
    rc, out, _ = run(["whoami", "--show-server"])
    server = out.strip()
    if rc != 0 or not server:
        return ["not logged in to a cluster"]
    errs = []
    if target_server.rstrip("/") != server.rstrip("/"):
        errs.append(f"--target-server ({target_server}) does not equal the logged-in server ({server})")
    src = manifest.get("source_server", "")
    if not src:
        errs.append("backup has no source_server recorded; source-cluster identity check is unavailable "
                    "(re-run backup with a working 'oc whoami --show-server')")
    elif server.rstrip("/") == src.rstrip("/"):
        errs.append("logged-in cluster is the backup's SOURCE cluster; restore there is forbidden")
    _, ctx, _ = run(["config", "current-context"])
    src_ctx = manifest.get("source_context", "")
    if not src_ctx:
        errs.append("backup has no source_context recorded; source-context identity check is unavailable "
                    "(re-run backup with a working 'oc config current-context')")
    elif ctx.strip() and ctx.strip() == src_ctx:
        errs.append("current context equals the backup's source context; restore there is forbidden")
    for key, ns in manifest["namespaces"].items():
        if key == "syncres":
            continue
        rc, _, _ = run(["get", "namespace", ns])
        if rc != 0:
            errs.append(f"namespace {ns} does not exist on target (stage 1 incomplete)")
    return errs


def api_available(api_version: str, run) -> bool:
    group = api_version.split("/")[0] if "/" in api_version else ""
    if group in BUILTIN_GROUPS:
        return True
    rc, out, _ = run(["api-resources", f"--api-group={group}", "-o", "name", "--no-headers"])
    return rc == 0 and bool(out.strip())


def apply_plan(backup: str, manifest: dict, plan: dict, target_server: str, execute: bool, overwrite: bool,
               run=default_oc, decrypt_cmd: str = "") -> dict:
    """Apply restorable steps in plan order; stop at the first failure.  The report never
    contains object content.

    Return dict fields:
      executed        bool  – whether --execute was in effect
      overwrite       bool  – whether --overwrite was in effect
      results         list  – per-step outcome dicts (id, result, [detail])
      ok              bool  – True when every step is created/dry-run-ok/skipped_exists
                              (preserved for backward compatibility)
      ok_no_skips     bool  – True only when every step is created/dry-run-ok; False when
                              any step was skipped because it already existed on the target
      skipped_required_ids  list  – IDs of required resources that returned skipped_exists;
                              these were not overwritten and their contents were NOT verified
      warnings        list  – human-readable warnings for conditions that need operator review
    """
    errs = preflight(manifest, target_server, run)
    if errs:
        raise RestoreError("preflight failed:\n  " + "\n  ".join(errs))
    if plan["problems"]:
        raise RestoreError("plan has ordering problems:\n  " + "\n  ".join(plan["problems"]))
    if execute and not manifest["encryption"]["secrets_and_files_encrypted"]:
        raise RestoreError(
            "--execute refused: backup is not encrypted. "
            "Re-run backup with DR_ENCRYPT_CMD set (team-approved encryption mechanism required). "
            "Dry-run (without --execute) is still available to verify the plan against the target."
        )
    entries = {e["id"]: e for e in manifest["entries"]}
    verb = "apply" if overwrite else "create"
    results, stop = [], False
    for step in plan["steps"]:
        if step["action"] != "apply":
            continue
        if stop:
            results.append({"id": step["id"], "result": "not_attempted"})
            continue
        obj = read_object(backup, entries[step["id"]], decrypt_cmd)
        if not api_available(obj.get("apiVersion", ""), run):
            results.append({"id": step["id"], "result": "failed",
                            "detail": "API/CRD not installed on target (stage 2 incomplete)"})
            stop = True
            continue
        rc, _, err = run([verb, "-f", "-", "--dry-run=none" if execute else "--dry-run=server"],
                         yaml.safe_dump(obj))
        if rc == 0:
            results.append({"id": step["id"], "result": "created" if execute else "dry-run-ok"})
        elif "AlreadyExists" in err and not overwrite:
            results.append({"id": step["id"], "result": "skipped_exists",
                            "detail": "already on target; not overwritten (use --overwrite)"})
        else:
            tail = err.strip().splitlines()[-1][:200] if err.strip() else "unknown error"
            results.append({"id": step["id"], "result": "failed", "detail": tail})
            stop = True
    # Identify required resources that were skipped: their on-target contents were not verified.
    skipped_required_ids = [
        r["id"] for r in results
        if r["result"] == "skipped_exists" and entries.get(r["id"], {}).get("required")
    ]
    warnings = []
    for sid in skipped_required_ids:
        warnings.append(
            f"REQUIRED resource {sid} already exists on the target and was NOT overwritten. "
            f"Its contents were not verified against the backup. "
            f"Run with --overwrite to replace it, or manually confirm the target value is correct."
        )
    return {"executed": execute, "overwrite": overwrite, "results": results,
            "ok": all(r["result"] in ("created", "dry-run-ok", "skipped_exists") for r in results),
            "ok_no_skips": all(r["result"] in ("created", "dry-run-ok") for r in results),
            "skipped_required_ids": skipped_required_ids,
            "warnings": warnings}


# --------------------------------------------------------------------------- cli
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("plan", "apply"):
        s = sub.add_parser(name)
        s.add_argument("--backup", required=True)
        s.add_argument("--include-optin", action="store_true")
        s.add_argument("--format", choices=("text", "json"), default="text")
    s = sub.choices["apply"]
    s.add_argument("--target-server", required=True, help="must equal `oc whoami --show-server` (typed confirmation)")
    s.add_argument("--execute", action="store_true", help="really create objects (default: server-side dry-run)")
    s.add_argument("--overwrite", action="store_true", help="use `oc apply` (default `oc create`, never overwrites)")
    a = ap.parse_args(argv)
    try:
        manifest = load_backup(a.backup)
        plan = build_plan(manifest, a.include_optin)
        if a.cmd == "plan":
            print(json.dumps(plan, indent=2, sort_keys=True) if a.format == "json" else render_plan(plan))
            return 2 if plan["problems"] else 0
        print(render_plan(plan))
        print("\n" + ("EXECUTING" if a.execute else "DRY-RUN (server-side; nothing is created)"))
        report = apply_plan(a.backup, manifest, plan, a.target_server, a.execute, a.overwrite,
                            decrypt_cmd=os.environ.get("DR_DECRYPT_CMD", ""))
    except RestoreError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 3
    for r in report["results"]:
        print(f"  {r['result']:<16} {r['id']}" + (f"  - {r['detail']}" if r.get("detail") else ""))
    for w in report.get("warnings", []):
        print(f"WARNING: {w}")
    if report["ok"] and report.get("skipped_required_ids") and a.execute:
        # Required resources were skipped during actual execution: the restore is incomplete.
        print("apply: INCOMPLETE (required resources already on target; contents unverified)")
        return 5
    print("apply:", "OK" if report["ok"] else "FAILED")
    return 0 if report["ok"] else 4


if __name__ == "__main__":
    sys.exit(main())

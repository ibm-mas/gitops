#!/usr/bin/env python3
"""Shared logic for the MASCORE-20742 Suite/Manage disaster-recovery POC.

Pure functions (classification, sanitisation, reference extraction, manifest
building/validation, dependency ordering) plus a small CLI used by
backup-suite-manage.sh.  Nothing here ever prints Secret values: Secret `data`
is only handled in memory by `store`, and every report carries key *names* only.
"""
from __future__ import annotations

import argparse
import copy
import datetime
import hashlib
import heapq
import json
import os
import re
import shlex
import subprocess
import sys

import yaml

SCHEMA_VERSION = 1
TOOL = "mascore-20742-suite-resource-dr"

VOLATILE_METADATA = ("resourceVersion", "uid", "creationTimestamp", "generation",
                     "managedFields", "selfLink")
LAST_APPLIED = "kubectl.kubernetes.io/last-applied-configuration"
ARGOCD_TRACKING = "argocd.argoproj.io/tracking-id"

# Categories (ownership)
GITOPS = "gitops_managed"
TOOLCHAIN = "toolchain_managed"
OPERATOR = "operator_managed"
EXTERNAL = "externally_sourced"
MANUAL = "manual_or_app_created"
UNKNOWN = "unknown"
CATEGORIES = (GITOPS, TOOLCHAIN, OPERATOR, EXTERNAL, MANUAL, UNKNOWN)

# backup_mode: how the resource is treated by backup/restore
MODE_RESTORE = "restore"            # stored, restorable by default
MODE_OPTIN = "restore_optin"        # stored, restorable only with an explicit opt-in flag
MODE_REFERENCE = "reference"        # stored for review/diff only, never restored
MODE_NONE = "none"                  # not stored; recreated by GitOps/operator/OLM

OLM_KINDS = ("Subscription", "OperatorGroup", "CatalogSource")

# Policy hints (NOT ownership evidence): Secrets whose loss cannot be repaired by
# re-reconciliation because they protect already-persisted data or sessions.
DEFAULT_STATE_HINTS = (r"encryption-secret", r"-keys-(jwt|ltpa)$", r"-credentials-superuser$")

# Objects created by in-cluster toolchain Jobs that only record run timestamps.  Evidence:
# gitops/sub-charts/junitreporter/templates/00-presync-report-starter.yaml (ArgoCD PreSync hook Job
# that runs `kubectl` from the CLI image and writes "<prefix>-synctime").  Policy hint, not ownership.
DEFAULT_EPHEMERAL_HINTS = (r"^pre-jreporter-.*-synctime$",)

KIND_RANK = {"Namespace": 0, "CustomResourceDefinition": 1, "CatalogSource": 2,
             "OperatorGroup": 3, "Subscription": 4, "Secret": 10, "ConfigMap": 11,
             "ClusterIssuer": 20, "Issuer": 21, "Certificate": 22}


# --------------------------------------------------------------------------- helpers
def rid(kind: str, namespace: str, name: str) -> str:
    return f"{kind}/{namespace or ''}/{name}"


def utcnow() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def write_private(path: str, data: bytes) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "wb") as fh:
        fh.write(data)
    os.chmod(path, 0o600)


def managers(obj: dict) -> list:
    return sorted({m.get("manager", "") for m in (obj.get("metadata") or {}).get("managedFields") or []
                   if m.get("manager")})


class Ctx:
    """Classification context (instance scope + policy)."""

    def __init__(self, instance, namespaces, ca_secrets=(), hints=DEFAULT_STATE_HINTS,
                 workspace_id="main", ephemeral=DEFAULT_EPHEMERAL_HINTS):
        self.instance = instance
        self.workspace_id = workspace_id
        self.namespaces = dict(namespaces)  # core, manage, syncres, cert_manager
        self.ca_secrets = {tuple(x) for x in ca_secrets}
        self.hints = [re.compile(h) for h in hints]
        self.ephemeral = [re.compile(h) for h in ephemeral]

    @classmethod
    def from_config(cls, cfg: dict, ca_secrets=()):
        return cls(cfg["instance"], cfg["namespaces"], ca_secrets,
                   cfg.get("state_hints") or DEFAULT_STATE_HINTS, cfg.get("workspace_id", "main"))

    def subdir(self, namespace: str) -> str:
        if not namespace:
            return "cluster"
        for key, subdir in (("core", "core"), ("manage", "manage"), ("syncres", "syncres"),
                            ("cert_manager", "cert-manager")):
            if self.namespaces.get(key) == namespace:
                return subdir
        return "other"


# --------------------------------------------------------------------------- sanitise
def sanitize(obj: dict, mode: str):
    """Return (clean_copy, stripped_report).

    mode "reference": remove only volatile server-populated fields, status and the
    last-applied annotation (which can duplicate the whole spec including credentials).
    mode "restore": additionally remove ownerReferences (stale UIDs make the garbage
    collector delete the restored object), finalizers and the ArgoCD tracking-id,
    and record exactly what was removed.
    """
    clean = copy.deepcopy(obj)
    stripped = {}
    meta = clean.setdefault("metadata", {})
    for key in VOLATILE_METADATA:
        meta.pop(key, None)
    ann = meta.get("annotations") or {}
    ann.pop(LAST_APPLIED, None)
    if mode == MODE_RESTORE:
        if meta.get("ownerReferences"):
            stripped["ownerReferences"] = [f"{o.get('kind')}/{o.get('name')}" for o in meta.pop("ownerReferences")]
        if meta.get("finalizers"):
            stripped["finalizers"] = list(meta.pop("finalizers"))
        if ann.pop(ARGOCD_TRACKING, None) is not None:
            stripped["annotations"] = [ARGOCD_TRACKING]
    if ann:
        meta["annotations"] = ann
    else:
        meta.pop("annotations", None)
    clean.pop("status", None)
    return clean, stripped


# --------------------------------------------------------------------------- references
def extract_references(obj: dict, ctx: Ctx) -> list:
    """Return sorted resource ids referenced by this object's spec.

    Secrets and ConfigMaps are intentionally excluded from scanning: their `spec` (or `data`)
    could contain encoded credential values, and they do not reference other resources by name
    in a way that the backup tool needs to follow.  Only CRs (Suite, ManageWorkspace, Certificate,
    Issuer, ClusterIssuer, …) carry meaningful `secretName` / `issuerRef` references in their
    specs, so those are the only objects whose outbound edges are extracted.
    """
    kind = obj.get("kind", "")
    if kind in ("Secret", "ConfigMap"):
        return []
    meta = obj.get("metadata") or {}
    ns = meta.get("namespace", "")
    cert_ns = ctx.namespaces.get("cert_manager", "cert-manager")
    refs = set()

    def add(ref_kind, name, namespace):
        if isinstance(name, str) and name:
            refs.add(rid(ref_kind, namespace, name))

    def walk(node, parent_key=""):
        if isinstance(node, dict):
            for key, value in node.items():
                lk = key.lower()
                if isinstance(value, str):
                    target_ns = cert_ns if kind == "ClusterIssuer" else ns
                    if lk.endswith("secretname") or lk in ("secret", "encryptionsecret"):
                        add("Secret", value, target_ns)
                    elif lk.endswith("configmapname"):
                        add("ConfigMap", value, target_ns)
                elif isinstance(value, dict):
                    if lk in ("secretref", "secretkeyref") and value.get("name"):
                        add("Secret", value["name"], ns)
                    elif lk in ("configmapref", "configmapkeyref") and value.get("name"):
                        add("ConfigMap", value["name"], ns)
                    elif lk == "issuerref" and value.get("name"):
                        ik = value.get("kind") or "Issuer"
                        add(ik, value["name"], "" if ik == "ClusterIssuer" else ns)
                walk(value, key)
        elif isinstance(node, list):
            for item in node:
                walk(item, parent_key)

    walk(obj.get("spec") or {})
    refs.discard(rid(kind, ns, meta.get("name", "")))
    return sorted(refs)


def ca_secret_refs(obj: dict, ctx: Ctx) -> list:
    """(namespace, secretName) pairs used as CA key pairs by an Issuer/ClusterIssuer."""
    if obj.get("kind") not in ("Issuer", "ClusterIssuer"):
        return []
    name = ((obj.get("spec") or {}).get("ca") or {}).get("secretName")
    if not name:
        return []
    ns = (obj.get("metadata") or {}).get("namespace") or ctx.namespaces.get("cert_manager", "cert-manager")
    return [(ns, name)]


# --------------------------------------------------------------------------- classify
def classify(obj: dict, ctx: Ctx) -> dict:
    """Classify ownership and recovery method using object metadata only (never names alone,
    except the explicit, documented state-bearing Secret policy hints)."""
    kind = obj.get("kind", "")
    meta = obj.get("metadata") or {}
    name, ns = meta.get("name", ""), meta.get("namespace", "")
    ann, labels = meta.get("annotations") or {}, meta.get("labels") or {}
    owners = meta.get("ownerReferences") or []
    tracking = ann.get(ARGOCD_TRACKING)
    primary = ann.get("operator-sdk/primary-resource")
    cert_owner = ann.get("cert-manager.io/certificate-name")
    helm = ann.get("meta.helm.sh/release-name")
    tekton = (any(k.startswith("tekton.dev/") for k in labels)
              or any(o.get("kind") in ("PipelineRun", "TaskRun") for o in owners))
    mgrs = managers(obj)
    manual_mgrs = [m for m in mgrs if m == "oc" or m.startswith("kubectl")]
    sensitive = kind == "Secret"
    hint = sensitive and any(rx.search(name) for rx in ctx.hints)
    ev = []
    r = {"id": rid(kind, ns, name), "kind": kind, "name": name, "namespace": ns,
         "scope": "namespaced" if ns else "cluster", "category": UNKNOWN, "confidence": "observed",
         "ambiguous": False, "ambiguity_reason": "", "source_of_truth": "", "external_source": "",
         "recovery_action": "review_manually", "backup_mode": MODE_REFERENCE, "required": False,
         "sensitive": sensitive, "blocked_by": "", "phase": 0}

    if owners:
        ev.append("ownerReferences: " + ", ".join(f"{o.get('kind')}/{o.get('name')}" for o in owners))
    if primary:
        ev.append(f"annotation operator-sdk/primary-resource={primary}")
    if cert_owner:
        ev.append(f"annotation cert-manager.io/certificate-name={cert_owner}")
    if tracking:
        ev.append(f"annotation {ARGOCD_TRACKING}={tracking}")
    if helm:
        ev.append(f"annotation meta.helm.sh/release-name={helm}")
    if mgrs:
        ev.append("field managers: " + ", ".join(mgrs))

    if kind == "Namespace":
        r.update(confidence="inferred", recovery_action="create_namespace", backup_mode=MODE_NONE, phase=1,
                 ambiguous=True, ambiguity_reason="namespace creator not verified (GitOps chart vs. pipeline)",
                 source_of_truth="GitOps/cluster provisioning; creator unverified")
    elif kind == "ConfigMap" and any(rx.search(name) for rx in ctx.ephemeral) and not owners:
        r.update(category=TOOLCHAIN, confidence="inferred", recovery_action="recreated_by_sync_hook",
                 backup_mode=MODE_REFERENCE, phase=2,
                 source_of_truth="ArgoCD PreSync/PostSync hook Job (gitops sub-charts/junitreporter); run timestamps only")
        ev.append("policy hint: ephemeral junitreporter sync-time record; field managers kubectl-* come from the hook Job")
    elif kind == "CustomResourceDefinition" and not tracking:
        r.update(category=OPERATOR, confidence="inferred", recovery_action="install_operator",
                 backup_mode=MODE_NONE, phase=1,
                 source_of_truth="operator package installed through OLM (version in CSV)")
        ev.append("kind CustomResourceDefinition: installed by operator package, not backed up")
    elif kind == "ClusterServiceVersion":
        r.update(category=OPERATOR, confidence="observed" if any(k.startswith("olm.") for k in ann) else "inferred",
                 recovery_action="install_operator", backup_mode=MODE_NONE, phase=1,
                 source_of_truth="OLM, generated from the Subscription")
        ev.append("kind ClusterServiceVersion: generated by OLM")
    elif tracking:
        app = tracking.split(":")[0]
        r.update(backup_mode=MODE_REFERENCE, phase=2,
                 source_of_truth=f"ArgoCD application '{app}' (gitops chart + gitops-envs values)")
        if sensitive:
            r.update(category=EXTERNAL, confidence="inferred", recovery_action="gitops_resync_with_external_secret",
                     external_source="AWS Secrets Manager via ArgoCD Vault Plugin (inferred from gitops chart "
                                     "convention; confirm in the chart that renders this Secret)", phase=3)
        else:
            r.update(category=GITOPS, recovery_action="gitops_resync")
        if owners:
            r.update(ambiguous=True, ambiguity_reason="both an ArgoCD tracking-id and ownerReferences are present")
    elif kind == "Secret" and (ns, name) in ctx.ca_secrets:
        r.update(category=OPERATOR, confidence="inferred", recovery_action="ca_continuity_decision",
                 backup_mode=MODE_OPTIN, phase=5, blocked_by="ca_continuity_policy",
                 source_of_truth="cert-manager CA Certificate (private key); continuity method not yet approved")
        ev.append("referenced as spec.ca.secretName by an Issuer/ClusterIssuer: CA private-key pair")
    elif primary or owners or cert_owner:
        owner_desc = ", ".join(f"{o.get('kind')}/{o.get('name')}" for o in owners) or primary
        r.update(category=OPERATOR, source_of_truth=f"operator reconcile of {owner_desc}",
                 recovery_action="recreate_operator", backup_mode=MODE_REFERENCE, phase=6)
        if kind == "Secret" and cert_owner:
            r.update(recovery_action="recreate_cert_manager",
                     source_of_truth=f"cert-manager Certificate/{cert_owner}")
        elif kind == "Secret" and hint:
            r.update(recovery_action="backup_restore_pre_reconcile", backup_mode=MODE_RESTORE, required=True,
                     phase=4, confidence="inferred",
                     source_of_truth="operator-generated state; non-reproducible, restore before operator reconciles")
            ev.append("policy hint: state-bearing Secret (regenerating it would orphan persisted data/sessions)")
        elif kind == "Secret":
            r.update(confidence="inferred")  # assumed regenerated by operator; verify in isolated test
    elif tekton or helm:
        r.update(category=TOOLCHAIN, confidence="inferred", recovery_action="rerun_toolchain", phase=2,
                 source_of_truth="deployment toolchain (Tekton/Helm); confirm the originating pipeline")
        r.update(ambiguous=True, ambiguity_reason="Tekton/Helm markers without ArgoCD tracking: confirm origin")
    elif manual_mgrs:
        r.update(category=MANUAL, confidence="inferred", recovery_action="backup_restore", backup_mode=MODE_RESTORE,
                 phase=4, ambiguous=True,
                 ambiguity_reason="kubectl/oc field manager only: could be a human or an in-cluster Job using kubectl",
                 source_of_truth="no GitOps/operator marker; this backup may be the only copy (origin unconfirmed)")
    else:
        r.update(category=UNKNOWN, ambiguous=True, confidence="inferred",
                 ambiguity_reason="no ownerReferences, GitOps/operator/cert-manager markers or manual field manager",
                 backup_mode=MODE_OPTIN, recovery_action="review_manually", phase=4,
                 source_of_truth="unknown")
        if hint:
            r.update(backup_mode=MODE_RESTORE, required=True, recovery_action="backup_restore_pre_reconcile",
                     ambiguity_reason=r["ambiguity_reason"] + "; name matches a state-bearing policy hint, "
                     "so it is backed up as restorable but its true origin must be confirmed")
            ev.append("policy hint: state-bearing Secret")

    if kind in OLM_KINDS and r["category"] in (UNKNOWN, MANUAL):
        r.update(recovery_action="reinstall_via_supported_workflow", backup_mode=MODE_REFERENCE, phase=1)
    r["evidence"] = ev
    return r


# --------------------------------------------------------------------------- ordering
def order_entries(entries: list) -> list:
    """Deterministic topological order: dependencies first, ties by (phase, kind rank, ns, name)."""
    by_id = {e["id"]: e for e in entries}
    deps = {i: {d for d in e.get("depends_on", []) if d in by_id and d != i} for i, e in by_id.items()}
    rdeps = {i: set() for i in by_id}
    for i, ds in deps.items():
        for d in ds:
            rdeps[d].add(i)

    def key(i):
        e = by_id[i]
        return (e.get("phase", 0), KIND_RANK.get(e["kind"], 50), e.get("namespace", ""), e["name"], i)

    ready = [key(i) for i, ds in deps.items() if not ds]
    heapq.heapify(ready)
    out = []
    while ready:
        i = heapq.heappop(ready)[-1]
        out.append(by_id[i])
        for j in rdeps[i]:
            deps[j].discard(i)
            if not deps[j]:
                heapq.heappush(ready, key(j))
    if len(out) != len(by_id):
        cyclic = sorted(set(by_id) - {e["id"] for e in out})
        raise ValueError("dependency cycle among: " + ", ".join(cyclic))
    return out


# --------------------------------------------------------------------------- encryption
def encrypt_bytes(data: bytes, cmd: str) -> bytes:
    """Pipe data through an external, team-approved command (stdin -> stdout).
    The command (and its keys/recipients) is supplied by the operator; none is bundled."""
    proc = subprocess.run(shlex.split(cmd), input=data, capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(f"encrypt command failed (rc={proc.returncode})")
    if not proc.stdout:
        raise RuntimeError("encrypt command produced no output")
    return proc.stdout


def decrypt_bytes(data: bytes, cmd: str) -> bytes:
    proc = subprocess.run(shlex.split(cmd), input=data, capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(f"decrypt command failed (rc={proc.returncode})")
    if not proc.stdout:
        raise RuntimeError("decrypt command produced no output")
    return proc.stdout


# --------------------------------------------------------------------------- backup state files
def _p(out, name):
    return os.path.join(out, name)


def load_config(out: str) -> dict:
    with open(_p(out, ".dr-config.json")) as fh:
        return json.load(fh)


def read_jsonl(path: str) -> list:
    if not os.path.exists(path):
        return []
    with open(path) as fh:
        return [json.loads(line) for line in fh if line.strip()]


def append_jsonl(path: str, obj: dict) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    with os.fdopen(fd, "a") as fh:
        fh.write(json.dumps(obj, sort_keys=True) + "\n")


def ca_secrets_from_out(out: str) -> list:
    path = _p(out, ".ca-secrets.json")
    if not os.path.exists(path):
        return []
    with open(path) as fh:
        return [tuple(x) for x in json.load(fh)]


def record_ca_secrets(out: str, pairs: list) -> None:
    cur = {tuple(x) for x in ca_secrets_from_out(out)} | {tuple(x) for x in pairs}
    write_private(_p(out, ".ca-secrets.json"), json.dumps(sorted(cur)).encode())


def cmd_init(a):
    os.makedirs(a.out, exist_ok=True)
    os.chmod(a.out, 0o700)
    for sub in ("core", "manage", "syncres", "cert-manager", "cluster"):
        os.makedirs(_p(a.out, sub), exist_ok=True)
        os.chmod(_p(a.out, sub), 0o700)
    cfg = {"schemaVersion": SCHEMA_VERSION, "tool": TOOL, "created": utcnow(), "instance": a.instance,
           "workspace_id": a.workspace_id,
           "namespaces": {"core": a.core_ns, "manage": a.manage_ns, "syncres": a.syncres_ns,
                          "cert_manager": a.cert_ns},
           "source_server": a.source_server, "source_context": a.source_context,
           "encryption": {"configured": bool(os.environ.get("DR_ENCRYPT_CMD")),
                          "allow_plaintext_local": a.allow_plaintext_local},
           "include_ca_keys": a.include_ca_keys, "store_reference_secrets": a.store_reference_secrets,
           "state_hints": list(a.state_hint or DEFAULT_STATE_HINTS)}
    write_private(_p(a.out, ".dr-config.json"), json.dumps(cfg, indent=2).encode())
    return 0


def cmd_ca_secrets(a):
    load_config(a.out)
    for ns, name in ca_secrets_from_out(a.out):
        print(f"Secret|secrets|{name}|{ns}")
    return 0


def cmd_record_skip(a):
    cfg = load_config(a.out)
    append_jsonl(_p(a.out, ".skips.jsonl"), {
        "id": rid(a.kind, a.namespace, a.name), "kind": a.kind, "name": a.name, "namespace": a.namespace,
        "required": a.required == "required", "status": a.status, "reason": a.reason, "source": a.source})
    return 0


def cmd_store(a):
    cfg = load_config(a.out)
    ctx = Ctx.from_config(cfg, ca_secrets_from_out(a.out))
    obj = json.load(sys.stdin)
    kind = obj.get("kind", "")
    meta = obj.get("metadata") or {}
    name, ns = meta.get("name", ""), meta.get("namespace", "")
    if not kind or not name:
        raise SystemExit("ERROR: object on stdin has no kind/name")
    if kind in ("Issuer", "ClusterIssuer"):
        record_ca_secrets(a.out, ca_secret_refs(obj, ctx))
        ctx = Ctx.from_config(cfg, ca_secrets_from_out(a.out))
    cls = classify(obj, ctx)
    if cls["id"] in {r["id"] for r in read_jsonl(_p(a.out, ".records.jsonl"))}:
        print(f"duplicate ignored {cls['id']}")
        return 0
    policy_reason = ""
    if kind == "Secret" and cls["blocked_by"] == "ca_continuity_policy" and not cfg["include_ca_keys"]:
        policy_reason = ("CA private-key Secret: continuity method not approved; "
                         "set --include-ca-keys (requires DR_ENCRYPT_CMD) to export it")
    elif kind == "Secret" and cls["backup_mode"] == MODE_REFERENCE and not cfg.get("store_reference_secrets"):
        policy_reason = (f"{cls['category']}: regenerated by '{cls['recovery_action']}'; "
                         "content not copied (use --store-reference-secrets for a break-glass copy)")
    if policy_reason:
        skip = {k: cls[k] for k in ("id", "kind", "name", "namespace", "category", "recovery_action",
                                     "source_of_truth", "external_source", "confidence", "ambiguous")}
        skip.update({"required": False, "status": "skipped_policy", "reason": policy_reason, "source": a.source})
        append_jsonl(_p(a.out, ".skips.jsonl"), skip)
        print(f"not stored (policy) {cls['id']} category={cls['category']}")
        return 0
    if kind == "Secret" and cls["blocked_by"] and not os.environ.get("DR_ENCRYPT_CMD"):
        raise SystemExit("ERROR: --include-ca-keys requires DR_ENCRYPT_CMD; CA private keys are never stored in plaintext")
    clean, stripped = sanitize(obj, MODE_RESTORE if cls["backup_mode"] == MODE_RESTORE else MODE_REFERENCE)
    data_keys = sorted((obj.get("data") or {}).keys()) + sorted((obj.get("stringData") or {}).keys()) if kind == "Secret" else []
    payload = yaml.safe_dump(clean, sort_keys=False).encode()
    enc_cmd = os.environ.get("DR_ENCRYPT_CMD", "")
    encrypted = bool(enc_cmd)
    if kind == "Secret" and not encrypted and not cfg["encryption"]["allow_plaintext_local"]:
        raise SystemExit("ERROR: refusing to write a Secret in plaintext (set DR_ENCRYPT_CMD or --allow-plaintext-local)")
    if encrypted:
        payload = encrypt_bytes(payload, enc_cmd)
    rel = f"{ctx.subdir(ns)}/{kind.lower()}-{name}.yaml" + (".enc" if encrypted else "")
    path = _p(a.out, rel)
    write_private(path, payload)
    entry = dict(cls)
    entry.update({"apiVersion": obj.get("apiVersion", ""), "file": rel, "sha256": sha256_bytes(payload),
                  "size": len(payload), "encrypted": encrypted, "data_keys": data_keys,
                  "stripped": stripped, "depends_on": extract_references(obj, ctx),
                  "required": bool(cls["required"] or a.required == "required"), "source": a.source,
                  "restore_eligible": cls["backup_mode"] == MODE_RESTORE})
    append_jsonl(_p(a.out, ".records.jsonl"), entry)
    print(f"stored {entry['id']} category={entry['category']} mode={entry['backup_mode']}"
          f"{' (ambiguous)' if entry['ambiguous'] else ''}")
    return 0


def _attempted(out: str) -> set:
    return {r["id"] for r in read_jsonl(_p(out, ".records.jsonl"))} | \
           {r["id"] for r in read_jsonl(_p(out, ".skips.jsonl"))}


def cmd_pending_refs(a):
    """List referenced Secrets/ConfigMaps/Issuers in scope that have not been attempted yet."""
    cfg = load_config(a.out)
    in_scope = set(cfg["namespaces"].values())
    seen = _attempted(a.out)
    ca = {rid("Secret", ns, name) for ns, name in ca_secrets_from_out(a.out)}  # handled by --include-ca-keys policy
    pending = {}
    for rec in read_jsonl(_p(a.out, ".records.jsonl")):
        for dep in rec.get("depends_on", []):
            kind, ns, name = dep.split("/", 2)
            if dep in seen or dep in ca or (ns and ns not in in_scope) \
                    or kind not in ("Secret", "ConfigMap", "Issuer", "ClusterIssuer"):
                continue
            pending[dep] = (kind, ns, name)
    hints = [re.compile(h) for h in cfg.get("state_hints") or DEFAULT_STATE_HINTS]
    for dep, (kind, ns, name) in sorted(pending.items()):
        res = kind.lower() + (".cert-manager.io" if kind in ("Issuer", "ClusterIssuer") else "")
        req = "required" if kind == "Secret" and any(h.search(name) for h in hints) else "optional"
        print(f"{kind}|{res}|{name}|{ns}|{req}")
    return 0


def _discover_stores(entry: dict) -> bool:
    """Whether a discovered entry is stored by the backup.  Reference-only Secrets are not stored:
    their content is regenerated by GitOps/operators, so copying it would add risk and no value."""
    if entry["backup_mode"] == MODE_NONE:
        return False
    return not (entry["kind"] == "Secret" and entry["backup_mode"] == MODE_REFERENCE)


def cmd_targets(a):
    """Targets from a discovery inventory that are not stored yet."""
    with open(a.inventory) as fh:
        inv = json.load(fh)
    seen = _attempted(a.out)
    ca = {rid("Secret", ns, name) for ns, name in ca_secrets_from_out(a.out)}
    for e in inv["entries"]:
        if e["id"] in seen or e["id"] in ca or e["blocked_by"] or not _discover_stores(e):
            continue
        group = e.get("apiVersion", "").split("/")[0] if "/" in e.get("apiVersion", "") else ""
        res = e["kind"].lower() + (f".{group}" if group else "")
        print(f"{e['kind']}|{res}|{e['name']}|{e['namespace']}|{'required' if e['required'] else 'optional'}")
    return 0


# --------------------------------------------------------------------------- manifest + validation
def build_manifest(out: str) -> dict:
    cfg = load_config(out)
    records = read_jsonl(_p(out, ".records.jsonl"))
    skips = read_jsonl(_p(out, ".skips.jsonl"))
    inv_path = _p(out, "inventory.json")
    inventory = None
    if os.path.exists(inv_path):
        with open(inv_path) as fh:
            inventory = json.load(fh)
    stored = {r["id"] for r in records}
    not_backed_up = []
    if inventory:
        not_backed_up = [{k: e[k] for k in ("id", "kind", "name", "namespace", "category", "recovery_action",
                                            "source_of_truth", "external_source", "confidence", "ambiguous")}
                         for e in inventory["entries"] if e["id"] not in stored and (not _discover_stores(e) or e["blocked_by"])]
    not_backed_up += [{k: s.get(k, "") for k in ("id", "kind", "name", "namespace", "category", "recovery_action",
                                                  "source_of_truth", "external_source", "confidence", "ambiguous")}
                      for s in skips if s["status"] == "skipped_policy"
                      and s["id"] not in {n["id"] for n in not_backed_up}]
    manifest = {"schemaVersion": SCHEMA_VERSION, "tool": TOOL, "created": cfg["created"], "completed": utcnow(),
                "instance": cfg["instance"], "workspace_id": cfg["workspace_id"], "namespaces": cfg["namespaces"],
                "source_server": cfg["source_server"], "source_context": cfg["source_context"],
                "encryption": {"secrets_and_files_encrypted": cfg["encryption"]["configured"],
                               "mode": "external-command (DR_ENCRYPT_CMD)" if cfg["encryption"]["configured"]
                               else "none (plaintext-local, restricted permissions)"},
                "include_ca_keys": cfg["include_ca_keys"], "discovery_run": inventory is not None,
                "entries": sorted(records, key=lambda e: e["id"]),
                "skipped": sorted(skips, key=lambda e: e["id"]),
                "not_backed_up": sorted(not_backed_up, key=lambda e: e["id"])}
    errors, warnings = validate_manifest(manifest, out, inventory)
    manifest["validation"] = {"ok": not errors, "errors": errors, "warnings": warnings, "checked": utcnow()}
    write_private(_p(out, "MANIFEST.json"), json.dumps(manifest, indent=2, sort_keys=True).encode())
    lines = []
    for e in manifest["entries"]:
        lines.append(f"{e['sha256']}  {e['file']}")
    lines.append(f"{sha256_file(_p(out, 'MANIFEST.json'))}  MANIFEST.json")
    write_private(_p(out, "SHA256SUMS"), ("\n".join(lines) + "\n").encode())
    return manifest


def validate_manifest(manifest: dict, base: str, inventory=None):
    errors, warnings = [], []
    ids = [e["id"] for e in manifest["entries"]]
    for dup in sorted({i for i in ids if ids.count(i) > 1}):
        errors.append(f"duplicate entry {dup}")
    enc_files = 0
    for e in manifest["entries"]:
        path = os.path.join(base, e["file"])
        if not os.path.isfile(path):
            errors.append(f"{e['id']}: file missing ({e['file']})")
            continue
        if sha256_file(path) != e["sha256"]:
            errors.append(f"{e['id']}: checksum mismatch ({e['file']})")
        if (os.stat(path).st_mode & 0o077) != 0:
            errors.append(f"{e['id']}: file is group/world accessible ({e['file']})")
        if e["kind"] == "Secret" and not e["encrypted"] and manifest["encryption"]["secrets_and_files_encrypted"]:
            errors.append(f"{e['id']}: Secret stored unencrypted although encryption is configured")
        if e["encrypted"]:
            enc_files += 1
            continue
        try:
            with open(path) as fh:
                obj = yaml.safe_load(fh)
        except yaml.YAMLError:
            errors.append(f"{e['id']}: YAML does not parse")
            continue
        errors.extend(_content_errors(e, obj))
    if (os.stat(base).st_mode & 0o077) != 0:
        errors.append("backup directory is group/world accessible")
    for s in manifest["skipped"]:
        if s["required"] and s["status"] != "skipped_policy":
            errors.append(f"required resource {s['id']} not backed up: {s['reason']}")
    all_ids = set(ids)
    known_recreated = {n["id"] for n in manifest.get("not_backed_up", [])}
    skipped_ids = {s["id"] for s in manifest["skipped"]}
    missing_refs = sorted({d for e in manifest["entries"] for d in e.get("depends_on", [])
                           if d not in all_ids and d not in known_recreated and d not in skipped_ids})
    for d in missing_refs:
        warnings.append(f"referenced resource not in backup and not classified: {d}")
    if inventory:
        for e in inventory["entries"]:
            if e["backup_mode"] == MODE_RESTORE and e["id"] not in all_ids and e["id"] not in skipped_ids:
                errors.append(f"discovered restorable resource missing from backup: {e['id']}")
    else:
        warnings.append("discovery not run (--discover): completeness against the live cluster is unverified")
    amb = sum(1 for e in manifest["entries"] if e["ambiguous"])
    if amb:
        warnings.append(f"{amb} entries have ambiguous classification (see ambiguity_reason)")
    if enc_files:
        warnings.append(f"{enc_files} encrypted files not content-validated (decrypt needed)")
    return errors, warnings


def _content_errors(e: dict, obj) -> list:
    errs = []
    if not isinstance(obj, dict) or not obj.get("kind"):
        return [f"{e['id']}: not a Kubernetes object"]
    meta = obj.get("metadata") or {}
    for f in VOLATILE_METADATA:
        if f in meta:
            errs.append(f"{e['id']}: volatile metadata.{f} present")
    if "status" in obj:
        errs.append(f"{e['id']}: status present")
    if LAST_APPLIED in (meta.get("annotations") or {}):
        errs.append(f"{e['id']}: last-applied annotation present")
    if e["backup_mode"] == MODE_RESTORE:
        for f in ("ownerReferences", "finalizers"):
            if meta.get(f):
                errs.append(f"{e['id']}: restorable object still has metadata.{f}")
        if ARGOCD_TRACKING in (meta.get("annotations") or {}):
            errs.append(f"{e['id']}: restorable object still has ArgoCD tracking-id")
    return errs


def verify_sha256sums(base: str) -> list:
    errs = []
    path = _p(base, "SHA256SUMS")
    if not os.path.exists(path):
        return ["SHA256SUMS missing"]
    with open(path) as fh:
        lines = fh.read().splitlines()
    for line in lines:
        if not line.strip():
            continue
        digest, _, rel = line.partition("  ")
        fp = _p(base, rel)
        if not os.path.isfile(fp):
            errs.append(f"{rel}: missing")
        elif sha256_file(fp) != digest:
            errs.append(f"{rel}: checksum mismatch")
    return errs


def cmd_manifest(a):
    m = build_manifest(a.out)
    v = m["validation"]
    counts = {}
    for e in m["entries"]:
        counts[e["backup_mode"]] = counts.get(e["backup_mode"], 0) + 1
    print(f"manifest: {len(m['entries'])} stored {counts}, {len(m['skipped'])} skipped, "
          f"{len(m['not_backed_up'])} expected to be recreated (from discovery)")
    for w in v["warnings"]:
        print("WARNING:", w)
    for er in v["errors"]:
        print("ERROR:", er)
    print("validation:", "OK" if v["ok"] else "FAILED")
    return 0 if v["ok"] else 2


def cmd_verify(a):
    with open(_p(a.out, "MANIFEST.json")) as fh:
        m = json.load(fh)
    errors, warnings = validate_manifest(m, a.out)
    errors += verify_sha256sums(a.out)
    for w in warnings:
        print("WARNING:", w)
    for er in errors:
        print("ERROR:", er)
    print("verify:", "OK" if not errors else "FAILED")
    return 0 if not errors else 2


def cmd_classify(a):
    """Classify already-sanitised YAML files in a directory (offline; prints metadata only)."""
    ns = {"core": f"mas-{a.instance}-core", "manage": f"mas-{a.instance}-manage",
          "syncres": f"mas-{a.instance}-syncres", "cert_manager": a.cert_ns}
    ctx = Ctx(a.instance, ns)
    objs = []
    for root, _, files in os.walk(a.path):
        for f in sorted(files):
            if f.endswith(".yaml"):
                with open(os.path.join(root, f)) as fh:
                    objs.append(yaml.safe_load(fh))
    for o in objs:
        for pair in ca_secret_refs(o, ctx):
            ctx.ca_secrets.add(pair)
    rows = sorted((classify(o, ctx) for o in objs), key=lambda r: r["id"])
    for r in rows:
        print("\t".join([r["id"], r["category"], r["recovery_action"], r["backup_mode"],
                         "AMBIGUOUS" if r["ambiguous"] else "-"]))
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("init")
    s.add_argument("--out", required=True)
    s.add_argument("--instance", required=True)
    s.add_argument("--workspace-id", default="main")
    s.add_argument("--core-ns", required=True)
    s.add_argument("--manage-ns", required=True)
    s.add_argument("--syncres-ns", required=True)
    s.add_argument("--cert-ns", required=True)
    s.add_argument("--source-server", default="")
    s.add_argument("--source-context", default="")
    s.add_argument("--allow-plaintext-local", action="store_true")
    s.add_argument("--include-ca-keys", action="store_true")
    s.add_argument("--store-reference-secrets", action="store_true")
    s.add_argument("--state-hint", action="append")
    s.set_defaults(fn=cmd_init)
    s = sub.add_parser("ca-secrets"); s.add_argument("--out", required=True); s.set_defaults(fn=cmd_ca_secrets)
    s = sub.add_parser("record-skip")
    for opt in ("out", "kind", "name", "namespace", "required", "status", "reason", "source"):
        s.add_argument(f"--{opt}", required=True)
    s.set_defaults(fn=cmd_record_skip)
    s = sub.add_parser("store")
    s.add_argument("--out", required=True)
    s.add_argument("--required", default="optional")
    s.add_argument("--source", default="allowlist")
    s.set_defaults(fn=cmd_store)
    s = sub.add_parser("pending-refs"); s.add_argument("--out", required=True); s.set_defaults(fn=cmd_pending_refs)
    s = sub.add_parser("targets")
    s.add_argument("--out", required=True)
    s.add_argument("--inventory", required=True)
    s.set_defaults(fn=cmd_targets)
    s = sub.add_parser("manifest"); s.add_argument("--out", required=True); s.set_defaults(fn=cmd_manifest)
    s = sub.add_parser("verify"); s.add_argument("--out", required=True); s.set_defaults(fn=cmd_verify)
    s = sub.add_parser("classify")
    s.add_argument("path")
    s.add_argument("--instance", required=True)
    s.add_argument("--cert-ns", default="cert-manager")
    s.set_defaults(fn=cmd_classify)
    a = ap.parse_args(argv)
    return a.fn(a)


if __name__ == "__main__":
    sys.exit(main())

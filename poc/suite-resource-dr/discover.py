#!/usr/bin/env python3
"""Read-only resource discovery and classification for one MAS instance (Core + Manage).

Only `oc get` is ever invoked.  Secret `data`/`stringData` is dropped in memory as soon as an
object is read and is never written or printed; the inventory records data key *names* only.

Usage:
  discover.py --instance inst03 [--workspace-id main] [--output inventory.json] [--format table|json]
              [--timeout 25] [--request-timeout 15s]

Each `oc get` call is bounded by two independent limits:
  --timeout          Python-side subprocess timeout in seconds (default 25).  On expiry the
                     query is recorded as a warning, discovery continues with the remaining
                     resources, and the inventory is flagged partial_discovery=True.
  --request-timeout  Passed as --request-timeout=<value> to every `oc get` invocation so the
                     API server itself terminates slow list operations (default "15s").

A partial inventory is never reported as complete: the tool exits nonzero and sets
"partial_discovery": true in the output JSON.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dr_lib as lib  # noqa: E402

# API groups owned by MAS / its dependencies that are enumerated generically.
MAS_GROUP_SUFFIX = ".mas.ibm.com"
EXTRA_GROUPS = ("sls.ibm.com", "marketplace.redhat.com")
CERT_KINDS = ("certificates.cert-manager.io", "issuers.cert-manager.io")
OLM_NAMESPACED = ("subscriptions.operators.coreos.com", "operatorgroups.operators.coreos.com",
                  "clusterserviceversions.operators.coreos.com")
CATALOG_NS = "openshift-marketplace"

PLATFORM_CONFIGMAPS = {"kube-root-ca.crt", "openshift-service-ca.crt"}
PLATFORM_SECRET_TYPES = {"kubernetes.io/service-account-token", "kubernetes.io/dockercfg"}

# Default subprocess timeout (seconds).  Overridden by --timeout / the timeout= kwarg.
DEFAULT_TIMEOUT = 25
# Default value passed as --request-timeout to oc.  Overridden by --request-timeout / kwarg.
DEFAULT_REQUEST_TIMEOUT = "15s"

# Sentinel returned by oc_json when the subprocess timer fires.
_TIMED_OUT = object()


def oc_json(args, *, timeout=DEFAULT_TIMEOUT, request_timeout=DEFAULT_REQUEST_TIMEOUT):
    """Run `oc get ... -o json`; returns parsed JSON, None when absent/forbidden,
    or the _TIMED_OUT sentinel when the subprocess timeout expires."""
    cmd = ["oc", "get", *args, "-o", "json", "--show-managed-fields"]
    if request_timeout:
        cmd.append(f"--request-timeout={request_timeout}")
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return _TIMED_OUT
    except FileNotFoundError:
        # oc binary not on PATH; caller should have checked prerequisites.
        return None
    if proc.returncode != 0:
        return None
    return json.loads(proc.stdout)


def _log(msg: str) -> None:
    """Write a progress line to stderr immediately (unbuffered)."""
    print(msg, file=sys.stderr, flush=True)


def _query_label(resource: str, namespace: str | None, selector: str | None) -> str:
    """Human-readable description of an oc-get query (no credential content)."""
    parts = [resource]
    if namespace:
        parts.append(f"-n {namespace}")
    if selector:
        parts.append(f"-l {selector}")
    return " ".join(parts)


def items(runner, resource, namespace=None, selector=None, label=None):
    """Fetch a resource list via runner; strip Secret bodies in-place.

    runner may return:
      - a dict with an "items" list  → normal list result
      - None                          → resource absent / forbidden (logged as note by callers)
      - _TIMED_OUT sentinel           → timeout; propagated to callers as-is
    """
    args = [resource]
    if namespace:
        args += ["-n", namespace]
    if selector:
        args += ["-l", selector]
    ql = label or _query_label(resource, namespace, selector)
    _log(f"  discover: querying {ql}")
    doc = runner(args)
    if doc is _TIMED_OUT:
        return _TIMED_OUT
    out = []
    for obj in (doc or {}).get("items", []):
        obj.setdefault("kind", resource.split(".")[0].capitalize())
        if obj.get("kind") == "Secret":
            obj["_data_keys"] = sorted((obj.get("data") or {}).keys())
            obj.pop("data", None)
            obj.pop("stringData", None)
        out.append(obj)
    return out


def is_platform_noise(obj):
    meta = obj.get("metadata", {})
    if obj.get("kind") == "ConfigMap" and meta.get("name") in PLATFORM_CONFIGMAPS:
        return True
    if obj.get("kind") == "Secret":
        if obj.get("type") in PLATFORM_SECRET_TYPES:
            return True
        if (meta.get("annotations") or {}).get("kubernetes.io/service-account.name"):
            return True
    return False


def discover(instance, namespaces, workspace_id="main", runner=None,
             timeout=DEFAULT_TIMEOUT, request_timeout=DEFAULT_REQUEST_TIMEOUT):
    """Return an inventory dict.

    runner is injectable for tests.  When runner is None, the real oc_json is used with the
    supplied timeout and request_timeout values.  When runner is provided (tests), timeout and
    request_timeout are ignored — the runner is responsible for simulating timeouts by returning
    the _TIMED_OUT sentinel.

    The returned dict includes:
      partial_discovery  bool  True when at least one query timed out; the inventory is
                               incomplete and must not be treated as authoritative.
    """
    if runner is None:
        def runner(args):  # noqa: F811
            return oc_json(args, timeout=timeout, request_timeout=request_timeout)

    ctx = lib.Ctx(instance, namespaces, workspace_id=workspace_id)
    in_scope = list(namespaces.values())
    objs, notes, seen = [], [], set()
    timed_out_queries: list[str] = []

    def add(obj, source):
        # Guard: Secret data/stringData must have been stripped by items() before reaching here.
        # If a caller bypasses items() and passes a raw Secret, abort rather than risk leaking
        # credential values into the inventory or classification output.
        if obj.get("kind") == "Secret" and (obj.get("data") or obj.get("stringData")):
            raise AssertionError(
                f"BUG: Secret {obj.get('metadata', {}).get('name')} passed to add() with "
                "data/stringData still present; strip via items() first"
            )
        meta = obj.get("metadata", {})
        key = lib.rid(obj.get("kind", ""), meta.get("namespace", ""), meta.get("name", ""))
        if key in seen:
            return
        seen.add(key)
        objs.append((obj, source))

    def handle_timeout(ql: str) -> None:
        msg = f"TIMEOUT: oc get {ql} did not complete within the configured timeout"
        _log(f"  discover: {msg}")
        notes.append(msg)
        timed_out_queries.append(ql)

    def safe_items(resource, namespace=None, selector=None):
        """items() wrapper that records timeouts as notes and returns [] on timeout."""
        ql = _query_label(resource, namespace, selector)
        result = items(runner, resource, namespace=namespace, selector=selector, label=ql)
        if result is _TIMED_OUT:
            handle_timeout(ql)
            return []
        return result

    for ns in in_scope:
        ql = f"namespace {ns}"
        _log(f"  discover: querying {ql}")
        doc = runner(["namespace", ns])
        if doc is _TIMED_OUT:
            handle_timeout(ql)
        elif doc is None:
            notes.append(f"namespace {ns} not found/readable")
        else:
            doc.setdefault("kind", "Namespace")
            add(doc, "namespace")

    # CRDs of MAS groups (prerequisites; recorded, never stored)
    crds = safe_items("customresourcedefinitions.apiextensions.k8s.io")
    mas_crds = [c for c in crds if (c.get("spec", {}).get("group", "").endswith(MAS_GROUP_SUFFIX)
                                    or c.get("spec", {}).get("group") in EXTRA_GROUPS)]
    for c in mas_crds:
        c["kind"] = "CustomResourceDefinition"
        add(c, "crd")

    # CRs of those CRDs in the instance namespaces (generic: no kind allowlist)
    selector = f"mas.ibm.com/instanceId={instance}"
    for crd in sorted(mas_crds, key=lambda c: c["metadata"]["name"]):
        spec = crd["spec"]
        res = f"{spec['names']['plural']}.{spec['group']}"
        if spec.get("scope") == "Namespaced":
            for ns in (namespaces["core"], namespaces["manage"]):
                for o in safe_items(res, namespace=ns):
                    add(o, "cr:" + crd["metadata"]["name"])
        else:
            for o in safe_items(res, selector=selector):
                add(o, "cr:" + crd["metadata"]["name"])

    # Config maps / Secrets in instance namespaces (metadata only).  The shared cert-manager
    # namespace is excluded: its Secrets are platform objects; instance CA Secrets are found
    # through the Issuer references below.
    for ns in (namespaces["core"], namespaces["manage"]):
        for kind in ("configmaps", "secrets"):
            for o in safe_items(kind, namespace=ns):
                if not is_platform_noise(o):
                    add(o, "namespace-scan")

    # cert-manager resources (instance-labelled in cert-manager ns; everything in MAS namespaces)
    for res in CERT_KINDS:
        for o in safe_items(res, namespace=namespaces["cert_manager"], selector=selector):
            add(o, "cert-manager")
        for ns in (namespaces["core"], namespaces["manage"]):
            for o in safe_items(res, namespace=ns):
                add(o, "cert-manager")
    for o in safe_items("clusterissuers.cert-manager.io", selector=selector):
        add(o, "cert-manager")

    # OLM resources in the instance namespaces + catalogs they use
    catalogs = set()
    for res in OLM_NAMESPACED:
        for ns in (namespaces["core"], namespaces["manage"], namespaces["cert_manager"]):
            for o in safe_items(res, namespace=ns):
                if o.get("kind") == "Subscription":
                    catalogs.add((o.get("spec", {}).get("sourceNamespace") or CATALOG_NS,
                                  o.get("spec", {}).get("source")))
                add(o, "olm")
    for cns, cname in sorted(c for c in catalogs if c[1]):
        for o in safe_items("catalogsources.operators.coreos.com", namespace=cns):
            if o["metadata"]["name"] == cname:
                add(o, "olm")

    # CA key-pair Secrets referenced by issuers (bodies already stripped)
    for o, _ in list(objs):
        for pair in lib.ca_secret_refs(o, ctx):
            ctx.ca_secrets.add(pair)
            if lib.rid("Secret", pair[0], pair[1]) not in seen:
                ca_result = safe_items("secrets", namespace=pair[0])
                match = [x for x in ca_result if x["metadata"]["name"] == pair[1]]
                if match:
                    add(match[0], "ca-keypair")
                else:
                    notes.append(f"CA Secret {pair[0]}/{pair[1]} referenced by "
                                 f"{o['kind']}/{o['metadata']['name']} is not readable")

    entries = []
    for o, source in objs:
        c = lib.classify(o, ctx)
        c.update({"apiVersion": o.get("apiVersion", ""), "source": source,
                  "depends_on": lib.extract_references(o, ctx),
                  "data_keys": o.get("_data_keys", [])})
        if (c["kind"] == "Suite" and c["name"] == instance) or \
                (c["kind"] == "ManageWorkspace" and c["name"] == f"{instance}-{workspace_id}"):
            c["required"] = True
        entries.append(c)
    entries.sort(key=lambda e: e["id"])
    summary = {}
    for e in entries:
        k = f"{e['category']}|{e['backup_mode']}"
        summary[k] = summary.get(k, 0) + 1
    partial = bool(timed_out_queries)
    return {"schemaVersion": lib.SCHEMA_VERSION, "tool": lib.TOOL, "generated": lib.utcnow(),
            "instance": instance, "workspace_id": workspace_id, "namespaces": namespaces,
            "partial_discovery": partial,
            "entries": entries, "summary": summary, "notes": sorted(notes),
            "ambiguous": [e["id"] for e in entries if e["ambiguous"]]}


def render_table(inv):
    rows = [("ID", "CATEGORY", "ACTION", "MODE", "REQ", "FLAGS")]
    for e in inv["entries"]:
        flags = ",".join(f for f, on in (("ambiguous", e["ambiguous"]), ("sensitive", e["sensitive"]),
                                         ("blocked:" + e["blocked_by"], bool(e["blocked_by"]))) if on)
        rows.append((e["id"], e["category"], e["recovery_action"], e["backup_mode"],
                     "Y" if e["required"] else "-", flags or "-"))
    widths = [max(len(r[i]) for r in rows) for i in range(len(rows[0]))]
    return "\n".join("  ".join(c.ljust(w) for c, w in zip(r, widths)).rstrip() for r in rows)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--instance", default=os.environ.get("INSTANCE", "inst03"))
    ap.add_argument("--workspace-id", default=os.environ.get("WORKSPACE_ID", "main"))
    ap.add_argument("--core-ns")
    ap.add_argument("--manage-ns")
    ap.add_argument("--syncres-ns")
    ap.add_argument("--cert-ns", default=os.environ.get("CERT_NS", "cert-manager"))
    ap.add_argument("--output", help="write inventory JSON here (mode 600)")
    ap.add_argument("--format", choices=("table", "json"), default="table")
    ap.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT,
                    help=f"per-query subprocess timeout in seconds (default {DEFAULT_TIMEOUT})")
    ap.add_argument("--request-timeout", default=DEFAULT_REQUEST_TIMEOUT,
                    help=f"value passed as --request-timeout to oc (default {DEFAULT_REQUEST_TIMEOUT!r})")
    a = ap.parse_args(argv)
    ns = {"core": a.core_ns or f"mas-{a.instance}-core", "manage": a.manage_ns or f"mas-{a.instance}-manage",
          "syncres": a.syncres_ns or f"mas-{a.instance}-syncres", "cert_manager": a.cert_ns}
    inv = discover(a.instance, ns, a.workspace_id,
                   timeout=a.timeout, request_timeout=a.request_timeout)
    if a.output:
        lib.write_private(a.output, json.dumps(inv, indent=2, sort_keys=True).encode())
    print(json.dumps(inv, indent=2, sort_keys=True) if a.format == "json" else render_table(inv))
    for note in inv["notes"]:
        print("NOTE:", note, file=sys.stderr)
    partial = inv.get("partial_discovery", False)
    if partial:
        print("\nWARNING: discovery is INCOMPLETE — one or more queries timed out (see TIMEOUT notes above).",
              file=sys.stderr)
    print(f"\n{len(inv['entries'])} resources; {len(inv['ambiguous'])} ambiguous classifications.",
          file=sys.stderr)
    return 1 if partial else 0


if __name__ == "__main__":
    sys.exit(main())

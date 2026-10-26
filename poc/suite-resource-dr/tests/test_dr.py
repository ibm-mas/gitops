"""Tests for the MASCORE-20742 DR POC.  Run: python3 -m unittest discover -s poc/suite-resource-dr/tests -v

No cluster, pytest or network is needed.  The backup script is exercised end to end against a
read-only fake `oc` that serves synthetic objects (tests/fakes.py).
"""
import copy
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
POC = os.path.dirname(HERE)
sys.path.insert(0, POC)
sys.path.insert(0, HERE)

import discover  # noqa: E402
import dr_lib as lib  # noqa: E402
import fakes  # noqa: E402
import restore  # noqa: E402

NS = {"core": fakes.CORE, "manage": fakes.MANAGE, "syncres": fakes.SYNC, "cert_manager": fakes.CERT}


def ctx(**kw):
    return lib.Ctx(fakes.INST, NS, **kw)


def obj(name, kind=None):
    for o in fakes.default_objects():
        if o["metadata"]["name"] == name and (kind is None or o["kind"] == kind):
            return o
    raise KeyError(name)


class ClassificationTests(unittest.TestCase):
    def test_argocd_tracked_cr_is_gitops(self):
        c = lib.classify(obj(fakes.INST), ctx())
        self.assertEqual((c["category"], c["recovery_action"], c["backup_mode"]),
                         (lib.GITOPS, "gitops_resync", lib.MODE_REFERENCE))
        self.assertIn("argocd", c["source_of_truth"].lower() + c["evidence"][0].lower() + str(c["evidence"]).lower())

    def test_tracked_secret_is_external_inferred_and_not_restorable(self):
        c = lib.classify(obj("cos-logging"), ctx())
        self.assertEqual(c["category"], lib.EXTERNAL)
        self.assertEqual(c["confidence"], "inferred")
        self.assertIn("AWS Secrets Manager", c["external_source"])
        self.assertEqual(c["backup_mode"], lib.MODE_REFERENCE)

    def test_operator_owned_state_secret_is_required_restore(self):
        c = lib.classify(obj("main-manage-encryption-secret"), ctx())
        self.assertEqual((c["category"], c["backup_mode"], c["required"]), (lib.OPERATOR, lib.MODE_RESTORE, True))
        self.assertEqual(c["recovery_action"], "backup_restore_pre_reconcile")
        self.assertTrue(any("ownerReferences" in e for e in c["evidence"]))

    def test_operator_owned_regenerable_secret_is_reference(self):
        c = lib.classify(obj(f"{fakes.INST}-admindashboard-cert-internal"), ctx())
        self.assertEqual((c["category"], c["backup_mode"], c["required"]), (lib.OPERATOR, lib.MODE_REFERENCE, False))

    def test_state_hint_is_configurable_policy_not_ownership(self):
        jwt = obj(f"{fakes.INST}-keys-jwt")  # operator-owned AND matches the default hint
        self.assertEqual(lib.classify(jwt, ctx())["backup_mode"], lib.MODE_RESTORE)
        self.assertEqual(lib.classify(jwt, ctx(hints=[]))["backup_mode"], lib.MODE_REFERENCE)

    def test_name_alone_does_not_make_ownership(self):
        # same name as an operator-owned object but without any marker -> not operator_managed
        o = obj("main-manage-encryption-secret")
        o["metadata"].pop("ownerReferences")
        c = lib.classify(o, ctx())
        self.assertEqual(c["category"], lib.UNKNOWN)
        self.assertTrue(c["ambiguous"])

    def test_unmarked_state_hint_secret_is_ambiguous_restore(self):
        c = lib.classify(obj(f"{fakes.INST}-keys-ltpa"), ctx())
        self.assertEqual((c["category"], c["backup_mode"], c["ambiguous"]), (lib.UNKNOWN, lib.MODE_RESTORE, True))
        self.assertIn("policy hint", " ".join(c["evidence"]))

    def test_unmarked_plain_object_is_optin_unknown(self):
        o = fakes.configmap("mystery", fakes.MANAGE)
        o["metadata"]["managedFields"] = []
        c = lib.classify(o, ctx())
        self.assertEqual((c["category"], c["backup_mode"], c["ambiguous"]), (lib.UNKNOWN, lib.MODE_OPTIN, True))

    def test_manual_field_manager_is_manual_restore(self):
        c = lib.classify(obj("extra-ref-secret"), ctx())
        self.assertEqual((c["category"], c["backup_mode"], c["ambiguous"]), (lib.MANUAL, lib.MODE_RESTORE, True))

    def test_synctime_configmap_is_toolchain_not_manual(self):
        o = fakes.configmap("pre-jreporter-ibm-mas-suite-inst03-synctime", fakes.CORE, manager="kubectl-create")
        c = lib.classify(o, ctx())
        self.assertEqual((c["category"], c["backup_mode"], c["recovery_action"]),
                         (lib.TOOLCHAIN, lib.MODE_REFERENCE, "recreated_by_sync_hook"))
        # the same manager on a differently named ConfigMap stays manual (and is flagged ambiguous)
        other = lib.classify(fakes.configmap("other-cm", fakes.CORE, manager="kubectl-create"), ctx())
        self.assertEqual((other["category"], other["ambiguous"]), (lib.MANUAL, True))

    def test_namespace_is_prerequisite_not_backed_up(self):
        c = lib.classify(obj(fakes.MANAGE, "Namespace"), ctx())
        self.assertEqual((c["recovery_action"], c["backup_mode"], c["ambiguous"]), ("create_namespace", lib.MODE_NONE, True))

    def test_cert_manager_leaf_secret_is_recreated(self):
        c = lib.classify(obj(f"{fakes.INST}-workspaceagent-tls"), ctx())
        self.assertEqual(c["recovery_action"], "recreate_cert_manager")
        self.assertEqual(c["backup_mode"], lib.MODE_REFERENCE)

    def test_ca_secret_is_blocked_optin_only_when_referenced_by_issuer(self):
        ca = obj(f"{fakes.INST}-cert-internal-ca", "Secret")
        plain = lib.classify(ca, ctx())  # not known as CA -> falls to cert-manager leaf logic
        self.assertEqual(plain["recovery_action"], "recreate_cert_manager")
        known = lib.classify(ca, ctx(ca_secrets=[(fakes.CERT, f"{fakes.INST}-cert-internal-ca")]))
        self.assertEqual((known["backup_mode"], known["blocked_by"]), (lib.MODE_OPTIN, "ca_continuity_policy"))

    def test_crd_and_olm_are_never_stored(self):
        crd = lib.classify(obj("suites.core.mas.ibm.com"), ctx())
        self.assertEqual((crd["recovery_action"], crd["backup_mode"]), ("install_operator", lib.MODE_NONE))
        sub = lib.classify(obj("ibm-mas"), ctx())
        self.assertEqual(sub["category"], lib.GITOPS)
        self.assertEqual(sub["backup_mode"], lib.MODE_REFERENCE)

    def test_unmanaged_olm_object_is_not_restored(self):
        o = obj("ibm-mas")
        o["metadata"]["annotations"] = {}
        o["metadata"]["managedFields"] = [{"manager": "kubectl-create"}]
        c = lib.classify(o, ctx())
        self.assertEqual((c["recovery_action"], c["backup_mode"]), ("reinstall_via_supported_workflow", lib.MODE_REFERENCE))

    def test_tracking_plus_owner_is_ambiguous(self):
        o = obj("cos-logging")
        o["metadata"]["ownerReferences"] = fakes.owner("Suite", fakes.INST, "u")
        self.assertTrue(lib.classify(o, ctx())["ambiguous"])

    def test_evidence_never_contains_secret_values(self):
        for o in fakes.default_objects():
            self.assertNotIn(fakes.SENTINEL, json.dumps(lib.classify(o, ctx())))


class SanitizeTests(unittest.TestCase):
    def test_reference_mode_keeps_ownership_metadata(self):
        clean, stripped = lib.sanitize(obj(fakes.INST), lib.MODE_REFERENCE)
        m = clean["metadata"]
        self.assertEqual(stripped, {})
        self.assertIn("finalizers", m)
        self.assertIn("argocd.argoproj.io/tracking-id", m["annotations"])
        for k in lib.VOLATILE_METADATA:
            self.assertNotIn(k, m)
        self.assertNotIn(lib.LAST_APPLIED, m["annotations"])
        self.assertNotIn("status", clean)

    def test_restore_mode_strips_only_ownership_metadata_and_records_it(self):
        o = obj("main-manage-encryption-secret")
        clean, stripped = lib.sanitize(o, lib.MODE_RESTORE)
        self.assertNotIn("ownerReferences", clean["metadata"])
        self.assertEqual(stripped["ownerReferences"], ["ManageWorkspace/inst03-main"])
        self.assertEqual(clean["data"], o["data"])  # data untouched
        self.assertEqual(clean["metadata"]["name"], o["metadata"]["name"])

    def test_restore_mode_strips_finalizers_and_tracking(self):
        clean, stripped = lib.sanitize(obj(fakes.INST), lib.MODE_RESTORE)
        self.assertNotIn("finalizers", clean["metadata"])
        self.assertEqual(stripped["annotations"], [lib.ARGOCD_TRACKING])
        self.assertNotIn("annotations", clean["metadata"])  # became empty -> removed

    def test_input_is_not_mutated(self):
        o = obj(fakes.INST)
        before = copy.deepcopy(o)
        lib.sanitize(o, lib.MODE_RESTORE)
        self.assertEqual(o, before)


class ReferenceTests(unittest.TestCase):
    def test_workspace_references(self):
        refs = lib.extract_references(obj(f"{fakes.INST}-main"), ctx())
        self.assertIn(f"Secret/{fakes.MANAGE}/main-manage-encryption-secret", refs)
        self.assertIn(f"Secret/{fakes.MANAGE}/extra-ref-secret", refs)

    def test_certificate_and_clusterissuer_references(self):
        cert = lib.extract_references(obj(f"{fakes.INST}-cert-internal-ca", "Certificate"), ctx())
        self.assertIn(f"Issuer/{fakes.CERT}/{fakes.CORE}-internal-ca-issuer", cert)
        ci = lib.extract_references(obj(f"{fakes.CORE}-internal-issuer"), ctx())
        self.assertEqual(ci, [f"Secret/{fakes.CERT}/{fakes.INST}-cert-internal-ca"])

    def test_secret_bodies_are_not_scanned(self):
        self.assertEqual(lib.extract_references(obj("cos-logging"), ctx()), [])

    def test_ca_secret_refs(self):
        self.assertEqual(lib.ca_secret_refs(obj(f"{fakes.CORE}-internal-issuer"), ctx()),
                         [(fakes.CERT, f"{fakes.INST}-cert-internal-ca")])
        self.assertEqual(lib.ca_secret_refs(obj(f"{fakes.CORE}-internal-ca-issuer"), ctx()), [])


class OrderingTests(unittest.TestCase):
    @staticmethod
    def e(i, deps=(), phase=0, kind="Secret"):
        return {"id": i, "kind": kind, "name": i, "namespace": "", "phase": phase, "depends_on": list(deps)}

    def test_dependencies_first(self):
        out = lib.order_entries([self.e("a", ["b"]), self.e("b", ["c"]), self.e("c")])
        self.assertEqual([x["id"] for x in out], ["c", "b", "a"])

    def test_deterministic_regardless_of_input_order(self):
        items = [self.e("x", phase=2), self.e("y", phase=1), self.e("z", ["y"], phase=1), self.e("w", phase=1)]
        a = [x["id"] for x in lib.order_entries(items)]
        b = [x["id"] for x in lib.order_entries(list(reversed(items)))]
        self.assertEqual(a, b)
        self.assertLess(a.index("y"), a.index("z"))

    def test_cycle_is_detected(self):
        with self.assertRaises(ValueError):
            lib.order_entries([self.e("a", ["b"]), self.e("b", ["a"])])

    def test_unknown_dependencies_are_ignored(self):
        self.assertEqual(len(lib.order_entries([self.e("a", ["external"])])), 1)


class BackupEndToEndTests(unittest.TestCase):
    """Runs backup-suite-manage.sh against the fake oc."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp(prefix="dr-test-")
        cls.bin = os.path.join(cls.tmp, "bin")
        os.makedirs(cls.bin)
        fake = os.path.join(cls.bin, "oc")
        with open(fake, "w") as fh:
            fh.write(f"#!/bin/sh\nexec {sys.executable} {os.path.join(HERE, 'fakes.py')} \"$@\"\n")
        os.chmod(fake, 0o755)
        # test-only stand-in for an approved encryption tool (NOT a real cipher)
        cls.enc = f"{sys.executable} -c \"import sys,base64;sys.stdout.buffer.write(base64.b64encode(sys.stdin.buffer.read()))\""
        cls.dec = f"{sys.executable} -c \"import sys,base64;sys.stdout.buffer.write(base64.b64decode(sys.stdin.buffer.read()))\""

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def fixture(self, objects=None, server="https://source.example:6443", context="source-ctx"):
        path = os.path.join(self.tmp, "fixture-%d.json" % len(os.listdir(self.tmp)))
        with open(path, "w") as fh:
            json.dump({"objects": objects if objects is not None else fakes.default_objects(),
                       "server": server, "context": context}, fh)
        return path

    _cache = {}

    def run_backup(self, *args, objects=None, env=None, fixture=None, fresh=False):
        """Cached for default fixtures; returns a private copy of the output when fresh=True so
        tests that tamper with files cannot affect each other."""
        key = (args, tuple(sorted((env or {}).items())))
        cacheable = objects is None and fixture is None
        if cacheable and key in self._cache:
            proc, out = self._cache[key]
        else:
            proc, out = self._run_backup(*args, objects=objects, env=env, fixture=fixture)
            if cacheable:
                self._cache[key] = (proc, out)
        if fresh:
            copy_dir = os.path.join(self.tmp, "copy-%d" % len(os.listdir(self.tmp)))
            shutil.copytree(out, copy_dir)
            return proc, copy_dir
        return proc, out

    def _run_backup(self, *args, objects=None, env=None, fixture=None):
        out = os.path.join(self.tmp, "out-%d" % len(os.listdir(self.tmp)))
        e = dict(os.environ, PATH=self.bin + os.pathsep + os.environ["PATH"], INSTANCE=fakes.INST,
                 FAKE_OC_FIXTURE=fixture or self.fixture(objects))
        e.pop("DR_ENCRYPT_CMD", None)
        e.update(env or {})
        proc = subprocess.run(["bash", os.path.join(POC, "backup-suite-manage.sh"), *args, out],
                              capture_output=True, text=True, env=e)
        return proc, out

    def manifest(self, out):
        with open(os.path.join(out, "MANIFEST.json")) as fh:
            return json.load(fh)

    def all_text(self, proc, out):
        parts = [proc.stdout, proc.stderr]
        for root, _, files in os.walk(out):
            for f in files:
                with open(os.path.join(root, f), "rb") as fh:
                    parts.append(fh.read().decode("utf-8", "replace"))
        return "\n".join(parts)

    # -- safety defaults
    def test_refuses_without_encryption_or_explicit_plaintext_optin(self):
        proc, out = self.run_backup()
        self.assertEqual(proc.returncode, 1)
        self.assertIn("no encryption configured", proc.stderr)
        self.assertFalse(os.path.exists(out))

    def test_ca_keys_require_encryption(self):
        proc, _ = self.run_backup("--allow-plaintext-local", "--include-ca-keys")
        self.assertEqual(proc.returncode, 1)
        self.assertIn("requires DR_ENCRYPT_CMD", proc.stderr)

    # -- happy path
    def test_plaintext_local_backup_ok_and_classified(self):
        proc, out = self.run_backup("--allow-plaintext-local")
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        m = self.manifest(out)
        self.assertTrue(m["validation"]["ok"], m["validation"])
        ids = {e["id"]: e for e in m["entries"]}
        # restorable set
        for i in (f"Secret/{fakes.MANAGE}/main-manage-encryption-secret",
                  f"Secret/{fakes.MANAGE}/main-manage-encryption-secret-operator",
                  f"Secret/{fakes.CORE}/{fakes.INST}-credentials-superuser",
                  f"Secret/{fakes.MANAGE}/{fakes.INST}-keys-ltpa",
                  f"Secret/{fakes.MANAGE}/extra-ref-secret"):
            self.assertTrue(ids[i]["restore_eligible"], i)
        # reference-only objects are stored without ownership stripping
        suite = ids[f"Suite/{fakes.CORE}/{fakes.INST}"]
        self.assertFalse(suite["restore_eligible"])
        self.assertEqual(suite["stripped"], {})
        # restorable objects had ownership metadata stripped and recorded
        enc = ids[f"Secret/{fakes.MANAGE}/main-manage-encryption-secret"]
        self.assertEqual(enc["stripped"]["ownerReferences"], ["ManageWorkspace/inst03-main"])
        self.assertEqual(enc["data_keys"], ["password", "token"])

    def test_extra_ref_secret_found_by_reference_closure(self):
        proc, out = self.run_backup("--allow-plaintext-local")
        m = self.manifest(out)
        e = {x["id"]: x for x in m["entries"]}[f"Secret/{fakes.MANAGE}/extra-ref-secret"]
        self.assertEqual(e["source"], "referenced")

    def test_no_duplicate_entries_and_no_duplicate_allowlist_lines(self):
        proc, out = self.run_backup("--allow-plaintext-local")
        ids = [e["id"] for e in self.manifest(out)["entries"]]
        self.assertEqual(len(ids), len(set(ids)))
        with open(os.path.join(POC, "backup-suite-manage.sh")) as fh:
            lines = [l.strip() for l in fh if l.startswith(("Secret|", "ConfigMap|", "Certificate|", "Issuer|",
                                                            "ClusterIssuer|", "Suite|", "ManageWorkspace|"))]
        self.assertEqual(len(lines), len(set(lines)), "duplicate allowlist entries")

    def test_ca_private_keys_not_exported_by_default_and_recorded(self):
        proc, out = self.run_backup("--allow-plaintext-local")
        m = self.manifest(out)
        ca = f"Secret/{fakes.CERT}/{fakes.INST}-cert-internal-ca"
        self.assertNotIn(ca, {e["id"] for e in m["entries"]})
        skipped = {s["id"]: s for s in m["skipped"]}
        self.assertEqual(skipped[ca]["status"], "skipped_policy")
        self.assertEqual(skipped[ca]["recovery_action"], "ca_continuity_decision")
        self.assertIn(ca, {n["id"] for n in m["not_backed_up"]})

    def test_reference_secrets_not_copied_by_default(self):
        proc, out = self.run_backup("--allow-plaintext-local")
        m = self.manifest(out)
        stored = {e["id"] for e in m["entries"]}
        for name, ns in (("cos-logging", fakes.MANAGE), (f"{fakes.INST}-admindashboard-cert-internal", fakes.CORE),
                         (f"{fakes.INST}-workspaceagent-tls", fakes.MANAGE)):
            self.assertNotIn(f"Secret/{ns}/{name}", stored)
        reasons = {s["id"]: s["reason"] for s in m["skipped"] if s["status"] == "skipped_policy"}
        self.assertIn(f"Secret/{fakes.MANAGE}/cos-logging", reasons)

    def test_break_glass_flag_copies_reference_secrets(self):
        proc, out = self.run_backup("--allow-plaintext-local", "--store-reference-secrets")
        stored = {e["id"] for e in self.manifest(out)["entries"]}
        self.assertIn(f"Secret/{fakes.MANAGE}/cos-logging", stored)

    def test_store_reference_secrets_sentinel_not_in_stdout_stderr_or_reports(self):
        """L-04: --store-reference-secrets copies reference-only Secret files (plaintext YAML
        with the full `data` block).  Sentinel must not appear in stdout, stderr, MANIFEST.json,
        SHA256SUMS or README.txt.  It WILL appear in the stored YAML files (that is the point
        of the flag), so those are explicitly excluded from this check."""
        proc, out = self.run_backup("--allow-plaintext-local", "--store-reference-secrets")
        reports = []
        for name in ("MANIFEST.json", "SHA256SUMS", "README.txt"):
            p = os.path.join(out, name)
            if os.path.exists(p):
                with open(p) as fh:
                    reports.append(fh.read())
        for text in [proc.stdout, proc.stderr, *reports]:
            self.assertNotIn(fakes.SENTINEL, text,
                             "sentinel must not appear in stdout/stderr/reports even with --store-reference-secrets")
            self.assertNotIn(fakes.SENTINEL_B64, text,
                             "sentinel base64 must not appear in stdout/stderr/reports even with --store-reference-secrets")

    def test_secret_values_never_in_stdout_stderr_or_reports(self):
        proc, out = self.run_backup("--allow-plaintext-local", "--discover")
        reports = []
        for name in ("MANIFEST.json", "inventory.json", "inventory.txt", "README.txt", "SHA256SUMS"):
            with open(os.path.join(out, name)) as fh:
                reports.append(fh.read())
        for text in [proc.stdout, proc.stderr, *reports]:
            self.assertNotIn(fakes.SENTINEL, text)
            self.assertNotIn(fakes.SENTINEL_B64, text)

    def test_last_applied_annotation_with_values_is_dropped(self):
        proc, out = self.run_backup("--allow-plaintext-local")
        for root, _, files in os.walk(out):
            for f in files:
                if f.endswith(".yaml"):
                    with open(os.path.join(root, f)) as fh:
                        self.assertNotIn(fakes.SENTINEL, fh.read().replace(fakes.SENTINEL_B64, ""))

    def test_permissions_are_restrictive(self):
        proc, out = self.run_backup("--allow-plaintext-local")
        for root, dirs, files in os.walk(out):
            for d in dirs + ["."]:
                self.assertEqual(stat.S_IMODE(os.stat(os.path.join(root, d)).st_mode) & 0o077, 0, os.path.join(root, d))
            for f in files:
                self.assertEqual(stat.S_IMODE(os.stat(os.path.join(root, f)).st_mode) & 0o077, 0, f)

    # -- failure handling
    def test_missing_required_resource_fails_and_is_recorded(self):
        objs = [o for o in fakes.default_objects() if o["metadata"]["name"] != "main-manage-encryption-secret"]
        proc, out = self.run_backup("--allow-plaintext-local", objects=objs)
        self.assertEqual(proc.returncode, 2)
        m = self.manifest(out)
        self.assertFalse(m["validation"]["ok"])
        self.assertTrue(any("main-manage-encryption-secret" in e and "required" in e for e in m["validation"]["errors"]))
        self.assertIn(f"Secret/{fakes.MANAGE}/main-manage-encryption-secret", {s["id"] for s in m["skipped"]})

    def test_missing_optional_resource_is_skipped_and_succeeds(self):
        objs = [o for o in fakes.default_objects() if o["metadata"]["name"] != "maximo-config"]
        proc, out = self.run_backup("--allow-plaintext-local", objects=objs)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        skipped = {s["id"]: s for s in self.manifest(out)["skipped"]}
        self.assertEqual(skipped[f"ConfigMap/{fakes.MANAGE}/maximo-config"]["status"], "not_found")

    def test_missing_suite_fails(self):
        objs = [o for o in fakes.default_objects() if o["kind"] != "Suite"]
        proc, _ = self.run_backup("--allow-plaintext-local", objects=objs)
        self.assertEqual(proc.returncode, 2)

    # -- manifest integrity
    def test_verify_detects_tampering(self):
        proc, out = self.run_backup("--allow-plaintext-local", fresh=True)
        self.assertEqual(lib.main(["verify", "--out", out]), 0)
        victim = next(e for e in self.manifest(out)["entries"] if e["kind"] == "ConfigMap")
        with open(os.path.join(out, victim["file"]), "a") as fh:
            fh.write("# tampered\n")
        self.assertEqual(lib.main(["verify", "--out", out]), 2)

    def test_verify_detects_missing_file_and_loose_permissions(self):
        proc, out = self.run_backup("--allow-plaintext-local", fresh=True)
        entries = self.manifest(out)["entries"]
        os.remove(os.path.join(out, entries[0]["file"]))
        os.chmod(os.path.join(out, entries[1]["file"]), 0o644)
        errs, _ = lib.validate_manifest(self.manifest(out), out)
        self.assertTrue(any("file missing" in e for e in errs))
        self.assertTrue(any("group/world accessible" in e for e in errs))

    def test_validate_flags_restorable_object_with_stale_owner_refs(self):
        proc, out = self.run_backup("--allow-plaintext-local", fresh=True)
        m = self.manifest(out)
        e = next(x for x in m["entries"] if x["restore_eligible"] and x["kind"] == "Secret")
        path = os.path.join(out, e["file"])
        import yaml
        with open(path) as fh:
            doc = yaml.safe_load(fh)
        doc["metadata"]["ownerReferences"] = fakes.owner("Suite", "x", "stale")
        with open(path, "w") as fh:
            yaml.safe_dump(doc, fh)
        e["sha256"] = lib.sha256_file(path)
        errs, _ = lib.validate_manifest(m, out)
        self.assertTrue(any("ownerReferences" in x for x in errs))

    # -- discovery
    def test_discovery_inventory_scopes_and_classifies(self):
        proc, out = self.run_backup("--allow-plaintext-local", "--discover")
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        with open(os.path.join(out, "inventory.json")) as fh:
            inv = json.load(fh)
        ids = {e["id"]: e for e in inv["entries"]}
        self.assertIn("CustomResourceDefinition//suites.core.mas.ibm.com", ids)
        self.assertNotIn("CustomResourceDefinition//widgets.example.com", ids)  # not a MAS group
        self.assertNotIn(f"ConfigMap/{fakes.MANAGE}/kube-root-ca.crt", ids)  # platform noise
        self.assertNotIn(f"Secret/{fakes.MANAGE}/default-token-abc", ids)
        self.assertEqual(ids["CustomResourceDefinition//suites.core.mas.ibm.com"]["backup_mode"], lib.MODE_NONE)
        self.assertIn(f"Subscription/{fakes.CORE}/ibm-mas", ids)
        self.assertIn("CatalogSource/openshift-marketplace/ibm-operator-catalog", ids)
        self.assertTrue(ids[f"Suite/{fakes.CORE}/{fakes.INST}"]["required"])
        self.assertIn(f"Secret/{fakes.MANAGE}/{fakes.INST}-keys-ltpa", inv["ambiguous"])

    def test_manifest_lists_crd_and_olm_as_recreated_not_backed_up(self):
        proc, out = self.run_backup("--allow-plaintext-local", "--discover")
        nb = {n["id"]: n for n in self.manifest(out)["not_backed_up"]}
        self.assertEqual(nb["CustomResourceDefinition//suites.core.mas.ibm.com"]["recovery_action"], "install_operator")
        self.assertIn(f"Secret/{fakes.MANAGE}/cos-logging", nb)

    def test_discovered_resources_missing_from_backup_fail_validation(self):
        proc, out = self.run_backup("--allow-plaintext-local", "--discover")
        m = self.manifest(out)
        with open(os.path.join(out, "inventory.json")) as fh:
            inv = json.load(fh)
        inv["entries"].append(dict(inv["entries"][0], id="ConfigMap/x/ghost", kind="ConfigMap",
                                   backup_mode=lib.MODE_RESTORE, name="ghost"))
        errs, _ = lib.validate_manifest(m, out, inv)
        self.assertTrue(any("ghost" in e for e in errs))

    # -- encryption interface
    def test_encrypted_backup_has_no_plaintext_secret_files(self):
        proc, out = self.run_backup("--include-ca-keys", env={"DR_ENCRYPT_CMD": self.enc})
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        m = self.manifest(out)
        secrets = [e for e in m["entries"] if e["kind"] == "Secret"]
        self.assertTrue(secrets)
        for e in secrets:
            self.assertTrue(e["encrypted"] and e["file"].endswith(".enc"))
            with open(os.path.join(out, e["file"]), "rb") as fh:
                self.assertNotIn(b"kind: Secret", fh.read())
        self.assertIn(f"Secret/{fakes.CERT}/{fakes.INST}-cert-internal-ca", {e["id"] for e in secrets})
        self.assertEqual(lib.main(["verify", "--out", out]), 0)

    def test_failing_encrypt_command_aborts_store(self):
        proc, out = self.run_backup(env={"DR_ENCRYPT_CMD": f"{sys.executable} -c 'import sys; sys.exit(3)'"})
        self.assertEqual(proc.returncode, 2)

    def test_store_failure_on_required_resource_recorded_in_manifest(self):
        """F-12/F-03 regression: a store/encrypt failure on a required resource must:
        - cause the backup to exit nonzero,
        - appear in manifest["skipped"] with status "failed",
        - set manifest["validation"]["ok"] to False,
        - leave other successfully stored resources still present in the manifest.

        The encrypt command matches exactly 'name: main-manage-encryption-secret\\n' so it
        fails only on that one Secret and not on main-manage-encryption-secret-operator.
        """
        target = "main-manage-encryption-secret"
        target_id = f"Secret/{fakes.MANAGE}/{target}"
        # Match exactly 'name: main-manage-encryption-secret\n' (newline via bytes([10])) so the
        # -operator variant (different suffix) is not caught.  shlex.split passes the bytes
        # correctly because encrypt_bytes uses subprocess.run, not the shell.
        selective_fail_enc = (
            f"{sys.executable} -c \""
            f"import sys, base64; "
            f"data = sys.stdin.buffer.read(); "
            f"sys.exit(5) if (b'name: {target}' + bytes([10])) in data "
            f"else sys.stdout.buffer.write(base64.b64encode(data))"
            f"\""
        )
        proc, out = self.run_backup(env={"DR_ENCRYPT_CMD": selective_fail_enc})
        # 1. Backup must exit nonzero
        self.assertNotEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        # 2. A MANIFEST.json must exist (backup ran far enough to build it)
        m = self.manifest(out)
        skipped_ids = {s["id"]: s for s in m["skipped"]}
        # 3. The failed required resource must appear in skipped with status "failed"
        self.assertIn(target_id, skipped_ids, f"expected {target_id} in skipped; got {list(skipped_ids)[:5]}")
        self.assertEqual(skipped_ids[target_id]["status"], "failed")
        self.assertIn("store command failed", skipped_ids[target_id]["reason"])
        # 4. manifest["validation"]["ok"] must be False
        self.assertFalse(m["validation"]["ok"],
                         f"validation should fail; errors={m['validation']['errors']}")
        self.assertTrue(any(target in e for e in m["validation"]["errors"]),
                        f"expected an error mentioning the failed resource; got {m['validation']['errors']}")
        # 5. Other successfully stored resources still appear in the manifest entries
        stored_ids = {e["id"] for e in m["entries"]}
        suite_id = f"Suite/{fakes.CORE}/{fakes.INST}"
        self.assertIn(suite_id, stored_ids, "Suite CR should still be present in entries")
        # -operator has a different name so the encrypt command passes it through
        other_enc_id = f"Secret/{fakes.MANAGE}/main-manage-encryption-secret-operator"
        self.assertIn(other_enc_id, stored_ids,
                      "second encryption Secret (different name) should be stored successfully")



    # -- restore planner / tool, driven from a real backup
    def test_plan_is_deterministic_staged_and_excludes_owner_managed(self):
        proc, out = self.run_backup("--allow-plaintext-local", "--discover")
        m = restore.load_backup(out)
        p1 = restore.render_plan(restore.build_plan(m))
        p2 = restore.render_plan(restore.build_plan(copy.deepcopy(m)))
        self.assertEqual(p1, p2)
        plan = restore.build_plan(m)
        self.assertEqual(plan["problems"], [])
        stages = [s["stage"] for s in plan["steps"]]
        self.assertEqual(stages, sorted(stages))
        applied = {s["id"] for s in plan["steps"] if s["action"] == "apply"}
        self.assertIn(f"Secret/{fakes.MANAGE}/main-manage-encryption-secret", applied)
        self.assertNotIn(f"Suite/{fakes.CORE}/{fakes.INST}", applied)
        self.assertNotIn(f"ManageWorkspace/{fakes.MANAGE}/{fakes.INST}-main", applied)
        self.assertTrue(any("CA key pairs were NOT exported" in b for b in plan["manual_blockers"]))
        self.assertTrue(any("plaintext" in b for b in plan["manual_blockers"]))

    def test_plan_refuses_tampered_backup(self):
        proc, out = self.run_backup("--allow-plaintext-local", fresh=True)
        victim = next(e for e in self.manifest(out)["entries"] if e["kind"] == "ConfigMap")
        with open(os.path.join(out, victim["file"]), "a") as fh:
            fh.write("# tampered\n")
        with self.assertRaises(restore.RestoreError):
            restore.load_backup(out)

    def test_optin_selection_includes_ca_secret_in_certificate_stage(self):
        proc, out = self.run_backup("--include-ca-keys", env={"DR_ENCRYPT_CMD": self.enc})
        m = restore.load_backup(out)
        base = restore.build_plan(m)
        opt = restore.build_plan(m, include_optin=True)
        ca = f"Secret/{fakes.CERT}/{fakes.INST}-cert-internal-ca"
        self.assertNotIn(ca, {s["id"] for s in base["steps"]})
        step = next(s for s in opt["steps"] if s["id"] == ca)
        self.assertEqual(step["stage"], 6)

    # -- F-09/M-02 regression: cross-stage dependency ordering
    def test_cross_stage_dependency_never_applied_before_prerequisite(self):
        """F-09: when a restorable resource depends on another restorable resource in a
        higher-numbered stage, the stage-propagation fix must raise the dependent's stage
        so that, after the final sort, the prerequisite always appears first.

        Simulates the pathological case: a stage-5 ConfigMap that spec-references a
        stage-6 cert-manager Secret (e.g. a truststore that embeds a CA cert).  Without
        stage propagation the sort would place the ConfigMap before the Secret.
        """
        import copy as _copy
        proc, out = self.run_backup("--include-ca-keys", env={"DR_ENCRYPT_CMD": self.enc})
        m = restore.load_backup(out)
        # Inject a synthetic dependency: find one restore-eligible Secret (stage 5) and
        # one opt-in CA Secret (stage 6); make the stage-5 resource depend on the stage-6 one.
        entries = {e["id"]: e for e in m["entries"]}
        ca_id = f"Secret/{fakes.CERT}/{fakes.INST}-cert-internal-ca"
        stage5_id = next(e["id"] for e in m["entries"]
                         if e.get("restore_eligible") and e["kind"] == "Secret"
                         and e["id"] != ca_id)
        # Patch the manifest in-memory: add a cross-stage dep on the CA Secret
        m2 = _copy.deepcopy(m)
        for e in m2["entries"]:
            if e["id"] == stage5_id:
                if ca_id not in e.get("depends_on", []):
                    e.setdefault("depends_on", []).append(ca_id)
        plan = restore.build_plan(m2, include_optin=True)
        self.assertEqual(plan["problems"], [], f"expected no ordering problems; got {plan['problems']}")
        position = {s["id"]: s["order"] for s in plan["steps"]}
        if ca_id in position and stage5_id in position:
            self.assertLess(position[ca_id], position[stage5_id],
                            f"CA Secret (stage 6, order {position[ca_id]}) must come before "
                            f"its dependent (stage 5→6 after propagation, order {position[stage5_id]})")

    def fake_runner(self, server, context="target-ctx", existing_ns=(fakes.CORE, fakes.MANAGE, fakes.CERT),
                    apis=("cert-manager.io", "apps.mas.ibm.com", "core.mas.ibm.com"), fail_on=None, exists=()):
        calls = []

        def run(args, input_text=None):
            calls.append((list(args), input_text))
            if args[:2] == ["whoami", "--show-server"]:
                return 0, server + "\n", ""
            if args[:2] == ["config", "current-context"]:
                return 0, context + "\n", ""
            if args[:2] == ["get", "namespace"]:
                return (0, "", "") if args[2] in existing_ns else (1, "", "NotFound")
            if args[0] == "api-resources":
                grp = args[1].split("=")[1]
                return (0, "x\n", "") if grp in apis else (0, "", "")
            if args[0] in ("create", "apply"):
                name = next((l.split(":", 1)[1].strip() for l in input_text.splitlines() if l.startswith("  name:")), "")
                if name in exists:
                    return 1, "", 'Error from server (AlreadyExists): secrets "x" already exists'
                if fail_on and name == fail_on:
                    return 1, "", "Error from server (Invalid): boom"
                return 0, "ok", ""
            return 99, "", "unexpected"
        run.calls = calls
        return run

    def plan_for(self):
        """Return (out, manifest, plan) for a plaintext backup.  Use for dry-run and
        preflight tests only; --execute requires an encrypted backup (see enc_plan_for)."""
        proc, out = self.run_backup("--allow-plaintext-local", fresh=True)
        m = restore.load_backup(out)
        return out, m, restore.build_plan(m)

    def enc_plan_for(self):
        """Return (out, manifest, plan, dec_cmd) for an encrypted backup.  Required for
        any test that calls apply_plan with execute=True (F-08: plaintext gate)."""
        proc, out = self.run_backup(env={"DR_ENCRYPT_CMD": self.enc}, fresh=True)
        m = restore.load_backup(out)
        return out, m, restore.build_plan(m), self.dec

    def test_apply_refuses_source_cluster(self):
        out, m, plan = self.plan_for()
        run = self.fake_runner("https://source.example:6443", context="other")
        with self.assertRaisesRegex(restore.RestoreError, "SOURCE cluster"):
            restore.apply_plan(out, m, plan, "https://source.example:6443", False, False, run)
        self.assertFalse([c for c in run.calls if c[0][0] in ("create", "apply")])

    def test_apply_refuses_source_context(self):
        out, m, plan = self.plan_for()
        run = self.fake_runner("https://target.example:6443", context="source-ctx")
        with self.assertRaisesRegex(restore.RestoreError, "source context"):
            restore.apply_plan(out, m, plan, "https://target.example:6443", False, False, run)


    # -- F-02 regression: decrypt_bytes must raise on empty stdout
    def test_decrypt_bytes_raises_on_empty_output(self):
        """A decrypt command that exits 0 but writes nothing must raise, not return empty bytes."""
        empty_cmd = f"{sys.executable} -c 'import sys; sys.exit(0)'"
        with self.assertRaisesRegex(RuntimeError, "no output"):
            lib.decrypt_bytes(b"somedata", empty_cmd)

    def test_decrypt_bytes_raises_on_nonzero_exit(self):
        """Existing behaviour: non-zero exit raises RuntimeError."""
        fail_cmd = f"{sys.executable} -c 'import sys; sys.exit(2)'"
        with self.assertRaisesRegex(RuntimeError, "decrypt command failed"):
            lib.decrypt_bytes(b"somedata", fail_cmd)

    def test_encrypted_restore_fails_cleanly_when_decrypt_returns_empty(self):
        """End-to-end: a decrypt command that succeeds but emits nothing is caught as RestoreError."""
        proc, out = self.run_backup(env={"DR_ENCRYPT_CMD": self.enc}, fresh=True)
        m = restore.load_backup(out)
        plan = restore.build_plan(m)
        run = self.fake_runner("https://target.example:6443")
        empty_dec = f"{sys.executable} -c 'import sys; sys.exit(0)'"
        with self.assertRaises(restore.RestoreError):
            restore.apply_plan(out, m, plan, "https://target.example:6443", False, False, run,
                               decrypt_cmd=empty_dec)

    # -- F-06 regression: preflight must block when source identity is empty
    def test_apply_refuses_when_source_server_empty(self):
        """A backup with no source_server recorded must be blocked by preflight."""
        out, m, plan = self.plan_for()
        m["source_server"] = ""
        run = self.fake_runner("https://target.example:6443")
        with self.assertRaisesRegex(restore.RestoreError, "no source_server recorded"):
            restore.apply_plan(out, m, plan, "https://target.example:6443", False, False, run)

    def test_apply_refuses_when_source_context_empty(self):
        """A backup with no source_context recorded must be blocked by preflight."""
        out, m, plan = self.plan_for()
        m["source_context"] = ""
        run = self.fake_runner("https://target.example:6443")
        with self.assertRaisesRegex(restore.RestoreError, "no source_context recorded"):
            restore.apply_plan(out, m, plan, "https://target.example:6443", False, False, run)

    def test_apply_refuses_when_both_source_identity_empty(self):
        """Both source identity fields empty: both errors must be reported."""
        out, m, plan = self.plan_for()
        m["source_server"] = ""
        m["source_context"] = ""
        run = self.fake_runner("https://target.example:6443")
        with self.assertRaises(restore.RestoreError) as cm:
            restore.apply_plan(out, m, plan, "https://target.example:6443", False, False, run)
        msg = str(cm.exception)
        self.assertIn("source_server", msg)
        self.assertIn("source_context", msg)

    def test_backup_warns_when_source_identity_unavailable(self):
        """The backup script must emit a WARNING to stderr when oc fails to return a server/context."""
        # Produce a fixture whose fake-oc returns empty server and context
        objs = fakes.default_objects()
        fix_path = os.path.join(self.tmp, "fixture-empty-id.json")
        with open(fix_path, "w") as fh:
            json.dump({"objects": objs, "server": "", "context": ""}, fh)
        proc, out = self.run_backup("--allow-plaintext-local", fixture=fix_path)
        self.assertIn("DEGRADED", proc.stderr)


    def test_apply_requires_typed_target_confirmation(self):
        out, m, plan = self.plan_for()
        run = self.fake_runner("https://target.example:6443")
        with self.assertRaisesRegex(restore.RestoreError, "does not equal"):
            restore.apply_plan(out, m, plan, "https://wrong.example:6443", False, False, run)

    def test_apply_requires_namespaces(self):
        out, m, plan = self.plan_for()
        run = self.fake_runner("https://target.example:6443", existing_ns=(fakes.CORE,))
        with self.assertRaisesRegex(restore.RestoreError, "does not exist on target"):
            restore.apply_plan(out, m, plan, "https://target.example:6443", False, False, run)

    def test_apply_defaults_to_server_dry_run(self):
        out, m, plan = self.plan_for()
        run = self.fake_runner("https://target.example:6443")
        rep = restore.apply_plan(out, m, plan, "https://target.example:6443", False, False, run)
        self.assertTrue(rep["ok"])
        writes = [c for c in run.calls if c[0][0] in ("create", "apply")]
        self.assertTrue(writes)
        for args, _ in writes:
            self.assertEqual(args[0], "create")
            self.assertIn("--dry-run=server", args)
        self.assertTrue(all(r["result"] == "dry-run-ok" for r in rep["results"]))

    def test_apply_execute_uses_create_and_never_overwrites(self):
        # execute=True requires an encrypted backup (F-08 gate); use enc_plan_for.
        out, m, plan, dec = self.enc_plan_for()
        victim = "main-manage-encryption-secret"
        run = self.fake_runner("https://target.example:6443", exists=(victim,))
        rep = restore.apply_plan(out, m, plan, "https://target.example:6443", True, False, run,
                                 decrypt_cmd=dec)
        res = {r["id"]: r for r in rep["results"]}
        self.assertEqual(res[f"Secret/{fakes.MANAGE}/{victim}"]["result"], "skipped_exists")
        for args, _ in [c for c in run.calls if c[0][0] in ("create", "apply")]:
            self.assertEqual(args[0], "create")
            self.assertIn("--dry-run=none", args)

    def test_apply_stops_at_first_failure(self):
        # execute=True requires an encrypted backup (F-08 gate); use enc_plan_for.
        out, m, plan, dec = self.enc_plan_for()
        first = next(s for s in plan["steps"] if s["action"] == "apply")
        run = self.fake_runner("https://target.example:6443", fail_on=first["name"])
        rep = restore.apply_plan(out, m, plan, "https://target.example:6443", True, False, run,
                                 decrypt_cmd=dec)
        self.assertFalse(rep["ok"])
        self.assertEqual(rep["results"][0]["result"], "failed")
        self.assertTrue(all(r["result"] == "not_attempted" for r in rep["results"][1:]))

    def test_apply_fails_when_crd_missing_on_target(self):
        # Uses a plaintext backup for file manipulation; CRD check runs before any write,
        # so execute=False is sufficient to exercise the api_available gate (F-08 is not
        # triggered because execute=False).
        out, m, plan = self.plan_for()
        # restorable set is only core v1 kinds here, so force a custom API into the manifest
        entry = next(e for e in m["entries"] if e["restore_eligible"])
        path = os.path.join(out, entry["file"])
        import yaml
        with open(path) as fh:
            doc = yaml.safe_load(fh)
        doc["apiVersion"], doc["kind"] = "widgets.example.com/v1", "Widget"
        with open(path, "w") as fh:
            yaml.safe_dump(doc, fh)
        os.chmod(path, 0o600)
        entry["sha256"] = lib.sha256_file(path)
        run = self.fake_runner("https://target.example:6443", apis=())
        rep = restore.apply_plan(out, m, plan, "https://target.example:6443", False, False, run)
        self.assertFalse(rep["ok"])
        self.assertIn("API/CRD not installed", rep["results"][0]["detail"])

    # -- F-08 regression: plaintext backup must be rejected by --execute
    def test_execute_refused_for_plaintext_backup(self):
        """F-08: apply_plan with execute=True must raise RestoreError for a plaintext backup."""
        out, m, plan = self.plan_for()
        run = self.fake_runner("https://target.example:6443")
        with self.assertRaisesRegex(restore.RestoreError, "not encrypted"):
            restore.apply_plan(out, m, plan, "https://target.example:6443", True, False, run)

    def test_execute_refused_for_plaintext_backup_no_oc_writes(self):
        """F-08: when plaintext gate fires, no mutating oc call (create/apply) must occur."""
        out, m, plan = self.plan_for()
        run = self.fake_runner("https://target.example:6443")
        try:
            restore.apply_plan(out, m, plan, "https://target.example:6443", True, False, run)
        except restore.RestoreError:
            pass
        mutating = [c for c in run.calls if c[0][0] in ("create", "apply")]
        self.assertEqual(mutating, [], f"expected no mutating oc calls; got {mutating}")

    def test_dry_run_allowed_for_plaintext_backup(self):
        """F-08: dry-run (execute=False) must remain available for a plaintext backup."""
        out, m, plan = self.plan_for()
        run = self.fake_runner("https://target.example:6443")
        rep = restore.apply_plan(out, m, plan, "https://target.example:6443", False, False, run)
        self.assertTrue(rep["ok"])
        writes = [c for c in run.calls if c[0][0] in ("create", "apply")]
        self.assertTrue(writes, "expected server dry-run calls")
        for args, _ in writes:
            self.assertIn("--dry-run=server", args)
        self.assertTrue(all(r["result"] == "dry-run-ok" for r in rep["results"]))

    def test_execute_allowed_for_encrypted_backup(self):
        """F-08: an encrypted backup must pass the plaintext gate and reach actual execution."""
        out, m, plan, dec = self.enc_plan_for()
        run = self.fake_runner("https://target.example:6443")
        rep = restore.apply_plan(out, m, plan, "https://target.example:6443", True, False, run,
                                 decrypt_cmd=dec)
        self.assertTrue(rep["ok"])
        writes = [c for c in run.calls if c[0][0] in ("create", "apply")]
        self.assertTrue(writes, "expected actual create calls")
        for args, _ in writes:
            self.assertIn("--dry-run=none", args)
        self.assertTrue(all(r["result"] == "created" for r in rep["results"]))


    # -- F-11 regression: ok_no_skips / skipped_required_ids / warnings
    def test_ok_no_skips_false_when_required_secret_skipped(self):
        """F-11: a required resource returning skipped_exists must set ok_no_skips=False."""
        out, m, plan, dec = self.enc_plan_for()
        # main-manage-encryption-secret is required=True (state-bearing, hint-matched)
        victim = "main-manage-encryption-secret"
        run = self.fake_runner("https://target.example:6443", exists=(victim,))
        rep = restore.apply_plan(out, m, plan, "https://target.example:6443", True, False, run,
                                 decrypt_cmd=dec)
        self.assertTrue(rep["ok"], "ok must still be True when only skip occurred")
        self.assertFalse(rep["ok_no_skips"], "ok_no_skips must be False when a required resource was skipped")

    def test_skipped_required_ids_populated_for_required_skip(self):
        """F-11: skipped_required_ids must list the id of the skipped required resource."""
        out, m, plan, dec = self.enc_plan_for()
        victim = "main-manage-encryption-secret"
        run = self.fake_runner("https://target.example:6443", exists=(victim,))
        rep = restore.apply_plan(out, m, plan, "https://target.example:6443", True, False, run,
                                 decrypt_cmd=dec)
        victim_id = f"Secret/{fakes.MANAGE}/{victim}"
        self.assertIn(victim_id, rep["skipped_required_ids"])

    def test_warning_present_for_required_skip(self):
        """F-11: warnings must contain a message mentioning the skipped required resource id."""
        out, m, plan, dec = self.enc_plan_for()
        victim = "main-manage-encryption-secret"
        run = self.fake_runner("https://target.example:6443", exists=(victim,))
        rep = restore.apply_plan(out, m, plan, "https://target.example:6443", True, False, run,
                                 decrypt_cmd=dec)
        victim_id = f"Secret/{fakes.MANAGE}/{victim}"
        self.assertTrue(any(victim_id in w for w in rep["warnings"]),
                        f"expected a warning mentioning {victim_id}; got {rep['warnings']}")

    def test_ok_no_skips_true_when_no_skips(self):
        """F-11: ok_no_skips must be True when every resource is created (no skips)."""
        out, m, plan, dec = self.enc_plan_for()
        run = self.fake_runner("https://target.example:6443")  # nothing pre-exists
        rep = restore.apply_plan(out, m, plan, "https://target.example:6443", True, False, run,
                                 decrypt_cmd=dec)
        self.assertTrue(rep["ok"])
        self.assertTrue(rep["ok_no_skips"], "ok_no_skips must be True when all results are 'created'")
        self.assertEqual(rep["skipped_required_ids"], [])
        self.assertEqual(rep["warnings"], [])

    def test_dry_run_ok_no_skips_true(self):
        """F-11: dry-run returns dry-run-ok (not skipped_exists), so ok_no_skips must be True
        even when the resource already exists on the target (server dry-run returns rc=0)."""
        out, m, plan = self.plan_for()  # plaintext is fine for dry-run
        run = self.fake_runner("https://target.example:6443")
        rep = restore.apply_plan(out, m, plan, "https://target.example:6443", False, False, run)
        self.assertTrue(rep["ok"])
        self.assertTrue(rep["ok_no_skips"],
                        "dry-run must never produce skipped_exists; ok_no_skips must be True")
        self.assertEqual(rep["skipped_required_ids"], [])
        self.assertEqual(rep["warnings"], [])



    def test_restore_report_has_no_secret_values(self):
        out, m, plan = self.plan_for()
        run = self.fake_runner("https://target.example:6443")
        rep = restore.apply_plan(out, m, plan, "https://target.example:6443", False, False, run)
        text = json.dumps(rep) + restore.render_plan(plan)
        self.assertNotIn(fakes.SENTINEL, text)
        self.assertNotIn(fakes.SENTINEL_B64, text)

    def test_encrypted_restore_needs_decrypt_command(self):
        proc, out = self.run_backup(env={"DR_ENCRYPT_CMD": self.enc}, fresh=True)
        m = restore.load_backup(out)
        plan = restore.build_plan(m)
        run = self.fake_runner("https://target.example:6443")
        with self.assertRaisesRegex(restore.RestoreError, "DR_DECRYPT_CMD"):
            restore.apply_plan(out, m, plan, "https://target.example:6443", False, False, run)
        rep = restore.apply_plan(out, m, plan, "https://target.example:6443", False, False, run, decrypt_cmd=self.dec)
        self.assertTrue(rep["ok"])


class DiscoveryUnitTests(unittest.TestCase):
    def test_discover_with_injected_runner_has_no_secret_data(self):
        cluster = fakes.FakeCluster()

        def runner(args):
            if args[0] == "namespace":
                return cluster.get(args)
            return cluster.get(args)
        inv = discover.discover(fakes.INST, NS, runner=runner)
        self.assertNotIn(fakes.SENTINEL, json.dumps(inv))
        self.assertNotIn(fakes.SENTINEL_B64, json.dumps(inv))
        self.assertTrue(inv["entries"])
        self.assertEqual(inv["notes"], [])

    def test_missing_namespace_is_noted_not_fatal(self):
        cluster = fakes.FakeCluster([o for o in fakes.default_objects() if o["metadata"]["name"] != fakes.SYNC])
        inv = discover.discover(fakes.INST, NS, runner=cluster.get)
        self.assertTrue(any(fakes.SYNC in n for n in inv["notes"]))

    def test_add_guard_rejects_secret_with_data_present(self):
        """L-01: discover.add() must raise AssertionError when passed a Secret that still
        has data/stringData (i.e. items() was bypassed).  This prevents accidental credential
        leakage if a future discovery source forgets to strip Secret bodies first.

        The guard lives in the add() closure.  The only code path that can reach add() with
        a Secret that still has data is one that bypasses items().  We simulate this by
        returning a raw Secret as the response to the namespace fetch (kind field mis-set to
        "Secret" with data) so that add() is called directly on it — replicating the class of
        bug the guard defends against.
        """
        raw_secret = fakes.secret("leaky", fakes.MANAGE)  # has data: {password: SENTINEL_B64}
        self.assertIn("data", raw_secret)
        with self.assertRaises(AssertionError, msg="add() must abort on a Secret with data still present"):
            def leaky_runner(args):
                # Return the raw Secret (with data) as if it were the Namespace response for
                # the manage namespace — bypassing items() so the guard in add() must fire.
                if args[0] == "namespace" and args[1] == fakes.MANAGE:
                    return raw_secret
                return fakes.FakeCluster().get(args)
            discover.discover(fakes.INST, NS, runner=leaky_runner)



class DiscoveryTimeoutTests(unittest.TestCase):
    """Offline tests for timeout handling in discover.py.
    Uses runners that return the _TIMED_OUT sentinel; no subprocess or cluster access."""

    def _timeout_runner(self, timeout_on):
        """Return a runner that returns _TIMED_OUT for any args[0] matching timeout_on,
        and delegates everything else to FakeCluster.  timeout_on can be a string or a set."""
        if isinstance(timeout_on, str):
            timeout_on = {timeout_on}
        cluster = fakes.FakeCluster()

        def runner(args):
            resource = args[0] if args else ""
            if any(t in resource for t in timeout_on):
                return discover._TIMED_OUT
            return cluster.get(args)
        return runner

    def test_timeout_on_crd_list_sets_partial_discovery(self):
        """A timeout fetching CRDs must set partial_discovery=True in the inventory."""
        run = self._timeout_runner("customresourcedefinitions")
        inv = discover.discover(fakes.INST, NS, runner=run)
        self.assertTrue(inv["partial_discovery"],
                        "partial_discovery must be True when a query times out")

    def test_timeout_produces_note_with_timeout_prefix(self):
        """A timed-out query must appear in inv['notes'] with a TIMEOUT: prefix."""
        run = self._timeout_runner("customresourcedefinitions")
        inv = discover.discover(fakes.INST, NS, runner=run)
        timeout_notes = [n for n in inv["notes"] if n.startswith("TIMEOUT:")]
        self.assertTrue(timeout_notes,
                        f"expected at least one TIMEOUT note; got notes={inv['notes']}")
        self.assertIn("customresourcedefinitions", timeout_notes[0])

    def test_timeout_on_one_resource_does_not_stop_remaining_queries(self):
        """A timeout on CRD listing must not prevent namespace-scan (configmaps/secrets)
        from completing; the inventory should still contain namespace-scan entries."""
        run = self._timeout_runner("customresourcedefinitions")
        inv = discover.discover(fakes.INST, NS, runner=run)
        # Namespace-scan entries (configmaps/secrets) should still be present
        sources = {e.get("source") for e in inv["entries"]}
        self.assertIn("namespace-scan", sources,
                      "namespace-scan entries must still appear after a CRD timeout")

    def test_no_timeout_sets_partial_discovery_false(self):
        """Normal (no-timeout) discovery must set partial_discovery=False."""
        cluster = fakes.FakeCluster()
        inv = discover.discover(fakes.INST, NS, runner=cluster.get)
        self.assertFalse(inv.get("partial_discovery", True),
                         "partial_discovery must be False (or absent) on a complete run")

    def test_timeout_on_namespace_fetch_sets_partial_discovery(self):
        """A timeout on the namespace fetch itself must also set partial_discovery=True."""
        cluster = fakes.FakeCluster()

        def runner(args):
            if args[0] == "namespace" and args[1] == fakes.CORE:
                return discover._TIMED_OUT
            return cluster.get(args)

        inv = discover.discover(fakes.INST, NS, runner=runner)
        self.assertTrue(inv["partial_discovery"])
        self.assertTrue(any("TIMEOUT" in n and fakes.CORE in n for n in inv["notes"]),
                        f"expected a TIMEOUT note for {fakes.CORE}; got {inv['notes']}")

    def test_timeout_sentinel_not_leaked_into_inventory(self):
        """The _TIMED_OUT sentinel object must never appear in the JSON-serialised inventory."""
        run = self._timeout_runner("customresourcedefinitions")
        inv = discover.discover(fakes.INST, NS, runner=run)
        # Must be JSON-serialisable (no non-serialisable sentinel in output)
        serialised = json.dumps(inv)
        # Sentinel string representation must not appear in notes or entries
        self.assertNotIn("_TIMED_OUT", serialised)
        self.assertNotIn("object at 0x", serialised)

    def test_timeout_note_contains_no_secret_values(self):
        """Timeout notes must not contain any Secret credential values."""
        run = self._timeout_runner("secrets")
        inv = discover.discover(fakes.INST, NS, runner=run)
        notes_text = json.dumps(inv["notes"])
        self.assertNotIn(fakes.SENTINEL, notes_text)
        self.assertNotIn(fakes.SENTINEL_B64, notes_text)

    def test_items_returns_timed_out_sentinel_directly(self):
        """discover.items() must propagate _TIMED_OUT from the runner without modification."""
        def always_timeout(args):
            return discover._TIMED_OUT

        result = discover.items(always_timeout, "secrets", namespace="ns1")
        self.assertIs(result, discover._TIMED_OUT,
                      "items() must return the _TIMED_OUT sentinel unchanged")

    def test_oc_json_timeout(self):
        """oc_json must return within the timeout even when the subprocess is slow.
        Uses a real subprocess call with a tiny timeout so no cluster is needed:
        oc is either absent (subprocess raises FileNotFoundError → None) or present but
        starved of time (TimeoutExpired → _TIMED_OUT).  Either way it must not block."""
        import time as _time
        start = _time.monotonic()
        result = discover.oc_json(["namespaces"], timeout=0.01, request_timeout="")
        elapsed = _time.monotonic() - start
        self.assertIn(result, (discover._TIMED_OUT, None),
                      f"oc_json must return _TIMED_OUT or None quickly; got {result!r}")
        self.assertLess(elapsed, 5.0,
                        f"oc_json must not block indefinitely (elapsed={elapsed:.2f}s)")


class StaticChecks(unittest.TestCase):
    def test_scripts_do_not_contain_mutating_cluster_commands(self):
        import re
        pat = re.compile(r"\boc\s+(apply|create|delete|patch|replace|annotate|label|scale|rollout|adm)\b")
        for f in ("backup-suite-manage.sh", "discover.py", "dr_lib.py", "backup.sh"):
            with open(os.path.join(POC, f)) as fh:
                for n, line in enumerate(fh, 1):
                    if line.lstrip().startswith("#"):
                        continue
                    self.assertIsNone(pat.search(line), f"{f}:{n} contains a mutating oc command")


if __name__ == "__main__":
    unittest.main()

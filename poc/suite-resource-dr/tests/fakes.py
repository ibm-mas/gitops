"""Fake cluster used by the DR POC tests.  All values are synthetic; the only "secret" content is a
sentinel string that the tests assert never appears in logs, inventories or manifests."""
from __future__ import annotations

import base64
import copy
import json
import sys

SENTINEL = "TOPSECRETSENTINEL-9f3a"
SENTINEL_B64 = base64.b64encode(SENTINEL.encode()).decode()

INST = "inst03"
CORE, MANAGE, SYNC, CERT = f"mas-{INST}-core", f"mas-{INST}-manage", f"mas-{INST}-syncres", "cert-manager"
SUITE_UID = "11111111-aaaa-bbbb-cccc-000000000001"
WS_UID = "11111111-aaaa-bbbb-cccc-000000000002"


def meta(name, ns=None, manager="ibm-mas", **kw):
    m = {"name": name, "uid": "uid-" + name, "resourceVersion": "42", "creationTimestamp": "2026-01-01T00:00:00Z",
         "generation": 3, "managedFields": [{"manager": manager, "operation": "Update"}]}
    if ns:
        m["namespace"] = ns
    m.update(kw)
    return m


def owner(kind, name, uid):
    return [{"apiVersion": "apps.mas.ibm.com/v1", "kind": kind, "name": name, "uid": uid, "controller": True}]


def secret(name, ns, **kw):
    return {"apiVersion": "v1", "kind": "Secret", "type": "Opaque", "metadata": meta(name, ns, **kw),
            "data": {"password": SENTINEL_B64, "token": SENTINEL_B64}}


def configmap(name, ns, **kw):
    return {"apiVersion": "v1", "kind": "ConfigMap", "metadata": meta(name, ns, **kw), "data": {"k": "v"}}


def default_objects():
    track = {"argocd.argoproj.io/tracking-id": f"{INST}-suite:core.mas.ibm.com/Suite:{CORE}/{INST}",
             "kubectl.kubernetes.io/last-applied-configuration": "{\"dup\": \"" + SENTINEL + "\"}"}
    primary = {"operator-sdk/primary-resource": f"{CORE}/{INST}"}
    return [
        {"apiVersion": "v1", "kind": "Namespace", "metadata": meta(CORE)},
        {"apiVersion": "v1", "kind": "Namespace", "metadata": meta(MANAGE)},
        {"apiVersion": "v1", "kind": "Namespace", "metadata": meta(SYNC)},
        {"apiVersion": "v1", "kind": "Namespace", "metadata": meta(CERT)},
        {"apiVersion": "core.mas.ibm.com/v1", "kind": "Suite",
         "metadata": meta(INST, CORE, annotations=dict(track), finalizers=["core.mas.ibm.com/finalizer"],
                          labels={"mas.ibm.com/instanceId": INST}, manager="argocd-controller"),
         "spec": {"domain": "x.example.com", "license": {"accept": True}}, "status": {"conditions": []}},
        {"apiVersion": "apps.mas.ibm.com/v1", "kind": "ManageWorkspace",
         "metadata": meta(f"{INST}-main", MANAGE, annotations=dict(track), finalizers=["apps.mas.ibm.com/finalizer"],
                          manager="argocd-controller"),
         "spec": {"settings": {"db": {"encryptionSecret": "main-manage-encryption-secret"}},
                  "extra": {"secretName": "extra-ref-secret"}}, "status": {"phase": "Ready"}},
        # state-bearing, operator generated -> backup_restore_pre_reconcile
        secret("main-manage-encryption-secret", MANAGE, ownerReferences=owner("ManageWorkspace", f"{INST}-main", WS_UID)),
        secret("main-manage-encryption-secret-operator", MANAGE,
               ownerReferences=owner("ManageWorkspace", f"{INST}-main", WS_UID)),
        secret(f"{INST}-credentials-superuser", CORE, ownerReferences=owner("Suite", INST, SUITE_UID)),
        # operator generated, regenerable -> reference only
        secret(f"{INST}-keys-jwt", CORE, ownerReferences=owner("Suite", INST, SUITE_UID)),
        secret(f"{INST}-admindashboard-cert-internal", CORE, ownerReferences=owner("Suite", INST, SUITE_UID)),
        # unmarked, matches state hint -> ambiguous restorable
        secret(f"{INST}-keys-ltpa", MANAGE),
        # gitops/AWS-backed -> reference only
        secret("cos-logging", MANAGE, annotations=dict(track)),
        # manually applied -> restorable, found only through ref closure
        secret("extra-ref-secret", MANAGE, manager="kubectl-client-side-apply"),
        configmap(f"{INST}-suite-reconcile", CORE, ownerReferences=owner("Suite", INST, SUITE_UID)),
        configmap("maximo-config", MANAGE, ownerReferences=owner("ManageWorkspace", f"{INST}-main", WS_UID)),
        # CA chain
        {"apiVersion": "cert-manager.io/v1", "kind": "Issuer",
         "metadata": meta(f"{CORE}-internal-ca-issuer", CERT, annotations=dict(primary)),
         "spec": {"selfSigned": {}}},
        {"apiVersion": "cert-manager.io/v1", "kind": "Certificate",
         "metadata": meta(f"{INST}-cert-internal-ca", CERT, annotations=dict(primary)),
         "spec": {"isCA": True, "secretName": f"{INST}-cert-internal-ca",
                  "issuerRef": {"kind": "Issuer", "name": f"{CORE}-internal-ca-issuer"}}},
        {"apiVersion": "cert-manager.io/v1", "kind": "ClusterIssuer",
         "metadata": meta(f"{CORE}-internal-issuer", None, labels={"mas.ibm.com/instanceId": INST},
                          annotations=dict(primary)),
         "spec": {"ca": {"secretName": f"{INST}-cert-internal-ca"}}},
        secret(f"{INST}-cert-internal-ca", CERT,
               annotations={"cert-manager.io/certificate-name": f"{INST}-cert-internal-ca"}),
        # leaf cert secret issued by cert-manager
        secret(f"{INST}-workspaceagent-tls", MANAGE,
               annotations={"cert-manager.io/certificate-name": f"{INST}-workspaceagent"}),
        # platform noise that discovery must ignore
        configmap("kube-root-ca.crt", MANAGE),
        {"apiVersion": "v1", "kind": "Secret", "type": "kubernetes.io/service-account-token",
         "metadata": meta("default-token-abc", MANAGE, annotations={"kubernetes.io/service-account.name": "default"}),
         "data": {"token": SENTINEL_B64}},
        # OLM
        {"apiVersion": "operators.coreos.com/v1alpha1", "kind": "Subscription",
         "metadata": meta("ibm-mas", CORE, annotations=dict(track)),
         "spec": {"source": "ibm-operator-catalog", "sourceNamespace": "openshift-marketplace"}},
        {"apiVersion": "operators.coreos.com/v1alpha1", "kind": "CatalogSource",
         "metadata": meta("ibm-operator-catalog", "openshift-marketplace", annotations=dict(track)), "spec": {}},
        {"apiVersion": "apiextensions.k8s.io/v1", "kind": "CustomResourceDefinition",
         "metadata": meta("suites.core.mas.ibm.com"),
         "spec": {"group": "core.mas.ibm.com", "scope": "Namespaced", "names": {"plural": "suites", "kind": "Suite"}}},
        {"apiVersion": "apiextensions.k8s.io/v1", "kind": "CustomResourceDefinition",
         "metadata": meta("manageworkspaces.apps.mas.ibm.com"),
         "spec": {"group": "apps.mas.ibm.com", "scope": "Namespaced",
                  "names": {"plural": "manageworkspaces", "kind": "ManageWorkspace"}}},
        {"apiVersion": "apiextensions.k8s.io/v1", "kind": "CustomResourceDefinition",
         "metadata": meta("widgets.example.com"),
         "spec": {"group": "example.com", "scope": "Namespaced", "names": {"plural": "widgets", "kind": "Widget"}}},
    ]


class FakeCluster:
    def __init__(self, objects=None, server="https://source.example:6443", context="source-ctx"):
        self.objects = copy.deepcopy(objects if objects is not None else default_objects())
        self.server, self.context = server, context

    @staticmethod
    def _match_kind(resource, obj):
        first = resource.split(".")[0].lower()
        kind = obj["kind"].lower()
        group = resource.split(".", 1)[1] if "." in resource else ""
        api_group = obj.get("apiVersion", "").split("/")[0] if "/" in obj.get("apiVersion", "") else ""
        if first not in (kind, kind + "s"):
            return False
        if not group:
            return True
        if obj["kind"] == "CustomResourceDefinition":
            return group.startswith("apiextensions")
        return group == api_group

    def get(self, args):
        """args: tokens after `get` (resource [name] [-n ns] [-l sel] [-o ...])."""
        toks, flags, i = [], {}, 0
        while i < len(args):
            t = args[i]
            if t in ("-n", "-l", "-o"):
                flags[t] = args[i + 1]
                i += 2
            elif t.startswith("-"):
                i += 1
            else:
                toks.append(t)
                i += 1
        resource, name = toks[0], (toks[1] if len(toks) > 1 else None)
        found = [copy.deepcopy(o) for o in self.objects if self._match_kind(resource, o)]
        ns = flags.get("-n")
        if ns:
            found = [o for o in found if o["metadata"].get("namespace") == ns]
        sel = flags.get("-l")
        if sel:
            k, _, v = sel.partition("=")
            found = [o for o in found if o["metadata"].get("labels", {}).get(k) == v]
        if name:
            found = [o for o in found if o["metadata"]["name"] == name]
            return found[0] if found else None
        return {"items": found}


def main():  # executable fake `oc` (read-only; refuses everything else)
    import os
    argv = sys.argv[1:]
    with open(os.environ["FAKE_OC_FIXTURE"]) as fh:
        spec = json.load(fh)
    cluster = FakeCluster(spec.get("objects"), spec.get("server", "https://source.example:6443"),
                          spec.get("context", "source-ctx"))
    if argv[:1] == ["whoami"]:
        print(cluster.server if "--show-server" in argv else "tester")
        return 0
    if argv[:2] == ["config", "current-context"]:
        print(cluster.context)
        return 0
    if argv[:1] == ["get"]:
        doc = cluster.get(argv[1:])
        if doc is None:
            print('Error from server (NotFound): resource "x" not found', file=sys.stderr)
            return 1
        print(json.dumps(doc))
        return 0
    print("fake oc: unsupported (refusing mutating command): " + " ".join(argv), file=sys.stderr)
    return 97


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env bash
# MASCORE-20742 Suite/Manage disaster-recovery POC backup (read-only against the cluster).
#
# Stages:
#   1. Baseline allowlist (parameterised by INSTANCE / WORKSPACE_ID; no duplicates).
#   2. Optional discovery (--discover): generic enumeration of MAS CRs, ConfigMaps, Secrets,
#      cert-manager and OLM resources in the instance namespaces, classified by ownership.
#   3. Referenced-resource closure: Secrets/ConfigMaps/Issuers referenced by stored CRs.
#   4. CA key-pair Secrets referenced by Issuers/ClusterIssuers (policy-gated, see README).
#   5. MANIFEST.json + SHA256SUMS with validation results.
#
# Every object is classified (dr_lib.py).  Only objects whose recovery method is "backup" are
# stored as restorable; GitOps/operator-regenerated objects are stored for reference (specs) or
# recorded as "expected to be recreated" without copying Secret content.
#
# Secrets are never written in plaintext unless --allow-plaintext-local is given.  For anything
# leaving this host, set DR_ENCRYPT_CMD to the team-approved encrypt command (stdin -> stdout).
# No encryption standard could be established from the six repositories; none is bundled and no
# key material is ever written next to the backup.
set -euo pipefail
umask 077

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HERE/dr_lib.py"

INSTANCE="${INSTANCE:-inst03}"
WORKSPACE_ID="${WORKSPACE_ID:-main}"
CORE_NS="${CORE_NS:-mas-${INSTANCE}-core}"
MANAGE_NS="${MANAGE_NS:-mas-${INSTANCE}-manage}"
SYNCRES_NS="${SYNCRES_NS:-mas-${INSTANCE}-syncres}"
CERT_NS="${CERT_NS:-cert-manager}"
OUT=""
DISCOVER=0
INCLUDE_CA=0
STORE_REF_SECRETS=0
ALLOW_PLAINTEXT=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options] [OUT_DIR]
  --discover                 run generic discovery in addition to the baseline allowlist
  --include-ca-keys          also export CA key-pair Secrets (REQUIRES DR_ENCRYPT_CMD)
  --store-reference-secrets  break-glass: also copy GitOps/operator-regenerated Secrets
  --allow-plaintext-local    permit plaintext Secret files (local, mode 600; never share)
  -h, --help
Environment: INSTANCE WORKSPACE_ID CORE_NS MANAGE_NS SYNCRES_NS CERT_NS DR_ENCRYPT_CMD
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --discover) DISCOVER=1 ;;
    --include-ca-keys) INCLUDE_CA=1 ;;
    --store-reference-secrets) STORE_REF_SECRETS=1 ;;
    --allow-plaintext-local) ALLOW_PLAINTEXT=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "ERROR: unknown option $1" >&2; usage >&2; exit 1 ;;
    *) OUT="$1" ;;
  esac
  shift
done
OUT="${OUT:-poc/suite-resource-dr/backups/${INSTANCE}-$(date +%Y%m%d-%H%M%S)}"

command -v oc >/dev/null || { echo "ERROR: oc CLI is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "ERROR: Python 3 is required" >&2; exit 1; }
python3 -c 'import yaml' >/dev/null 2>&1 || {
  echo "ERROR: Python PyYAML is required (python3 -m pip install pyyaml)." >&2
  exit 1
}
oc whoami >/dev/null || { echo "ERROR: not logged in to a cluster" >&2; exit 1; }
if [[ -z "${DR_ENCRYPT_CMD:-}" && $ALLOW_PLAINTEXT -eq 0 ]]; then
  echo "ERROR: no encryption configured. Set DR_ENCRYPT_CMD to the approved encrypt command" >&2
  echo "       (stdin->stdout), or pass --allow-plaintext-local for a local-only POC copy." >&2
  exit 1
fi
if [[ $INCLUDE_CA -eq 1 && -z "${DR_ENCRYPT_CMD:-}" ]]; then
  echo "ERROR: --include-ca-keys requires DR_ENCRYPT_CMD (CA private keys are never stored in plaintext)." >&2
  exit 1
fi

SOURCE_SERVER="$(oc whoami --show-server 2>/dev/null || true)"
SOURCE_CONTEXT="$(oc config current-context 2>/dev/null || true)"
if [[ -z "$SOURCE_SERVER" ]]; then
  echo "WARNING: could not determine source server URL (oc whoami --show-server failed)." >&2
  echo "         The restore tool's source-cluster safety check will be DEGRADED for this backup." >&2
fi
if [[ -z "$SOURCE_CONTEXT" ]]; then
  echo "WARNING: could not determine source kubeconfig context (oc config current-context failed)." >&2
  echo "         The restore tool's source-context safety check will be DEGRADED for this backup." >&2
fi

init_args=(init --out "$OUT" --instance "$INSTANCE" --workspace-id "$WORKSPACE_ID"
  --core-ns "$CORE_NS" --manage-ns "$MANAGE_NS" --syncres-ns "$SYNCRES_NS" --cert-ns "$CERT_NS"
  --source-server "$SOURCE_SERVER"
  --source-context "$SOURCE_CONTEXT")
[[ $ALLOW_PLAINTEXT -eq 1 ]] && init_args+=(--allow-plaintext-local)
[[ $INCLUDE_CA -eq 1 ]] && init_args+=(--include-ca-keys)
[[ $STORE_REF_SECRETS -eq 1 ]] && init_args+=(--store-reference-secrets)
python3 "$LIB" "${init_args[@]}"

REQUIRED_MISSING=0
FAILED=0

# fetch_store KIND RESOURCE NAME NAMESPACE REQUIRED SOURCE
fetch_store() {
  local kind="$1" resource="$2" name="$3" ns="$4" required="${5:-optional}" source="${6:-allowlist}"
  local args=(get "$resource" "$name" -o json --show-managed-fields) err json
  [[ -n "$ns" ]] && args+=(-n "$ns")
  err="$(mktemp)"
  if json="$(oc "${args[@]}" 2>"$err")"; then
    printf '%s' "$json" | python3 "$LIB" store --out "$OUT" --required "$required" --source "$source" || {
      FAILED=$((FAILED + 1))
      echo "ERROR: could not store $kind/$name" >&2
      python3 "$LIB" record-skip --out "$OUT" --kind "$kind" --name "$name" --namespace "$ns" \
        --required "$required" --status "failed" \
        --reason "store command failed (encrypt error or other Python exception)" \
        --source "$source"
      if [[ "$required" == "required" ]]; then
        REQUIRED_MISSING=$((REQUIRED_MISSING + 1))
      fi
    }
  else
    local status="not_found" reason
    reason="$(head -c 300 "$err" | tr '\n' ' ')"
    if ! grep -qi "notfound\|not found" "$err"; then status="failed"; FAILED=$((FAILED + 1)); fi
    python3 "$LIB" record-skip --out "$OUT" --kind "$kind" --name "$name" --namespace "$ns" \
      --required "$required" --status "$status" --reason "$reason" --source "$source"
    if [[ "$required" == "required" ]]; then
      REQUIRED_MISSING=$((REQUIRED_MISSING + 1))
      echo "ERROR: required resource $kind/$name ${ns:+in $ns}: $status" >&2
    else
      echo "SKIP ($status) $kind/$name ${ns:+in $ns}"
    fi
  fi
  rm -f "$err"
}

fetch_list() { # stdin lines: Kind|resource|name|namespace|required
  local kind resource name ns req
  while IFS='|' read -r kind resource name ns req; do
    [[ -z "$kind" ]] && continue
    fetch_store "$kind" "$resource" "$name" "$ns" "${req:-optional}" "${1:-allowlist}"
  done
}

# Stage 1: baseline allowlist (each name appears once; checked by tests/test_dr.py).
fetch_list baseline <<LIST
Suite|suites.core.mas.ibm.com|${INSTANCE}|${CORE_NS}|required
ManageWorkspace|manageworkspaces.apps.mas.ibm.com|${INSTANCE}-${WORKSPACE_ID}|${MANAGE_NS}|required
Certificate|certificates.cert-manager.io|${INSTANCE}-cert-internal-ca|${CERT_NS}|optional
Certificate|certificates.cert-manager.io|${INSTANCE}-cert-public-ca|${CERT_NS}|optional
Issuer|issuers.cert-manager.io|${CORE_NS}-internal-ca-issuer|${CERT_NS}|optional
Issuer|issuers.cert-manager.io|${CORE_NS}-public-ca-issuer|${CERT_NS}|optional
ClusterIssuer|clusterissuers.cert-manager.io|${CORE_NS}-internal-issuer||optional
ClusterIssuer|clusterissuers.cert-manager.io|${CORE_NS}-public-issuer||optional
ConfigMap|configmaps|${INSTANCE}-catalog-items|${CORE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-catalog-settings|${CORE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-nps|${CORE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-settings-applications|${CORE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-suite-reconcile|${CORE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-supported-applications|${CORE_NS}|optional
Secret|secrets|${INSTANCE}-keys-jwt|${CORE_NS}|optional
Secret|secrets|${INSTANCE}-admindashboard-cert-internal|${CORE_NS}|optional
Secret|secrets|${INSTANCE}-credentials-superuser|${CORE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-coreidp-binding-reconcile|${MANAGE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-${WORKSPACE_ID}-aicfg-binding-reconcile|${MANAGE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-${WORKSPACE_ID}-instance-monitor-cfg|${MANAGE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-${WORKSPACE_ID}-jdbccfg-binding-reconcile|${MANAGE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-${WORKSPACE_ID}-optimizerworkspace-binding-reconcile|${MANAGE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-${WORKSPACE_ID}-server-monitor-cfg|${MANAGE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-${WORKSPACE_ID}-smtpcfg-binding-reconcile|${MANAGE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-${WORKSPACE_ID}-supported-pod-keys|${MANAGE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-${WORKSPACE_ID}-truststore-cfg|${MANAGE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-${WORKSPACE_ID}-truststore-tsmcfg|${MANAGE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-manage-install-placeholder|${MANAGE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-manage-${WORKSPACE_ID}-config-placeholder|${MANAGE_NS}|optional
ConfigMap|configmaps|${INSTANCE}-suite-binding-reconcile|${MANAGE_NS}|optional
ConfigMap|configmaps|maximo-config|${MANAGE_NS}|optional
ConfigMap|configmaps|pre-jreporter-app-install-manage-${INSTANCE}-synctime|${MANAGE_NS}|optional
Secret|secrets|${WORKSPACE_ID}-manage-encryption-secret|${MANAGE_NS}|required
Secret|secrets|${WORKSPACE_ID}-manage-encryption-secret-operator|${MANAGE_NS}|required
Secret|secrets|${WORKSPACE_ID}-manage-d--sb0--asc--sn|${MANAGE_NS}|optional
Secret|secrets|${WORKSPACE_ID}-manage-d--sb1--asc--sn|${MANAGE_NS}|optional
Secret|secrets|cos-logging|${MANAGE_NS}|optional
Secret|secrets|${INSTANCE}-coreidp-system-binding|${MANAGE_NS}|optional
Secret|secrets|${INSTANCE}-credentials-oauth-manage|${MANAGE_NS}|optional
Secret|secrets|${INSTANCE}-internal-manage-tls|${MANAGE_NS}|optional
Secret|secrets|${INSTANCE}-internal-mobile-encryption|${MANAGE_NS}|optional
Secret|secrets|${INSTANCE}-keys-ltpa|${MANAGE_NS}|optional
Secret|secrets|${INSTANCE}-${WORKSPACE_ID}-cert-public-81|${MANAGE_NS}|optional
Secret|secrets|${INSTANCE}-${WORKSPACE_ID}-internal-maximoproperty-secret|${MANAGE_NS}|optional
Secret|secrets|${INSTANCE}-${WORKSPACE_ID}-jdbccfg-workspace-application-binding|${MANAGE_NS}|optional
Secret|secrets|${INSTANCE}-${WORKSPACE_ID}-manage-truststorepasswd|${MANAGE_NS}|optional
Secret|secrets|${INSTANCE}-${WORKSPACE_ID}-truststore|${MANAGE_NS}|optional
Secret|secrets|${INSTANCE}-suite-system-binding|${MANAGE_NS}|optional
Secret|secrets|${INSTANCE}-workspaceagent-tls|${MANAGE_NS}|optional
Secret|secrets|${WORKSPACE_ID}-default-bundleproperty|${MANAGE_NS}|optional
Secret|secrets|${WORKSPACE_ID}-default-nonsystemproperty|${MANAGE_NS}|optional
Secret|secrets|${WORKSPACE_ID}-foundation-bundleproperty|${MANAGE_NS}|optional
Secret|secrets|${WORKSPACE_ID}-foundation-nonsystemproperty|${MANAGE_NS}|optional
Secret|secrets|${WORKSPACE_ID}-jmsserver-bundleproperty|${MANAGE_NS}|optional
Secret|secrets|${WORKSPACE_ID}-smtp-oauth-properties|${MANAGE_NS}|optional
LIST

# Stage 2: generic discovery (instance-scoped, read-only).
if [[ $DISCOVER -eq 1 ]]; then
  echo "Running discovery..."
  python3 "$HERE/discover.py" --instance "$INSTANCE" --workspace-id "$WORKSPACE_ID" \
    --core-ns "$CORE_NS" --manage-ns "$MANAGE_NS" --syncres-ns "$SYNCRES_NS" --cert-ns "$CERT_NS" \
    --output "$OUT/inventory.json" > "$OUT/inventory.txt"
  chmod 600 "$OUT/inventory.txt"
  python3 "$LIB" targets --out "$OUT" --inventory "$OUT/inventory.json" | fetch_list discovery
fi

# Stage 3: referenced Secrets/ConfigMaps/Issuers of stored CRs (closure, bounded).
for _ in 1 2 3 4; do
  pending="$(python3 "$LIB" pending-refs --out "$OUT")"
  [[ -z "$pending" ]] && break
  printf '%s\n' "$pending" | fetch_list referenced
done

# Stage 4: CA key-pair Secrets referenced by Issuers/ClusterIssuers (policy-gated).
python3 "$LIB" ca-secrets --out "$OUT" | fetch_list ca-keypair

# Stage 5: manifest + validation.
rc=0
python3 "$LIB" manifest --out "$OUT" || rc=$?

cat > "$OUT/README.txt" <<NOTES
MASCORE-20742 Suite/Manage DR POC backup  (see MANIFEST.json for the authoritative inventory)
Instance: ${INSTANCE}   Workspace: ${WORKSPACE_ID}
Namespaces: ${CORE_NS}, ${MANAGE_NS}, ${SYNCRES_NS}, ${CERT_NS}
Discovery run: $([[ $DISCOVER -eq 1 ]] && echo yes || echo "no (baseline allowlist + referenced closure only)")
Encrypted: $([[ -n "${DR_ENCRYPT_CMD:-}" ]] && echo "yes (external DR_ENCRYPT_CMD)" || echo "NO - plaintext local copy, mode 600/700. Never share or commit.")

This is NOT a complete cluster backup.  Objects with recovery action gitops_resync,
install_operator, recreate_operator or recreate_cert_manager are recreated by their owners
(see "not_backed_up" and per-entry "recovery_action" in MANIFEST.json).  CRDs, CSVs,
Subscriptions and CatalogSources are never restored from this backup.
Restore with:  restore.py plan|apply --backup <this dir>   (default is plan-only)
No end-to-end restore has been verified; see POC-RESULTS.md.
NOTES
chmod 600 "$OUT/README.txt"

echo
echo "Backup directory: $OUT"
echo "Files: $(find "$OUT" -type f | wc -l | tr -d ' ')   required-missing: $REQUIRED_MISSING   fetch/store failures: $FAILED"
[[ -z "${DR_ENCRYPT_CMD:-}" ]] && echo "WARNING: backup is NOT encrypted. Do not stage, commit or share this directory."
if [[ $rc -ne 0 || $REQUIRED_MISSING -gt 0 || $FAILED -gt 0 ]]; then
  echo "RESULT: FAILED validation - see messages above" >&2
  exit 2
fi
echo "RESULT: OK"

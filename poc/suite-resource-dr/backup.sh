#!/usr/bin/env bash
set -euo pipefail
umask 077

INSTANCE="${INSTANCE:-inst03}"
CORE_NS="${CORE_NS:-mas-${INSTANCE}-core}"
SYNCRES_NS="${SYNCRES_NS:-mas-${INSTANCE}-syncres}"
OUT="${1:-poc/suite-resource-dr/backups/${INSTANCE}-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$OUT/core" "$OUT/syncres"
chmod 700 "$OUT" "$OUT/core" "$OUT/syncres"

command -v oc >/dev/null || { echo "ERROR: oc CLI is required" >&2; exit 1; }
oc whoami >/dev/null || { echo "ERROR: not logged in to a cluster" >&2; exit 1; }

backup_resource() {
  local namespace="$1" resource="$2" name="$3" dest="$4"
  echo "Backing up ${resource}/${name} from ${namespace}..."
  oc get "$resource" "$name" -n "$namespace" -o yaml |
    python3 -c 'import sys, yaml
obj = yaml.safe_load(sys.stdin)
meta = obj.get("metadata", {})
for key in ("resourceVersion", "uid", "creationTimestamp", "generation", "managedFields", "selfLink"):
    meta.pop(key, None)
annotations = meta.get("annotations", {})
annotations.pop("kubectl.kubernetes.io/last-applied-configuration", None)
if not annotations:
    meta.pop("annotations", None)
obj.pop("status", None)
yaml.safe_dump(obj, sys.stdout, sort_keys=False)' > "$dest"
  chmod 600 "$dest"
}


python3 -c 'import yaml' || {
  echo "ERROR: Python PyYAML is required." >&2
  exit 1
}

# Explicit POC allowlist: Suite custom resource and named Suite-owned ConfigMaps.
backup_resource "$CORE_NS" suites.core.mas.ibm.com "$INSTANCE" \
  "$OUT/core/suite-${INSTANCE}.yaml"

for name in \
  "${INSTANCE}-catalog-items" \
  "${INSTANCE}-catalog-settings" \
  "${INSTANCE}-nps" \
  "${INSTANCE}-settings-applications" \
  "${INSTANCE}-suite-reconcile" \
  "${INSTANCE}-supported-applications"
do
  backup_resource "$CORE_NS" configmaps "$name" "$OUT/core/configmap-${name}.yaml"
done

# Manifest records scope and the deliberately limited allowlist.
cat > "$OUT/README.txt" <<NOTES
Suite resource DR POC
Instance: ${INSTANCE}
Core namespace: ${CORE_NS}
Supporting namespace: ${SYNCRES_NS}

Included:
- Suite.core.mas.ibm.com/${INSTANCE}
- ConfigMaps: ${INSTANCE}-catalog-items
- ConfigMaps: ${INSTANCE}-catalog-settings
- ConfigMaps: ${INSTANCE}-nps
- ConfigMaps: ${INSTANCE}-settings-applications
- ConfigMaps: ${INSTANCE}-suite-reconcile
- ConfigMaps: ${INSTANCE}-supported-applications

Not included yet:
- Secrets
- cert-manager resources and certificate private keys
- CRDs, OperatorGroups, Subscriptions, CSVs
- Operator-generated resources and database contents

Restore prerequisites:
- Recreate the namespace and install compatible operators/CRDs first.
- Review the manifest and adapt instance-specific values before restoring.
- Do not restore directly over a live instance without an approved recovery plan.

WARNING: This is a limited POC, not a complete disaster-recovery backup.
NOTES
chmod 600 "$OUT/README.txt"

echo "Backup completed: $OUT"
echo "Review files before using them for any restore."

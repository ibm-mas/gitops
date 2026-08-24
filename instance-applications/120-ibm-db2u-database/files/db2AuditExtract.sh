#!/bin/bash

# ----------------------------------------------------------------------------
#% Script Name  : db2AuditExtract.sh
#% Description  : Archive and extract DB2 audit logs as DEL/ASC files, upload
#%                each *.del file to S3, then remove source files.
#%
#%  **  THIS MUST BE RUN AS THE DB2 INSTANCE OWNER (db2inst1)  **
#%
#%  USAGE:  db2AuditExtract.sh <application_name> [dbname] [--use-irsa]
#%
#%  Options:
#%    --use-irsa    Use IAM Role for Service Account (IRSA) instead of credentials
#%
#%  Steps:
#%   1.  mkdir /tmp/auditarchive
#%   2.  rm /tmp/auditarchive/*.del
#%   3.  db2audit flush
#%   4.  db2audit archive database BLUDB to /tmp/auditarchive
#%   5.  db2audit archive to /tmp/auditarchive  (instance log)
#%   6.  db2audit extract delasc to /tmp/auditarchive  (database log)
#%   7.  db2audit extract delasc to /tmp/auditarchive  (instance log)
#%   8.  Copy db2audit.db.BLUDB.log.0.20*   from /mnt/blumeta0/audit → /tmp/auditarchive
#%   9.  Copy db2audit.instance.log.0.20*   from /mnt/blumeta0/audit → /tmp/auditarchive
#%  10.  Upload ALL files from /tmp/auditarchive to S3
#%  11.  rm -rf /tmp/auditarchive
#%  12.  Delete the *.log.0.20* source files from /mnt/blumeta0/audit
#%  13.  (Conditional) Delete pre-existing *.del files from /mnt/blumeta0/audit
#%       (prints list before deleting)
# ----------------------------------------------------------------------------

set -eo pipefail

# ── Logging helper ─────────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ── Parse arguments ────────────────────────────────────────────────────────
APP_NAME="${1:-}"
USE_IRSA=false

if [ -z "${APP_NAME}" ]; then
  echo "ERROR :: Usage: $0 <application_name> [dbname] [--use-irsa]"
  exit 1
fi

# Check for --use-irsa flag in any position
for arg in "$@"; do
  if [ "$arg" = "--use-irsa" ]; then
    USE_IRSA=true
  fi
done

# ── Constants ──────────────────────────────────────────────────────────────
ARCHIVE_DIR="/tmp/auditarchive"
AUDIT_BASE="/mnt/blumeta0/audit"
DBNAME="${2:-BLUDB}"  # Passed as 2nd arg from CronJob; falls back to BLUDB
DATE=$(date +"%Y-%m-%d")
DT=$(date +"%Y-%m-%d_%H%M%S")
DELETE_AUDIT_BASE_DEL="false"   # Set to "true" to delete *.del files from ${AUDIT_BASE} (step 13)

# ── Source DB2 environment (DB2 profile uses unbound vars — disable nounset) ─
set +u
. "${HOME}/sqllib/db2profile"
set -u

# ── Load COS/S3 credentials (CONTAINER, SERVER, PARM1, PARM2) ─────────────
. /mnt/backup/bin/.PROPS

# ── Install AWS CLI if not already present ────────────────────────────────
AWS_CLI="/mnt/backup/aws/dist/aws"
log "INFO  :: Checking AWS CLI at ${AWS_CLI}"
if ! "${AWS_CLI}" --version >/dev/null 2>&1; then
  log "INFO  ::   Not found — installing AWS CLI to /mnt/backup/"
  cd /mnt/backup
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip -d /mnt/backup/
  log "INFO  ::   AWS CLI installed at ${AWS_CLI}"
else
  log "INFO  ::   AWS CLI already present: $(${AWS_CLI} --version 2>&1)"
fi

# ── Configure AWS authentication ───────────────────────────────────────────
if [ "${USE_IRSA}" = true ]; then
  log "INFO  :: Using IRSA (IAM Role for Service Account) for AWS authentication"
  # IRSA: AWS SDK/CLI automatically uses the pod's service account token
  # mounted at /var/run/secrets/eks.amazonaws.com/serviceaccount/token
  # No need to set AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY
  export AWS_DEFAULT_REGION=$(echo "${SERVER}" | sed 's|.*s3\.\([^.]*\)\.amazonaws.*|\1|')
else
  log "INFO  :: Using IAM User credentials for AWS authentication (legacy mode)"
  export AWS_ACCESS_KEY_ID="${PARM1}"
  export AWS_SECRET_ACCESS_KEY="${PARM2}"
  export AWS_DEFAULT_REGION=$(echo "${SERVER}" | sed 's|.*s3\.\([^.]*\)\.amazonaws.*|\1|')
fi

S3_TARGET="s3://${CONTAINER}/audit_logs/${APP_NAME}/${DATE}/"

# ── Ensure db2audit is always restarted on exit ────────────────────────────
trap 'log "INFO  :: Restarting db2audit after job"; db2audit start >/dev/null 2>&1 || true' EXIT

# ── Banner ─────────────────────────────────────────────────────────────────
log "INFO  :: ============================================================"
log "INFO  :: DB2 Audit Extract — ${DT}"
log "INFO  :: Application : ${APP_NAME} | Database : ${DBNAME}"
log "INFO  :: Work dir    : ${ARCHIVE_DIR}"
log "INFO  :: S3 target   : ${S3_TARGET}"
log "INFO  :: ============================================================"

# ============================================================================
# 1–2.  Prepare working directory
# ============================================================================
log "INFO  :: [1] mkdir ${ARCHIVE_DIR}"
mkdir -p "${ARCHIVE_DIR}"

log "INFO  :: [2] Removing any stale .del files from ${ARCHIVE_DIR}"
rm -f "${ARCHIVE_DIR}"/*.del 2>/dev/null || true

# ============================================================================
# 3.  Flush in-memory audit buffer to disk
# ============================================================================
log "INFO  :: [3] db2audit flush"
db2audit flush

# ============================================================================
# 4.  Archive the database audit log to /tmp/auditarchive
# ============================================================================
log "INFO  :: [4] db2audit archive database ${DBNAME} to ${ARCHIVE_DIR}"
db2audit archive database "${DBNAME}" to "${ARCHIVE_DIR}"

# ============================================================================
# 5.  Archive the instance audit log to /tmp/auditarchive
# ============================================================================
log "INFO  :: [5] db2audit archive to ${ARCHIVE_DIR}  (instance log)"
db2audit archive to "${ARCHIVE_DIR}"

# ============================================================================
# 6.  Extract archived database log → *.del
# ============================================================================
log "INFO  :: [6] db2audit extract delasc (database log)"
DB_LOGS=$(ls "${ARCHIVE_DIR}"/db2audit.db."${DBNAME}".log.0.* 2>/dev/null || true)
if [ -z "${DB_LOGS}" ]; then
  log "WARN  ::     No database archive log found in ${ARCHIVE_DIR} — skipping extract"
else
  db2audit extract delasc to "${ARCHIVE_DIR}" from files ${DB_LOGS}
fi

# ============================================================================
# 7.  Extract archived instance log → *.del
# ============================================================================
log "INFO  :: [7] db2audit extract delasc (instance log)"
INST_LOGS=$(ls "${ARCHIVE_DIR}"/db2audit.instance.log.0.* 2>/dev/null || true)
if [ -z "${INST_LOGS}" ]; then
  log "WARN  ::     No instance archive log found in ${ARCHIVE_DIR} — skipping extract"
else
  db2audit extract delasc to "${ARCHIVE_DIR}" from files ${INST_LOGS}
fi

# ============================================================================
# 8–9.  Copy historical log files from /mnt/blumeta0/audit to /tmp/auditarchive
# ============================================================================
log "INFO  :: [8] Copying db2audit.db.${DBNAME}.log.0.20* from ${AUDIT_BASE}"
cp "${AUDIT_BASE}"/db2audit.db."${DBNAME}".log.0.20* "${ARCHIVE_DIR}/" 2>/dev/null \
  && log "INFO  ::     Database logs copied" \
  || log "WARN  ::     No matching db2audit.db.${DBNAME}.log.0.20* files found — skipping"

log "INFO  :: [9] Copying db2audit.instance.log.0.20* from ${AUDIT_BASE}"
cp "${AUDIT_BASE}"/db2audit.instance.log.0.20* "${ARCHIVE_DIR}/" 2>/dev/null \
  && log "INFO  ::     Instance logs copied" \
  || log "WARN  ::     No matching db2audit.instance.log.0.20* files found — skipping"

# ============================================================================
# 10.  Upload ALL files from /tmp/auditarchive to S3
# ============================================================================
log "INFO  :: [10] Uploading all files from ${ARCHIVE_DIR} to ${S3_TARGET}"

ALL_FILES=$(ls "${ARCHIVE_DIR}"/* 2>/dev/null || true)
if [ -z "${ALL_FILES}" ]; then
  log "WARN  ::      No files found in ${ARCHIVE_DIR} — nothing to upload"
else
  ERRORS=0
  for F in ${ALL_FILES}; do
    FILE_NAME=$(basename "${F}")
    log "INFO  ::      [s3] ${FILE_NAME} → ${S3_TARGET}${FILE_NAME}"
    "${AWS_CLI}" s3 cp "${F}" "${S3_TARGET}${FILE_NAME}" \
      && log "INFO  ::           Upload confirmed" \
      || { log "ERROR ::           Upload FAILED for ${FILE_NAME}"; ERRORS=$((ERRORS + 1)); }
  done
  [ ${ERRORS} -gt 0 ] && { log "ERROR :: ${ERRORS} upload(s) failed"; exit 1; }
  log "INFO  ::      All files uploaded successfully"
fi

# ============================================================================
# 11.  Remove /tmp/auditarchive and all its contents
# ============================================================================
log "INFO  :: [11] rm -rf ${ARCHIVE_DIR}"
rm -rf "${ARCHIVE_DIR}"
log "INFO  ::      Working directory removed"

# ============================================================================
# 12.  Delete the historical *.log.0.20* source files from /mnt/blumeta0/audit
# ============================================================================
log "INFO  :: [12] Removing historical log files from ${AUDIT_BASE}"

for PATTERN in \
  "${AUDIT_BASE}/db2audit.db.${DBNAME}.log.0.20"* \
  "${AUDIT_BASE}/db2audit.instance.log.0.20"*
do
  for F in ${PATTERN}; do
    [ -f "${F}" ] || continue
    log "INFO  ::      [delete] $(basename "${F}")"
    rm -f "${F}"
  done
done
log "INFO  ::      Historical log files removed"

# ============================================================================
# 13.  (Optional) Delete pre-existing *.del files from /mnt/blumeta0/audit
#       — controlled by DELETE_AUDIT_BASE_DEL; prints list before deleting
# ============================================================================
log "INFO  :: [13] DELETE_AUDIT_BASE_DEL=${DELETE_AUDIT_BASE_DEL}"

if [ "${DELETE_AUDIT_BASE_DEL}" != "true" ]; then
  log "INFO  ::      Skipping .del cleanup in ${AUDIT_BASE} (DELETE_AUDIT_BASE_DEL is not true)"
else
  AUDIT_DEL_FILES=$(ls "${AUDIT_BASE}"/*.del 2>/dev/null || true)
  if [ -z "${AUDIT_DEL_FILES}" ]; then
    log "INFO  ::      No .del files found in ${AUDIT_BASE} — nothing to clean"
  else
    log "INFO  ::      The following .del files will be deleted from ${AUDIT_BASE}:"
    for F in ${AUDIT_DEL_FILES}; do
      log "INFO  ::        $(basename "${F}")"
    done
    rm -f ${AUDIT_DEL_FILES}
    log "INFO  ::      .del files deleted"
  fi
fi

# ── Done ───────────────────────────────────────────────────────────────────
log "INFO  :: ============================================================"
log "INFO  :: Audit extraction completed successfully"
log "INFO  :: S3 target : ${S3_TARGET}"
log "INFO  :: ============================================================"
exit 0
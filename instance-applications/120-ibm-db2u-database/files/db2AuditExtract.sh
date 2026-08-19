#!/bin/bash

# ----------------------------------------------------------------------------
#% Script Name  : db2AuditExtract.sh
#% Description  : Archive and extract DB2 audit logs as DEL/ASC (delasc) files,
#%                zip them, upload the zip to S3, then remove ALL local copies
#%                to keep the /mnt/blumeta0/audit filesystem free.
#% Created On   : 2026
#%
#%  **************  THIS NEEDS TO BE RUN AS INSTANCE OWNER (db2inst1).  ******
#%  USAGE:
#%          db2AuditExtract.sh <application_name>
#%
#%  Working directory : /mnt/blumeta0/audit/auditarchive  (persistent volume)
#%  S3 target         : s3://<bucket>/audit_logs/<app>/<YYYYMMDD>/<timestamp>.zip
#%
#%  Steps:
#%   1.  Prepare /mnt/blumeta0/audit/auditarchive (clear old *.del files)
#%   2.  db2audit flush
#%   3.  db2audit archive database BLUDB to auditarchive
#%   4.  db2audit archive (instance) to auditarchive
#%   5.  db2audit extract delasc ... from files db2audit.db.BLUDB.log.0.*
#%   6.  db2audit extract delasc ... from files db2audit.instance.log.0.*
#%   7.  zip all *.del into <app>_<timestamp>.zip
#%   8.  Upload zip to S3 via AWS CLI (s3 cp)
#%   9.  Delete zip from source ONLY after S3 upload confirmed
#%  10.  Clean up auditarchive directory (rm -rf)
#%  11.  Delete previous day folders from /mnt/blumeta0/audit/ older than 1 day
# ----------------------------------------------------------------------------

set -eo pipefail

# ============================================================================
# Parameters / Inputs
# ============================================================================
APP_NAME="${1:-}"

if [ -z "${APP_NAME}" ]; then
  echo "ERROR :: Usage: $0 <application_name>"
  exit 1
fi

# Use persistent mount as working dir — db2RemStgManager requires source on
# a mounted filesystem, not /tmp (ephemeral, may be rejected as source path)
AUDIT_BASE="/mnt/blumeta0/audit"
ARCHIVE_DIR="${AUDIT_BASE}/auditarchive"
DBNAME="BLUDB"
HOSTNAME=$(hostname)
DATE=$(date +"%Y%m%d")
DT=$(date +"%Y%m%d_%H%M%S")

# ============================================================================
# Logging helper
# ============================================================================
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# ============================================================================
# Source DB2 environment — disable nounset temporarily (DB2 profile uses
# unbound variables internally)
# ============================================================================
set +u
. "${HOME}/sqllib/db2profile"
set -u

# ============================================================================
# Load COS / S3 parameters (CONTAINER, SERVER, PARM1, PARM2)
# ============================================================================
. /mnt/backup/bin/.PROPS

# ============================================================================
# Ensure audit is re-started on exit (even on failure)
# ============================================================================
cleanup_exit() {
  log "INFO  :: Ensuring db2audit is running after job completion"
  db2audit start >/dev/null 2>&1 || true
}
trap cleanup_exit EXIT

# ============================================================================
# Print runtime context
# ============================================================================
log "INFO  :: ============================================================"
log "INFO  :: DB2 Audit Extract — ${DT}"
log "INFO  :: Host          : ${HOSTNAME}"
log "INFO  :: Application   : ${APP_NAME}"
log "INFO  :: Database      : ${DBNAME}"
log "INFO  :: Work dir      : ${ARCHIVE_DIR}"
log "INFO  :: S3 bucket     : ${CONTAINER}"
log "INFO  :: S3 target     : s3://${CONTAINER}/audit_logs/${APP_NAME}/${DATE}/<timestamp>.zip"
log "INFO  :: ============================================================"

# ============================================================================
# 1. Prepare working directory on persistent volume
# ============================================================================
log "INFO  :: [1/9] Preparing archive directory ${ARCHIVE_DIR}"
mkdir -p "${ARCHIVE_DIR}"

log "INFO  ::       Removing any leftover .del files from previous run"
rm -f "${ARCHIVE_DIR}"/*.del 2>/dev/null || true

# ============================================================================
# 2. Flush active audit buffers
# ============================================================================
log "INFO  :: [2/9] Flushing db2audit buffers"
db2audit flush
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: db2audit flush failed (RC=${RC})"
  exit 1
fi
log "INFO  ::       Flush succeeded"

# ============================================================================
# 3. Archive the database audit log
# ============================================================================
log "INFO  :: [3/9] Archiving database audit log for ${DBNAME}"
db2audit archive database "${DBNAME}" to "${ARCHIVE_DIR}"
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: db2audit archive database failed (RC=${RC})"
  exit 1
fi
log "INFO  ::       Database archive succeeded"

# ============================================================================
# 4. Archive the instance audit log
# ============================================================================
log "INFO  :: [4/9] Archiving instance audit log"
db2audit archive to "${ARCHIVE_DIR}"
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: db2audit archive instance failed (RC=${RC})"
  exit 1
fi
log "INFO  ::       Instance archive succeeded"

# ============================================================================
# 5. Extract database archived log to DEL/ASC format
# ============================================================================
log "INFO  :: [5/9] Extracting database audit archive to delasc"
DB_LOG_PATTERN="${ARCHIVE_DIR}/db2audit.db.${DBNAME}.log.0.*"
DB_LOG_FILES=$(ls ${DB_LOG_PATTERN} 2>/dev/null || true)

if [ -z "${DB_LOG_FILES}" ]; then
  log "WARN  ::       No database audit archive files found — skipping"
else
  log "INFO  ::       Files: $(echo ${DB_LOG_FILES} | wc -w) archive file(s) found"
  db2audit extract delasc to "${ARCHIVE_DIR}" from files ${DB_LOG_PATTERN}
  RC=$?
  if [ $RC -ne 0 ]; then
    log "ERROR :: db2audit extract (database) failed (RC=${RC})"
    exit 1
  fi
  log "INFO  ::       Database audit extract completed"
fi

# ============================================================================
# 6. Extract instance archived log to DEL/ASC format
# ============================================================================
log "INFO  :: [6/9] Extracting instance audit archive to delasc"
INST_LOG_PATTERN="${ARCHIVE_DIR}/db2audit.instance.log.0.*"
INST_LOG_FILES=$(ls ${INST_LOG_PATTERN} 2>/dev/null || true)

if [ -z "${INST_LOG_FILES}" ]; then
  log "WARN  ::       No instance audit archive files found — skipping"
else
  log "INFO  ::       Files: $(echo ${INST_LOG_FILES} | wc -w) archive file(s) found"
  db2audit extract delasc to "${ARCHIVE_DIR}" from files ${INST_LOG_PATTERN}
  RC=$?
  if [ $RC -ne 0 ]; then
    log "ERROR :: db2audit extract (instance) failed (RC=${RC})"
    exit 1
  fi
  log "INFO  ::       Instance audit extract completed"
fi

# ============================================================================
# 7. Zip all *.del files — same approach as auditExtractUpload.sh which works
# ============================================================================
DEL_FILES=$(ls "${ARCHIVE_DIR}"/*.del 2>/dev/null || true)

if [ -z "${DEL_FILES}" ]; then
  log "WARN  :: No .del files produced — nothing to upload"
  log "INFO  :: Cleaning up ${ARCHIVE_DIR}"
  rm -rf "${ARCHIVE_DIR}"
  exit 0
fi

ZIP_NAME="${APP_NAME}_${DT}.zip"
ZIP_FILE="${ARCHIVE_DIR}/${ZIP_NAME}"

log "INFO  :: [7/9] Zipping .del files into ${ZIP_FILE}"
zip -j "${ZIP_FILE}" ${DEL_FILES} > /dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: zip failed (RC=${RC})"
  exit 1
fi
log "INFO  ::       Zip created: ${ZIP_FILE}"

# ============================================================================
# 8. Upload zip to S3 using AWS CLI
#    Installed by the postsync setup job (same method as HADR setup).
#    Credentials come from PARM1/PARM2 in .PROPS.
#    ONLY delete source after upload is confirmed.
# ============================================================================
AWS_CLI="/mnt/backup/aws/dist/aws"
S3_TARGET="s3://${CONTAINER}/audit_logs/${APP_NAME}/${DATE}/${ZIP_NAME}"

log "INFO  :: [8/9] Uploading to S3 using AWS CLI"
log "INFO  ::       Source : ${ZIP_FILE}"
log "INFO  ::       Target : ${S3_TARGET}"

if [ ! -x "${AWS_CLI}" ]; then
  log "ERROR :: AWS CLI not found at ${AWS_CLI}"
  log "ERROR :: Trigger an ArgoCD sync to run the postsync job which installs it"
  exit 1
fi

export AWS_ACCESS_KEY_ID="${PARM1}"
export AWS_SECRET_ACCESS_KEY="${PARM2}"
export AWS_DEFAULT_REGION=$(echo "${SERVER}" | sed 's|.*s3\.\([^.]*\)\.amazonaws.*|\1|')

"${AWS_CLI}" s3 cp "${ZIP_FILE}" "${S3_TARGET}"
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: S3 upload failed (RC=${RC})"
  log "ERROR :: Source file ${ZIP_FILE} has NOT been deleted — safe to retry"
  exit 1
fi
log "INFO  ::       S3 upload confirmed: ${S3_TARGET}"

# Delete zip from working dir ONLY after S3 upload is confirmed
log "INFO  ::       Deleting source zip (upload confirmed): ${ZIP_FILE}"
rm -f "${ZIP_FILE}"

# ============================================================================
# 9. Clean up auditarchive working directory
#    Removes raw archived logs and .del files — only reached after upload succeeds
# ============================================================================
log "INFO  :: [9/9] Cleaning up archive directory ${ARCHIVE_DIR}"
rm -rf "${ARCHIVE_DIR}"
log "INFO  ::       Archive directory removed"

# ============================================================================
# 10. Delete previous day folders from /mnt/blumeta0/audit/ older than 1 day
#     This keeps the 100GB filesystem free — S3 is the permanent store.
#     Only date-named folders (YYYYMMDD) are removed; other dirs are left alone.
# ============================================================================
log "INFO  :: Purging local audit folders older than 1 day from ${AUDIT_BASE}"
find "${AUDIT_BASE}" -mindepth 1 -maxdepth 1 -type d -name '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' -mtime +1 | \
  while read OLD_DIR; do
    log "INFO  ::   Removing ${OLD_DIR}"
    rm -rf "${OLD_DIR}"
  done
log "INFO  ::   Purge complete"

log "INFO  :: ============================================================"
log "INFO  :: Audit extraction completed successfully"
log "INFO  :: S3 : ${S3_TARGET}"
log "INFO  :: ============================================================"
exit 0

# -- End of Script

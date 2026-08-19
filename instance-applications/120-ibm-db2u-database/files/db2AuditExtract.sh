#!/bin/bash

# ----------------------------------------------------------------------------
#% Script Name  : db2AuditExtract.sh
#% Description  : Archive and extract DB2 audit logs as DEL/ASC (delasc) files,
#%                zip them, upload the zip to S3, then remove working files.
#% Created On   : 2026
#%
#%  **************  THIS NEEDS TO BE RUN AS INSTANCE OWNER (db2inst1).  ******
#%  USAGE:
#%          db2AuditExtract.sh <application_name>
#%
#%  Working directory : /mnt/blumeta0/audit/auditarchive  (persistent volume)
#%  Local audit dest  : /mnt/blumeta0/audit/<YYYYMMDD>/
#%  S3 target         : DB2REMOTE://AWSCOS//audit_logs/<app>_<YYYYMMDD>.zip
#%
#%  Steps:
#%   1.  Prepare /mnt/blumeta0/audit/auditarchive (clear old *.del files)
#%   2.  db2audit flush
#%   3.  db2audit archive database BLUDB to auditarchive
#%   4.  db2audit archive (instance) to auditarchive
#%   5.  db2audit extract delasc ... from files db2audit.db.BLUDB.log.0.*
#%   6.  db2audit extract delasc ... from files db2audit.instance.log.0.*
#%   7.  zip all *.del into audit_logs_<app>_<YYYYMMDD>_<timestamp>.zip
#%   8.  cp zip to /mnt/blumeta0/audit/<YYYYMMDD>/  (local persistent copy)
#%   9.  Upload zip to S3 via db2RemStgManager alias put  (same as auditExtractUpload.sh)
#%  10.  Delete zip from source ONLY after S3 upload confirmed
#%  11.  Clean up auditarchive directory
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
log "INFO  :: Local dest    : ${AUDIT_BASE}/${DATE}/"
log "INFO  :: S3 bucket     : ${CONTAINER}"
log "INFO  :: S3 target     : audit_logs/${APP_NAME}_${DATE}_<timestamp>.zip"
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
# 8. Copy zip to local persistent audit folder
# ============================================================================
DEST_DIR="${AUDIT_BASE}/${DATE}"
log "INFO  :: [8/9] Copying zip to local audit folder ${DEST_DIR}"
mkdir -p "${DEST_DIR}"
cp "${ZIP_FILE}" "${DEST_DIR}/${ZIP_NAME}"
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: Failed to copy zip to ${DEST_DIR} (RC=${RC})"
  exit 1
fi
log "INFO  ::       Local copy succeeded: ${DEST_DIR}/${ZIP_NAME}"

# ============================================================================
# 9. Upload zip to S3 — identical pattern to auditExtractUpload.sh
#    Source file is on persistent mount (/mnt/blumeta0) not /tmp
#    ONLY delete after confirmed upload
# ============================================================================
COS_TARGET="DB2REMOTE://AWSCOS//audit_logs/${APP_NAME}_${DATE}_${ZIP_NAME}"
log "INFO  :: [9/9] Uploading to S3"
log "INFO  ::       Source : ${ZIP_FILE}"
log "INFO  ::       Target : ${COS_TARGET}"

db2RemStgManager alias put \
  source="${ZIP_FILE}" \
  target="${COS_TARGET}" > /dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: S3 upload failed (RC=0x$(printf '%08X' ${RC}))"
  log "ERROR :: Source file ${ZIP_FILE} has NOT been deleted — safe to retry"
  exit 1
fi
log "INFO  ::       S3 upload confirmed: ${COS_TARGET}"

# Delete zip from working dir ONLY after S3 upload is confirmed
log "INFO  ::       Deleting source zip (S3 upload confirmed): ${ZIP_FILE}"
rm -f "${ZIP_FILE}"
log "INFO  ::       Deleted"

# ============================================================================
# Clean up — remove raw archived logs and .del files from working dir
# Reached ONLY if S3 upload succeeded
# ============================================================================
log "INFO  :: Cleaning up archive directory ${ARCHIVE_DIR}"
rm -rf "${ARCHIVE_DIR}"
log "INFO  :: Archive directory removed"

log "INFO  :: ============================================================"
log "INFO  :: Audit extraction completed successfully"
log "INFO  :: Local : ${DEST_DIR}/${ZIP_NAME}"
log "INFO  :: S3    : ${COS_TARGET}"
log "INFO  :: ============================================================"
exit 0

# -- End of Script

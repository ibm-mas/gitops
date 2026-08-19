#!/bin/bash

# ----------------------------------------------------------------------------
#% Script Name  : db2AuditExtract.sh
#% Description  : Archive and extract DB2 audit logs as DEL/ASC files, then
#%                move them to the persistent audit folder and clean up.
#% Created On   : 2026
#%
#%  **************  THIS NEEDS TO BE RUN AS INSTANCE OWNER (db2inst1).  ******
#%  USAGE:
#%          db2AuditExtract.sh <application_name>
#%
#%  Steps performed:
#%   1.  mkdir /tmp/auditarchive
#%   2.  rm /tmp/auditarchive/*.del         (clear previous leftovers)
#%   3.  db2audit flush
#%   4.  db2audit archive database BLUDB to /tmp/auditarchive
#%   5.  db2audit archive to /tmp/auditarchive
#%   6.  db2audit extract delasc to /tmp/auditarchive from files db2audit.db.BLUDB.log.0.*
#%   7.  db2audit extract delasc to /tmp/auditarchive from files db2audit.instance.log.0.*
#%   8.  Copy all *.del files to /mnt/blumeta0/audit/<YYYYMMDD>/  (local)
#%       Upload to S3: audit_logs/<app>_<YYYYMMDD>_<file>.del     (flat key — db2RemStgManager)
#%   9.  rm -rf /tmp/auditarchive
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

ARCHIVE_DIR="/tmp/auditarchive"
AUDIT_DIR="/mnt/blumeta0/audit"
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
# Source DB2 environment (instance owner required)
# DB2's own profile scripts reference variables that may not yet be set, so
# we temporarily disable the nounset (-u) option while sourcing them.
# ============================================================================
set +u
. "${HOME}/sqllib/db2profile"
set -u

# ============================================================================
# Load COS / S3 parameters from .PROPS (CONTAINER, SERVER, PARM1, PARM2)
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
log "INFO  :: Audit dest    : ${AUDIT_DIR}/${DATE}/"
log "INFO  :: S3 bucket     : ${CONTAINER}"
log "INFO  :: S3 key format : audit_logs/${APP_NAME}_${DATE}_<file>.del"
log "INFO  :: ============================================================"

# ============================================================================
# 1. Prepare working directory
# ============================================================================
log "INFO  :: [1/7] Creating archive directory ${ARCHIVE_DIR}"
mkdir -p "${ARCHIVE_DIR}"

# ============================================================================
# 2. Remove leftover *.del files from a previous run
# ============================================================================
log "INFO  :: [2/7] Removing any leftover .del files from ${ARCHIVE_DIR}"
rm -f "${ARCHIVE_DIR}"/*.del 2>/dev/null || true

# ============================================================================
# 3. Flush active audit buffers
# ============================================================================
log "INFO  :: [3/7] Flushing db2audit buffers"
db2audit flush
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: db2audit flush failed (RC=${RC})"
  exit 1
fi
log "INFO  ::       Flush succeeded"

# ============================================================================
# 4. Archive the database audit log
# ============================================================================
log "INFO  :: [4/7] Archiving database audit log for ${DBNAME} to ${ARCHIVE_DIR}"
db2audit archive database "${DBNAME}" to "${ARCHIVE_DIR}"
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: db2audit archive database failed (RC=${RC})"
  exit 1
fi
log "INFO  ::       Database archive succeeded"

# ============================================================================
# 5. Archive the instance audit log
# ============================================================================
log "INFO  :: [5/7] Archiving instance audit log to ${ARCHIVE_DIR}"
db2audit archive to "${ARCHIVE_DIR}"
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: db2audit archive instance failed (RC=${RC})"
  exit 1
fi
log "INFO  ::       Instance archive succeeded"

# ============================================================================
# 6. Extract database archived log to DEL/ASC format
# ============================================================================
log "INFO  :: [6/7] Extracting database audit archive to delasc"
DB_LOG_PATTERN="${ARCHIVE_DIR}/db2audit.db.${DBNAME}.log.0.*"
DB_LOG_FILES=$(ls ${DB_LOG_PATTERN} 2>/dev/null || true)

if [ -z "${DB_LOG_FILES}" ]; then
  log "WARN  ::       No database audit archive files found matching ${DB_LOG_PATTERN} — skipping"
else
  log "INFO  ::       Found files: ${DB_LOG_FILES}"
  db2audit extract delasc to "${ARCHIVE_DIR}" from files ${DB_LOG_PATTERN}
  RC=$?
  if [ $RC -ne 0 ]; then
    log "ERROR :: db2audit extract (database) failed (RC=${RC})"
    exit 1
  fi
  log "INFO  ::       Database audit extract completed"
fi

# ============================================================================
# 7. Extract instance archived log to DEL/ASC format
# ============================================================================
log "INFO  :: [7/7] Extracting instance audit archive to delasc"
INST_LOG_PATTERN="${ARCHIVE_DIR}/db2audit.instance.log.0.*"
INST_LOG_FILES=$(ls ${INST_LOG_PATTERN} 2>/dev/null || true)

if [ -z "${INST_LOG_FILES}" ]; then
  log "WARN  ::       No instance audit archive files found matching ${INST_LOG_PATTERN} — skipping"
else
  log "INFO  ::       Found files: ${INST_LOG_FILES}"
  db2audit extract delasc to "${ARCHIVE_DIR}" from files ${INST_LOG_PATTERN}
  RC=$?
  if [ $RC -ne 0 ]; then
    log "ERROR :: db2audit extract (instance) failed (RC=${RC})"
    exit 1
  fi
  log "INFO  ::       Instance audit extract completed"
fi

# ============================================================================
# 8. Copy *.del to local audit folder AND upload to S3, then remove from source
# ============================================================================
DEL_FILES=$(ls "${ARCHIVE_DIR}"/*.del 2>/dev/null || true)

if [ -z "${DEL_FILES}" ]; then
  log "WARN  :: No .del files found in ${ARCHIVE_DIR} — nothing to copy/upload"
else
  # ---- Local copy to persistent audit volume --------------------------------
  DEST_DIR="${AUDIT_DIR}/${DATE}"
  log "INFO  :: Creating local audit destination ${DEST_DIR}"
  mkdir -p "${DEST_DIR}"

  # ---- S3 upload target -----------------------------------------------------
  # Resolve DB2 storage alias for the backup bucket (registered by Set_DB_COS_Storage.sh)
  BUCKET_ALIAS=$(db2 list storage access | grep "${CONTAINER}" -B4 | grep ALIAS | awk -F '=' '{print $2}' | tr -d ' ')
  log "INFO  :: S3 bucket    : ${CONTAINER}"
  log "INFO  :: S3 alias     : ${BUCKET_ALIAS}"

  if [ -z "${BUCKET_ALIAS}" ]; then
    log "ERROR :: Could not resolve DB2 storage alias for bucket '${CONTAINER}'. Run Set_DB_COS_Storage.sh to register it."
    exit 1
  fi

  # S3 key format (flat — db2RemStgManager does not support nested subdirectories):
  # audit_logs_<app>_<YYYYMMDD>_<filename>   e.g. audit_logs_facilities_20260819_audit.del
  S3_FOLDER="audit_logs"
  log "INFO  :: S3 folder    : ${S3_FOLDER}"

  for DEL_FILE in ${DEL_FILES}; do
    FILE_NAME=$(basename "${DEL_FILE}")
    # Encode app name and date into the filename so it is sortable and unique
    S3_KEY="${S3_FOLDER}/${APP_NAME}_${DATE}_${FILE_NAME}"

    # -- Step A: copy to local persistent audit folder
    log "INFO  ::   [local]  ${DEL_FILE} -> ${DEST_DIR}/${FILE_NAME}"
    cp "${DEL_FILE}" "${DEST_DIR}/${FILE_NAME}"
    RC=$?
    if [ $RC -ne 0 ]; then
      log "ERROR :: Failed to copy ${FILE_NAME} to ${DEST_DIR} (RC=${RC})"
      exit 1
    fi
    log "INFO  ::   [local]  Copy succeeded"

    # -- Step B: upload to S3 (flat path — same pattern as auditExtractUpload.sh)
    # Format: DB2REMOTE://AWSCOS//audit_logs/<app>_<date>_<file>
    # IMPORTANT: source file is only deleted (Step C) after this upload succeeds.
    # If upload fails, exit 1 fires and rm is never reached.
    COS_TARGET="DB2REMOTE://${BUCKET_ALIAS}//${S3_KEY}"
    log "INFO  ::   [s3]     Uploading ${DEL_FILE} -> ${COS_TARGET}"
    db2RemStgManager alias put source="${DEL_FILE}" target="${COS_TARGET}"
    RC=$?
    if [ $RC -ne 0 ]; then
      log "ERROR :: S3 upload of ${FILE_NAME} failed (RC=0x$(printf '%08X' ${RC}))"
      log "ERROR :: Source file ${DEL_FILE} has NOT been deleted — safe to retry"
      exit 1
    fi
    log "INFO  ::   [s3]     Upload confirmed: ${COS_TARGET}"

    # -- Step C: delete from source ONLY after S3 upload is confirmed above
    log "INFO  ::   [clean]  S3 upload confirmed — now deleting source ${DEL_FILE}"
    rm -f "${DEL_FILE}"
    log "INFO  ::   [clean]  Deleted"
  done

  log "INFO  :: All .del files processed"
  log "INFO  :: Local audit folder contents:"
  ls -lh "${DEST_DIR}"
fi

# ============================================================================
# 9. Remove archive directory (raw archived logs — already processed above)
#    Only reached if ALL files uploaded and deleted successfully in Step 8.
# ============================================================================
log "INFO  :: Removing archive directory ${ARCHIVE_DIR}"
rm -rf "${ARCHIVE_DIR}"
log "INFO  :: Archive directory removed"

log "INFO  :: ============================================================"
log "INFO  :: DB2 audit extraction completed successfully"
log "INFO  :: ============================================================"
exit 0

# -- End of Script

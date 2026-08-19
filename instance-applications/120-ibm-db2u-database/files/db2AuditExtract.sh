#!/bin/sh

# ----------------------------------------------------------------------------
#% Script Name  : db2AuditExtract.sh
#% Description  : Archive and extract DB2 audit logs as DEL/ASC files, then
#%                copy to an S3 audit bucket and remove local copies.
#% Created On   : 2026
#%
#%  **************  THIS NEEDS TO BE RUN AS INSTANCE OWNER (db2inst1).  ******
#%  USAGE:
#%          db2AuditExtract.sh <audit_bucket_name> <application_name>
#%
#% Steps performed:
#%   1. Flush active audit buffers
#%   2. Archive the database audit log (BLUDB)
#%   3. Archive the instance audit log
#%   4. Extract archived database log to delasc format
#%   5. Extract archived instance log to delasc format
#%   6. Upload all *.del files to s3://<bucket>/audit-log-<application_name>/<YYYYMMDD>/
#%      and delete each file from source immediately after a successful upload
#%   7. Remove /tmp/auditarchive and all its contents
# ----------------------------------------------------------------------------

set -eo pipefail

# ============================================================================
# Parameters / Inputs
# ============================================================================
AUDIT_BUCKET="${1:-}"
APP_NAME="${2:-}"

if [ -z "${AUDIT_BUCKET}" ] || [ -z "${APP_NAME}" ]; then
  echo "ERROR :: Usage: $0 <audit_bucket_name> <application_name>"
  exit 1
fi

ARCHIVE_DIR="/tmp/auditarchive"
DBNAME="BLUDB"
HOSTNAME=$(hostname)
DATE=$(date +"%Y%m%d")

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
# Load COS / S3 parameters (bucket alias etc.)
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
# 1. Prepare working directory
# ============================================================================
log "INFO  :: Preparing archive directory ${ARCHIVE_DIR}"
mkdir -p "${ARCHIVE_DIR}"

# Remove any leftover *.del files from a previous run
log "INFO  :: Removing any leftover .del files from ${ARCHIVE_DIR}"
rm -f "${ARCHIVE_DIR}"/*.del

# ============================================================================
# 2. Flush active audit buffers
# ============================================================================
log "INFO  :: Flushing db2audit buffers"
db2audit flush
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: db2audit flush failed (RC=${RC})"
  exit 1
fi

# ============================================================================
# 3. Archive the database audit log
# ============================================================================
log "INFO  :: Archiving database audit log for ${DBNAME} to ${ARCHIVE_DIR}"
db2audit archive database "${DBNAME}" to "${ARCHIVE_DIR}"
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: db2audit archive database failed (RC=${RC})"
  exit 1
fi

# ============================================================================
# 4. Archive the instance audit log
# ============================================================================
log "INFO  :: Archiving instance audit log to ${ARCHIVE_DIR}"
db2audit archive to "${ARCHIVE_DIR}"
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: db2audit archive instance failed (RC=${RC})"
  exit 1
fi

# ============================================================================
# 5. Extract database archived log to DEL/ASC format
# ============================================================================
log "INFO  :: Extracting database audit archive to delasc"
DB_LOG_PATTERN="${ARCHIVE_DIR}/db2audit.db.${DBNAME}.log.0.*"

# Verify at least one archived file exists before attempting extract
DB_LOG_FILES=$(ls ${DB_LOG_PATTERN} 2>/dev/null || true)
if [ -z "${DB_LOG_FILES}" ]; then
  log "WARN  :: No database audit archive files matching ${DB_LOG_PATTERN} — skipping db extract"
else
  db2audit extract delasc to "${ARCHIVE_DIR}" from files ${DB_LOG_PATTERN}
  RC=$?
  if [ $RC -ne 0 ]; then
    log "ERROR :: db2audit extract (database) failed (RC=${RC})"
    exit 1
  fi
  log "INFO  :: Database audit extract completed"
fi

# ============================================================================
# 6. Extract instance archived log to DEL/ASC format
# ============================================================================
log "INFO  :: Extracting instance audit archive to delasc"
INST_LOG_PATTERN="${ARCHIVE_DIR}/db2audit.instance.log.0.*"

INST_LOG_FILES=$(ls ${INST_LOG_PATTERN} 2>/dev/null || true)
if [ -z "${INST_LOG_FILES}" ]; then
  log "WARN  :: No instance audit archive files matching ${INST_LOG_PATTERN} — skipping instance extract"
else
  db2audit extract delasc to "${ARCHIVE_DIR}" from files ${INST_LOG_PATTERN}
  RC=$?
  if [ $RC -ne 0 ]; then
    log "ERROR :: db2audit extract (instance) failed (RC=${RC})"
    exit 1
  fi
  log "INFO  :: Instance audit extract completed"
fi

# ============================================================================
# 7. Upload *.del files to audit-log-<app>/<date>/ in S3 and delete from source
# ============================================================================
DEL_FILES=$(ls "${ARCHIVE_DIR}"/*.del 2>/dev/null || true)

if [ -z "${DEL_FILES}" ]; then
  log "WARN  :: No .del files found in ${ARCHIVE_DIR} — nothing to upload"
else
  BUCKET_ALIAS=$(db2 list storage access | grep "${AUDIT_BUCKET}" -B4 | grep ALIAS | awk -F '=' '{print $2}')
  # S3 path: audit-log-<application_name>/<YYYYMMDD>/
  TARGET_PREFIX="audit-log-${APP_NAME}/${DATE}"

  for DEL_FILE in ${DEL_FILES}; do
    FILE_NAME=$(basename "${DEL_FILE}")
    COS_TARGET="DB2REMOTE://${BUCKET_ALIAS}//${TARGET_PREFIX}/${FILE_NAME}"
    log "INFO  :: Uploading ${DEL_FILE} to ${COS_TARGET}"
    db2RemStgManager alias put \
      source="${DEL_FILE}" \
      target="${COS_TARGET}"
    RC=$?
    if [ $RC -ne 0 ]; then
      log "ERROR :: Upload of ${FILE_NAME} failed (RC=${RC})"
      exit 1
    fi
    log "INFO  :: Upload completed: ${FILE_NAME} — removing from source"
    rm -f "${DEL_FILE}"
  done
fi

# ============================================================================
# 8. Remove archive directory and all its contents
# ============================================================================
log "INFO  :: Removing archive directory ${ARCHIVE_DIR}"
rm -rf "${ARCHIVE_DIR}"
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: Failed to remove ${ARCHIVE_DIR} (RC=${RC})"
  exit 1
fi
log "INFO  :: Archive directory removed"

log "INFO  :: DB2 audit extraction and upload completed successfully"
exit 0

# -- End of Script

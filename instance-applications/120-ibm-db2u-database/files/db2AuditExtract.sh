#!/bin/bash

# ----------------------------------------------------------------------------
#% Script Name  : db2AuditExtract.sh
#% Description  : Archive and extract DB2 audit logs as DEL/ASC files, upload
#%                each *.del file to S3, then remove /tmp/auditarchive entirely.
#% Created On   : 2026
#%
#%  **************  THIS NEEDS TO BE RUN AS INSTANCE OWNER (db2inst1).  ******
#%  USAGE:
#%          db2AuditExtract.sh <application_name>
#%
#%  S3 target : s3://<bucket>/audit_logs/<app>/<YYYYMMDD>/<file>.del
#%
#%  Steps (matching work description exactly):
#%   1.  mkdir /tmp/auditarchive
#%   2.  rm /tmp/auditarchive/*.del
#%   3.  db2audit flush
#%   4.  db2audit archive database BLUDB to /tmp/auditarchive
#%   5.  db2audit archive to /tmp/auditarchive
#%   6.  db2audit extract delasc to /tmp/auditarchive from files db2audit.db.BLUDB.log.0.*
#%   7.  db2audit extract delasc to /tmp/auditarchive from files db2audit.instance.log.0.*
#%   8.  Upload each *.del to s3://<bucket>/audit_logs/<app>/<YYYYMMDD>/<file>.del
#%       Delete each *.del from source ONLY after its upload is confirmed
#%   9.  rm -rf /tmp/auditarchive
#%  10.  Purge /mnt/blumeta0/audit/<YYYYMMDD> folders older than 1 day
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
AUDIT_BASE="/mnt/blumeta0/audit"
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
log "INFO  :: S3 target     : s3://${CONTAINER}/audit_logs/${APP_NAME}/${DATE}/"
log "INFO  :: ============================================================"

# ============================================================================
# 1. mkdir /tmp/auditarchive
# ============================================================================
log "INFO  :: [1] mkdir ${ARCHIVE_DIR}"
mkdir -p "${ARCHIVE_DIR}"

# ============================================================================
# 2. rm /tmp/auditarchive/*.del
# ============================================================================
log "INFO  :: [2] rm ${ARCHIVE_DIR}/*.del"
rm -f "${ARCHIVE_DIR}"/*.del 2>/dev/null || true

# ============================================================================
# 3. db2audit flush
# ============================================================================
log "INFO  :: [3] db2audit flush"
db2audit flush
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: db2audit flush failed (RC=${RC})"
  exit 1
fi
log "INFO  ::     Flush succeeded"

# ============================================================================
# 4. db2audit archive database BLUDB to /tmp/auditarchive
# ============================================================================
log "INFO  :: [4] db2audit archive database ${DBNAME} to ${ARCHIVE_DIR}"
db2audit archive database "${DBNAME}" to "${ARCHIVE_DIR}"
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: db2audit archive database failed (RC=${RC})"
  exit 1
fi
log "INFO  ::     Database archive succeeded"

# ============================================================================
# 5. db2audit archive to /tmp/auditarchive  (instance log)
# ============================================================================
log "INFO  :: [5] db2audit archive to ${ARCHIVE_DIR}"
db2audit archive to "${ARCHIVE_DIR}"
RC=$?
if [ $RC -ne 0 ]; then
  log "ERROR :: db2audit archive instance failed (RC=${RC})"
  exit 1
fi
log "INFO  ::     Instance archive succeeded"

# ============================================================================
# 6. db2audit extract delasc ... from files db2audit.db.BLUDB.log.0.*
# ============================================================================
log "INFO  :: [6] db2audit extract delasc (database)"
DB_LOG_PATTERN="${ARCHIVE_DIR}/db2audit.db.${DBNAME}.log.0.*"
DB_LOG_FILES=$(ls ${DB_LOG_PATTERN} 2>/dev/null || true)

if [ -z "${DB_LOG_FILES}" ]; then
  log "WARN  ::     No database audit archive files found — skipping"
else
  log "INFO  ::     Found $(echo ${DB_LOG_FILES} | wc -w) file(s): $(echo ${DB_LOG_FILES} | tr '\n' ' ')"
  db2audit extract delasc to "${ARCHIVE_DIR}" from files ${DB_LOG_PATTERN}
  RC=$?
  if [ $RC -ne 0 ]; then
    log "ERROR :: db2audit extract (database) failed (RC=${RC})"
    exit 1
  fi
  log "INFO  ::     Database extract completed"
fi

# ============================================================================
# 7. db2audit extract delasc ... from files db2audit.instance.log.0.*
# ============================================================================
log "INFO  :: [7] db2audit extract delasc (instance)"
INST_LOG_PATTERN="${ARCHIVE_DIR}/db2audit.instance.log.0.*"
INST_LOG_FILES=$(ls ${INST_LOG_PATTERN} 2>/dev/null || true)

if [ -z "${INST_LOG_FILES}" ]; then
  log "WARN  ::     No instance audit archive files found — skipping"
else
  log "INFO  ::     Found $(echo ${INST_LOG_FILES} | wc -w) file(s): $(echo ${INST_LOG_FILES} | tr '\n' ' ')"
  db2audit extract delasc to "${ARCHIVE_DIR}" from files ${INST_LOG_PATTERN}
  RC=$?
  if [ $RC -ne 0 ]; then
    log "ERROR :: db2audit extract (instance) failed (RC=${RC})"
    exit 1
  fi
  log "INFO  ::     Instance extract completed"
fi

# ============================================================================
# 8. Upload each *.del to S3, delete from source after confirmed upload
#    AWS CLI installed by postsync job (07-postsync-setup-db2_Job.yaml)
#    using same method as HADR setup job.
# ============================================================================
DEL_FILES=$(ls "${ARCHIVE_DIR}"/*.del 2>/dev/null || true)

if [ -z "${DEL_FILES}" ]; then
  log "WARN  :: [8] No .del files found in ${ARCHIVE_DIR} — nothing to upload"
else
  AWS_CLI="/mnt/backup/aws/dist/aws"

  if [ ! -x "${AWS_CLI}" ]; then
    log "ERROR :: AWS CLI not found at ${AWS_CLI}"
    log "ERROR :: Trigger an ArgoCD sync to run the postsync job which installs it"
    exit 1
  fi

  export AWS_ACCESS_KEY_ID="${PARM1}"
  export AWS_SECRET_ACCESS_KEY="${PARM2}"
  export AWS_DEFAULT_REGION=$(echo "${SERVER}" | sed 's|.*s3\.\([^.]*\)\.amazonaws.*|\1|')

  log "INFO  :: [8] Uploading *.del files to s3://${CONTAINER}/audit_logs/${APP_NAME}/${DATE}/"

  for DEL_FILE in ${DEL_FILES}; do
    FILE_NAME=$(basename "${DEL_FILE}")
    S3_TARGET="s3://${CONTAINER}/audit_logs/${APP_NAME}/${DATE}/${FILE_NAME}"

    log "INFO  ::     Uploading ${FILE_NAME} -> ${S3_TARGET}"
    "${AWS_CLI}" s3 cp "${DEL_FILE}" "${S3_TARGET}"
    RC=$?
    if [ $RC -ne 0 ]; then
      log "ERROR :: Upload of ${FILE_NAME} failed (RC=${RC})"
      log "ERROR :: ${DEL_FILE} has NOT been deleted — safe to retry"
      exit 1
    fi
    log "INFO  ::     Upload confirmed — deleting source ${DEL_FILE}"
    rm -f "${DEL_FILE}"
  done

  log "INFO  ::     All .del files uploaded and removed from source"
fi

# ============================================================================
# 9. rm -rf /tmp/auditarchive
# ============================================================================
log "INFO  :: [9] rm -rf ${ARCHIVE_DIR}"
rm -rf "${ARCHIVE_DIR}"
log "INFO  ::     Done"

# ============================================================================
# 10. Purge /mnt/blumeta0/audit/<YYYYMMDD> folders older than 1 day
#     Keeps the 100GB filesystem free — S3 is the permanent store.
#     Only removes YYYYMMDD-named dirs; leaves all other content untouched.
# ============================================================================
log "INFO  :: [10] Purging ${AUDIT_BASE}/<YYYYMMDD> folders older than 1 day"
find "${AUDIT_BASE}" -mindepth 1 -maxdepth 1 -type d \
  -name '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' -mtime +1 | \
  while read OLD_DIR; do
    log "INFO  ::      Removing ${OLD_DIR}"
    rm -rf "${OLD_DIR}"
  done
log "INFO  ::      Purge complete"

log "INFO  :: ============================================================"
log "INFO  :: Audit extraction completed successfully"
log "INFO  :: S3 : s3://${CONTAINER}/audit_logs/${APP_NAME}/${DATE}/"
log "INFO  :: ============================================================"
exit 0

# -- End of Script

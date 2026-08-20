#!/bin/bash

# ----------------------------------------------------------------------------
#% Script Name  : db2AuditExtract.sh
#% Description  : Archive and extract DB2 audit logs as DEL/ASC files, upload
#%                each *.del file to S3, then remove source files.
#% Created On   : 2026
#%
#%  **************  THIS NEEDS TO BE RUN AS INSTANCE OWNER (db2inst1).  ******
#%  USAGE:
#%          db2AuditExtract.sh <application_name>
#%
#%  S3 target : s3://<bucket>/audit_logs/<app>/<YYYY-MM-DD>/<file>.del
#%
#%  Steps:
#%   1.  mkdir /tmp/auditarchive
#%   2.  rm /tmp/auditarchive/*.del
#%   3.  db2audit flush
#%   4.  db2audit archive database BLUDB to /tmp/auditarchive
#%   5.  db2audit archive to /tmp/auditarchive
#%   6.  db2audit extract delasc to /tmp/auditarchive from files db2audit.db.BLUDB.log.0.*
#%   7.  db2audit extract delasc to /tmp/auditarchive from files db2audit.instance.log.0.*
#%   8.  Upload each *.del to S3; copy to /mnt/blumeta0/audit/; delete source after upload
#%   9.  rm -rf /tmp/auditarchive
#%  10.  Process /mnt/blumeta0/audit/ (flat):
#%       a. Convert any *.log files → *.del via db2audit extract delasc
#%       b. Upload ALL *.del (pre-existing + newly converted) to S3
#%       c. Delete each *.del from source after confirmed S3 upload
#%       d. Delete *.log files after all uploads succeed
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
DATE=$(date +"%Y-%m-%d")
DT=$(date +"%Y-%m-%d_%H%M%S")

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
# Configure AWS CLI (used in both step 8 and step 10)
# ============================================================================
AWS_CLI="/mnt/backup/aws/dist/aws"

if [ ! -x "${AWS_CLI}" ]; then
  echo "ERROR :: AWS CLI not found at ${AWS_CLI}"
  echo "ERROR :: Trigger an ArgoCD sync to run the postsync job which installs it"
  exit 1
fi

export AWS_ACCESS_KEY_ID="${PARM1}"
export AWS_SECRET_ACCESS_KEY="${PARM2}"
export AWS_DEFAULT_REGION=$(echo "${SERVER}" | sed 's|.*s3\.\([^.]*\)\.amazonaws.*|\1|')

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
  # Create local audit destination directory
  LOCAL_DEST="${AUDIT_BASE}/${DATE}"
  log "INFO  :: [8] Copying *.del to local audit folder ${LOCAL_DEST}"
  mkdir -p "${LOCAL_DEST}"

  log "INFO  ::     Uploading *.del files to s3://${CONTAINER}/audit_logs/${APP_NAME}/${DATE}/"

  for DEL_FILE in ${DEL_FILES}; do
    FILE_NAME=$(basename "${DEL_FILE}")

    # Step A: copy to /mnt/blumeta0/audit/<YYYY-MM-DD>/
    log "INFO  ::     [local]  ${FILE_NAME} -> ${LOCAL_DEST}/${FILE_NAME}"
    cp "${DEL_FILE}" "${LOCAL_DEST}/${FILE_NAME}"
    RC=$?
    if [ $RC -ne 0 ]; then
      log "ERROR :: Failed to copy ${FILE_NAME} to ${LOCAL_DEST} (RC=${RC})"
      exit 1
    fi

    # Step B: upload to S3
    S3_TARGET="s3://${CONTAINER}/audit_logs/${APP_NAME}/${DATE}/${FILE_NAME}"
    log "INFO  ::     [s3]     ${FILE_NAME} -> ${S3_TARGET}"
    "${AWS_CLI}" s3 cp "${DEL_FILE}" "${S3_TARGET}"
    RC=$?
    if [ $RC -ne 0 ]; then
      log "ERROR :: Upload of ${FILE_NAME} failed (RC=${RC})"
      log "ERROR :: ${DEL_FILE} has NOT been deleted — safe to retry"
      exit 1
    fi

    # Step C: delete from /tmp/auditarchive ONLY after S3 upload confirmed
    log "INFO  ::     [clean]  S3 upload confirmed — deleting source ${DEL_FILE}"
    rm -f "${DEL_FILE}"
  done

  log "INFO  ::     All .del files copied to ${LOCAL_DEST} and uploaded to S3"
fi

# ============================================================================
# 9. rm -rf /tmp/auditarchive
# ============================================================================
log "INFO  :: [9] rm -rf ${ARCHIVE_DIR}"
rm -rf "${ARCHIVE_DIR}"
log "INFO  ::     Done"

# ============================================================================
# 10. Process /mnt/blumeta0/audit/ (flat directory — no subfolders):
#     a. Convert any *.log files to *.del via db2audit extract delasc
#     b. Upload ALL *.del files (pre-existing + newly converted) to S3
#     c. Delete each *.del from source ONLY after confirmed S3 upload
#     d. Delete *.log files after all uploads succeed
# ============================================================================
log "INFO  :: [10] Processing ${AUDIT_BASE}/ → S3"

if [ ! -d "${AUDIT_BASE}" ]; then
  log "WARN  ::      ${AUDIT_BASE} does not exist — skipping"
else

  # a. Convert any *.log files to *.del
  AUDIT_LOG_FILES=$(ls "${AUDIT_BASE}"/*.log 2>/dev/null || true)
  if [ -n "${AUDIT_LOG_FILES}" ]; then
    log "INFO  ::      [a] Found raw .log files — running db2audit extract"
    for AUDIT_LOG in ${AUDIT_LOG_FILES}; do
      AUDIT_LOG_NAME=$(basename "${AUDIT_LOG}")
      log "INFO  ::          [extract] ${AUDIT_LOG_NAME} -> .del"
      db2audit extract delasc to "${AUDIT_BASE}" from files "${AUDIT_LOG}"
      RC=$?
      if [ $RC -ne 0 ]; then
        log "ERROR ::          db2audit extract failed for ${AUDIT_LOG_NAME} (RC=${RC}) — skipping"
      fi
    done
    log "INFO  ::      [a] Extraction complete"
  else
    log "INFO  ::      [a] No raw .log files found in ${AUDIT_BASE}"
  fi

  # b+c. Upload ALL *.del files, delete each from source after confirmed upload
  AUDIT_DEL_FILES=$(ls "${AUDIT_BASE}"/*.del 2>/dev/null || true)
  if [ -z "${AUDIT_DEL_FILES}" ]; then
    log "WARN  ::      [b] No .del files found in ${AUDIT_BASE} — nothing to upload"
  else
    AUDIT_UPLOAD_ERRORS=0
    log "INFO  ::      [b] Uploading all .del files to s3://${CONTAINER}/audit_logs/${APP_NAME}/${DATE}/"
    for AUDIT_DEL in ${AUDIT_DEL_FILES}; do
      AUDIT_DEL_NAME=$(basename "${AUDIT_DEL}")
      AUDIT_S3_TARGET="s3://${CONTAINER}/audit_logs/${APP_NAME}/${DATE}/${AUDIT_DEL_NAME}"
      log "INFO  ::          [s3]    ${AUDIT_DEL_NAME} -> ${AUDIT_S3_TARGET}"
      "${AWS_CLI}" s3 cp "${AUDIT_DEL}" "${AUDIT_S3_TARGET}"
      RC=$?
      if [ $RC -ne 0 ]; then
        log "ERROR ::          Upload of ${AUDIT_DEL_NAME} failed (RC=${RC}) — source NOT deleted"
        AUDIT_UPLOAD_ERRORS=$((AUDIT_UPLOAD_ERRORS + 1))
        continue
      fi
      log "INFO  ::          [clean] Upload confirmed — removing ${AUDIT_DEL}"
      rm -f "${AUDIT_DEL}"
    done

    if [ ${AUDIT_UPLOAD_ERRORS} -gt 0 ]; then
      log "ERROR ::      ${AUDIT_UPLOAD_ERRORS} upload(s) failed — failed files left in ${AUDIT_BASE} for retry"
      exit 1
    fi
    log "INFO  ::      [b] All .del files uploaded and removed from source"
  fi

  # d. Delete *.log files now that all uploads succeeded
  AUDIT_LOG_REMAINING=$(ls "${AUDIT_BASE}"/*.log 2>/dev/null || true)
  if [ -n "${AUDIT_LOG_REMAINING}" ]; then
    log "INFO  ::      [d] Removing source .log files"
    for AUDIT_LOG in ${AUDIT_LOG_REMAINING}; do
      log "INFO  ::          [clean] Removing $(basename "${AUDIT_LOG}")"
      rm -f "${AUDIT_LOG}"
    done
    log "INFO  ::      [d] Source .log files removed"
  fi

fi

log "INFO  :: ============================================================"
log "INFO  :: Audit extraction completed successfully"
log "INFO  :: S3 : s3://${CONTAINER}/audit_logs/${APP_NAME}/${DATE}/"
log "INFO  :: ============================================================"
exit 0

# -- End of Script

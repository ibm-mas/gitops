#!/bin/sh

# ----------------------------------------------------------------------------
#% Script Name  : auditExtractUpload.sh
#% Description  : Script to Archive, Extract the audit logs and upload to COS
#% Created On   : 10th February 2026
#%
#% Author       : Mujibur Rahman
#% Email        : mujibur.rahman1@ibm.com
# ----------------------------------------------------------------------------
# Version       Date            Changed By      Description
# ----------------------------------------------------------------------------
#     0.1       10-02-2026      Mujib           Initial Version
#     0.2       04-05-2026      Prudhviraj P    Updated the loggging, clean up of old archives, induced compression to archives
#                                                    
# ----------------------------------------------------------------------------
#  **************  THIS NEEDS TO BE RUN AS INSTANCE OWNER.   *****************
#   USAGE:
#           auditExtractUpload.sh
#
#  ***************************************************************************

#set -euo pipefail

# ============================================================================
# Parameters/Inputs 
# ============================================================================

HOSTNAME=$(hostname)
HOSTIP=$(hostname -i)
WHOAMI=$(whoami)
INST=$(/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | awk -F, '{print $4}')
INSTHOME=$(/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | grep "${INST}" | awk -F ',' '{print $5}'| sed 's/\/sqllib//')
BASE_DIR=${INSTHOME}/bin
DT=$(date +"%Y%m%d_%H%M%S")
DBNAME="BLUDB"

# ===========================================================================
# Invoking DB2 Profile
# ===========================================================================

. ${INSTHOME}/sqllib/db2profile

# -------------------------------
# Load COS parameters
# -------------------------------
. /mnt/backup/bin/.PROPS

# ===========================================================================
# Debug Options
# ===========================================================================

# set -x;       # Uncomment to debug this shell script
# set -n;       # Uncomment to check your syntax, without execution.


# -- Extract the info needed from db2audit 

DATA_DIR=$( db2audit describe | grep "Audit Data Path: " | awk -F ': ' '{gsub(/"/, ""); print $2}' | sed 's/\/$//' );
ARCHIVE_DIR=$( db2audit describe | grep "Audit Archive Path:" | awk -F ': ' '{gsub(/"/, ""); print $2}' | sed 's/\/$//' );

# -------------------------------
# Functions
# -------------------------------
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

cleanup() {
  log "INFO  :: Ensuring db2audit is running "
  db2audit start >/dev/null 2>&1 || true
}

trap cleanup EXIT

# -------------------------------
# Start processing
# -------------------------------
log "INFO  :: Starting DB2 audit extraction for database $DBNAME"

: '
# Stop audit
db2audit stop
RC=$?
if [[ $RC -eq 0 ]]; then 
  log "INFO  :: db2audit stopped"
else
  log "ERROR :: db2audit cannot be stopped"
fi
'

# Flush records
db2audit flush > /dev/null 2>&1
RC=$?
if [[ $RC -eq 0 ]]; then 
  log "INFO  :: db2audit flushed"
else
  log "ERROR :: db2audit cannot be flushed"
fi

# Archive audit logs
db2audit archive database "$DBNAME" > /dev/null 2>&1 
RC=$?
if [[ $RC -eq 0 ]]; then 
  log "INFO  :: db2audit archived"
else
  log "ERROR :: db2audit cannot be archived"
  exit
fi
#db2audit.db.BLUDB.log.0.20260504093246
#db2audit.db."$DBNAME".log.0.
DTN=$( date +'%Y%m%d%H' )

# Identify latest archived audit file
AUDIT_LOG=$(ls -t "$ARCHIVE_DIR"/db2audit.db."$DBNAME".log.0.$DTN* 2>/dev/null | head -1)
AUDIT_FILE="${ARCHIVE_DIR}/db2audit_report.${DT}"
AUDIT_ZIP="${AUDIT_FILE}.zip"

log "INFO  :: Verifying whether audit log is available or not"

if [[ -z "${AUDIT_LOG:-}" ]]; then
  log "ERROR :: No archived audit file found"
  exit 1
fi

log "INFO  :: Extracting audit data from $AUDIT_LOG"

# Extract audit data
db2audit extract file "$AUDIT_FILE" from files "$AUDIT_LOG" > /dev/null 2>&1 
RC=$?
if [[ $RC -eq 0 ]]; then 
  log "INFO  :: Audit log extract and created as $AUDIT_FILE"
else
  log "ERROR :: Audit Failed to extract. "
  exit
fi

log "INFO  :: Compressing the Audit file : $AUDIT_FILE"
zip -r ${AUDIT_ZIP} ${AUDIT_FILE} > /dev/null 2>&1 
RC=$?
if [[ $RC -eq 0 ]]; then 
  log "INFO  :: Audit log Compressed to $AUDIT_ZIP"
  log "INFO  :: Removing the extracted and archived files "
  log "INFO  :: ${AUDIT_FILE} "
  log "INFO  :: ${AUDIT_LOG} "
  rm ${AUDIT_FILE} ${AUDIT_LOG}
  RC2=$?
  if [[ $RC2 -eq 0 ]]; then 
    log "INFO  :: Removed both extracted/Archive audit files "
  else
    log "ERROR :: Failed to delete the extracted/Archive audit files "
    exit
  fi
else
  log "ERROR :: Audit Failed to Compress. "
  exit
fi

# Restart audit
#db2audit start
#log "db2audit started"

# Upload to COS
log "INFO  :: Uploading audit extract to COS"

AUDZIP=$( echo $AUDIT_ZIP | awk -F '/' '{print $NF}' )
COS_TARGET="DB2REMOTE://AWSCOS//AUDIT_LOGS/${AUDZIP}"

db2RemStgManager alias put \
  source="$AUDIT_ZIP" \
  target="$COS_TARGET" > /dev/null 2>&1
RC=$?
if [[ $RC -eq 0 ]]; then 
  log "INFO  :: Upload completed to $COS_TARGET"
else
  log "ERROR :: Failed to Upload. "
  exit
fi


# -- Clean the old archives more than 30 days
log "INFO  :: Deleting the old archive more than 30 Days from Pod "
find ${ARCHIVE_DIR} -name db2audit_report.*.zip -type f -mtime +30 -exec rm {} \;
RC=$?
if [[ $RC -eq 0 ]]; then 
  log "INFO  :: Cleaned archives more than 30 Days"
else
  log "ERROR :: Failed to clean the old archives  "
  exit
fi

log "INFO  :: Execution of audit extract and upload has completed. "
exit 0


# -- End of the Script
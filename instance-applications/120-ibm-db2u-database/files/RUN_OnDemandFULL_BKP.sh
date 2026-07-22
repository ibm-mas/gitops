#!/bin/bash
#########################################################
#   RUN_OnDemandFULL_BKP.sh 
#   RUN_OnDemandFULL_BKP.sh will be called by OnDemand Jobs 
#   This script will list all local databases running in the instance on a node.  It will call the
#   DB2_Backup.sh script to run a backup for each running database.
#   Variables are set at the top of the DB2_Backup.sh script to determine if a full backup needs to be run
#   based on the day of the week.  Currently, Saturday is when the full backup runs, incremental backups run
#   every all other days.
#
#   Variables to be set
#   SLACKURL = The channel were notifications are send
#   BACKUP_SCRIPT =  The backup script that RUN_OnDemandFULL_BKP.sh calls
#   DAYOFFULL = Defines the day of the week that the full backup will on on (must match the same format as the output from $(date))
#   NUMOFBKUPTOKEEP = This defines the number of days to keep a backup image on local disk
#
#   Variables determined by the environment
#   BACKUPTYPE = Is determined from the $(date) command and the DAYOFFULL value
#   DB2INSTANCE = Pulled from the environment
#   HOSTNAME
#   DBNAME = Pulled from the $(db2 list db directory)
#   
#   Backup command issued
#   ./DB2_Backup.sh ${DB2INSTANCE} ${DBNAME} ${NUMOFBKUPTOKEEP} ${BACKUPTYPE} 2>>.BackupLOG.stderr > .BackupLOG.out
#########################################################

# -- Standard Parameters 
DATETIME=$(date +'%F_%H%M%S');
HOSTNAME=$(hostname)
HOSTIP=$(/sbin/ifconfig | grep "inet" | grep broadcast | awk '{print $2}')
NAMESPACE=$(hostname -A | awk -F '.' '{print $3}')
DBINSTANCE=$(whoami);
INSTANCE_HOME=$(/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | grep "${DBINSTANCE}" | awk -F ',' '{print $5}'| sed 's/\/sqllib//' )
CUSTNAME=$(hostname | sed 's/c-db2wh-//; s/c-db2u-//; s/c-//; s/-db2u-0//; s/db2u/-/; ' | tr '[:lower:]' '[:upper:]' )
SCRIPT_DIR=${INSTANCE_HOME}/bin
ICD_LOG=${SCRIPT_DIR}/.Maillive.log
Maillog="/tmp/.backup_maillog"

# -- Verify and source db2profile 

if [[ ! -f "${INSTANCE_HOME}/sqllib/db2profile" ]]; then
   echo "ERROR - ${INSTANCE_HOME}/sqllib/db2profile not found"
   EXIT_STATUS=1
else
   . ${INSTANCE_HOME}/sqllib/db2profile
fi
# -- Source the PROPS File 
. /mnt/backup/bin/.PROPS

# -- Debug Mode 
# set -x;       # Uncomment to debug this shell script
# set -n;       # Uncomment to check your syntax, without execution.

# -- Backup parameters 
BACKUPTYPE=full
BACKUP_SCRIPT="${SCRIPT_DIR}/DB2_Backup.sh"
BUCKET_ALIAS=$(db2 list storage access | grep ${CONTAINER} -B4 | grep ALIAS | awk -F '=' '{print $2}')
HSTYPE="Backup"

# -- Valid only for MAS-CP4D Customers 
if [[ "${NAMESPACE}" == "mas-cp4d" || "${NAMESPACE}" == "mas-cpd" ]] ; then 
   CUSTNAME=$(echo ${CONTAINER} | awk -F '-backup-' '{print $2}'  | awk -F '-pr-' '{print $1}' | tr '[:lower:]' '[:upper:]')
fi 

# -- Database Environment 
if [[ "${CONTAINER}" =~ "masms" ]]; then 
   DBENV="MASMS"
else
   DBENV="MASSAAS"
fi

# -- For mapping Hostname with Servicedesk
NS=$( echo ${NAMESPACE} | sed 's/mas-//; s/-core//; s/-manage//; s/-facilities//; s/-db2u//;' );
if   [[ "${NAMESPACE}" =~ "manage" || "${HOSTNAME}" =~ "manage" ]] ; then 
   HSHOSTS="main.manage.${NS}.suite"
elif [[ "${NAMESPACE}" =~ "core" || "${HOSTNAME}" =~ "core" ]]; then
   HSHOSTS="main.home.${NS}.suite"
elif [[ "${NAMESPACE}" =~ "monitor" || "${HOSTNAME}" =~ "iot" ]]; then
   HSHOSTS="main.monitor.${NS}.suite"
elif [[ "${NAMESPACE}" =~ "facilities" || "${HOSTNAME}" =~ "facilities" ]]; then
   HSHOSTS="main.facilities.${NS}.suite"
fi


# -- Create ICD Incident , If Backup fails 

CREATE_ICD() {
	HSTYPE=$(echo ${HSTYPE} | tr '[:lower:]' '[:upper:]')
	DES="$1"
	LONGDES=$(cat ${ICD_LOG} | sed 's/"//g' | sed "s/'//g")
	LONGDES=$(echo "<pre>${LONGDES}</pre>")

   # -- Verify the ICD Status 
   if curl -k -s --connect-timeout 3 ${ICD_URL_SAAS} >/dev/null; then
      CURL_REQ="--request POST --url ${ICD_URL_SAAS} "
      AUTH_REQ="apikey: ${ICD_API_KEY}"
   fi 

   # -- Generate Curl Syntax to push to ICD
   cat << ! >.curl_${DBNAME}_ICD.sh
      curl ${CURL_REQ}           \
      --header '${AUTH_REQ}'     \
      --header 'Content-Type: application/json' \
      --data '{
         "description":"${DES}",
         "reportedpriority":3,
         "internalpriority":3,
         "reportedby":"DB2",
         "affectedperson":"${DBENV}",
         "ownergroup":"HSDBA",
         "description_longdescription":"${LONGDES}",
         "siteid":"001",
         "classstructureid":"1341",
         "classificationid":"IN-DBPERF",
         "hshost":"${HSHOSTS}",
         "hstype":"${HSTYPE}"
      }'
!
   /bin/bash .curl_${DBNAME}_ICD.sh > .curl_${DBNAME}_ICD.out 2>&1
}

# -- Loop through the available databases in the instance 

DBS=$(db2 list db directory | grep -B5 "Indirect" | grep "Database name" |  awk '{ print $4 }' | sort -u  )
for DBNAME in ${DBS}
do
   cd ${SCRIPT_DIR}
   ${BACKUP_SCRIPT} ${DB2INSTANCE} ${DBNAME} ${NUMOFBKUPTOKEEP} ${BACKUPTYPE} 2>.BackupLOG.stderr > .BackupLOG.out
   RC=$?
   if [[ ${RC} -ne 0 ]]; then

      LONGDES="Failure to start the Backup job ${DATETIME} CUST=${CUSTNAME} - ${RC}"
      # -- Send Failure notification to a slack channel 
      cat << ! >.curl_${DBNAME}_RUN.sh
         curl -X POST -H 'Content-type: application/json' --data '{"text":"$LONGDES"}' ${SLACKURL}
!
      /bin/bash .curl_${DBNAME}_RUN.sh > .curl_${DBNAME}_RUN.out 2>&1

      # -- Create ICD ticket if fails  
      DES="${CUSTNAME} - ${DBENV} - ${DBNAME} - ${HOSTNAME} -- Failed to Start Backup!! "
      CREATE_ICD "${DES}"
   fi   
done

# -- END OF SCRIPT


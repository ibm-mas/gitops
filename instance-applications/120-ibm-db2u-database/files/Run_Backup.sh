#!/bin/bash
#########################################################
#       Run_Backup.sh 
#   Run_Backup.sh will be called from the Cron Jobs 
#   This script will list all local databases running in the instance on a node.  It will call the
#   DB2_Backup.sh script to run a backup for each running database.
#   Variables are set at the top of the DB2_Backup.sh script to determine if a full backup needs to be run
#   based on the day of the week.  Currently, Saturday is when the full backup runs, incremental backups run
#   every all other days.
#
#    Variables to be set
#   SLACKURL = The channel were notifications are send
#   BACKUP_SCRIPT =  The backup script that Run_Backup.sh calls
#   DAYOFFULL = Defines the day of the week that the full backup will on on (must match the same format as the output from `date`)
#   NUMOFBKUPTOKEEP = This defines the number of days to keep a backup image on local disk
#
#    Variables determined by the environment
#   BKPTYPE = Is determined from the `date` command and the DAYOFFULL value
#   DB2INSTANCE = Pulled from the environment
#   HOSTNAME
#   DBNAME = Pulled from the `db2 list db directory`
#   
#    Backup command issued
#   ./DB2_Backup.sh ${DB2INSTANCE} ${DBNAME} ${NUMOFBKUPTOKEEP} ${BKPTYPE} 2>>.BackupLOG.stderr > .BackupLOG.out
#
# -- Revision of script to include new ICD URL
#########################################################

# -- Source the Props File
. /mnt/backup/bin/.PROPS

# -- Standard Parameters
DBINSTANCE=`whoami`
HOSTNAME=`hostname`
DATETIME=`date +%Y-%m-%d_%H%M%S`;
DOW=`date |  awk '{print $1}'`

# -- Verify and source db2profile 

if [[ ! -f "${HOME}/sqllib/db2profile" ]]; then
   echo "ERROR - ${HOME}/sqllib/db2profile not found"
   EXIT_STATUS=1
else
   . ${HOME}/sqllib/db2profile
fi

# -- Debug Mode 
set -x

# -- Backup Parameters
INSTANCE_HOME=`/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | grep "${DBINSTANCE}" | awk -F ',' '{print $5}'| cut -d/ -f 1,2,3,4,5`
SCRIPT_DIR=${INSTANCE_HOME}/bin
BACKUP_SCRIPT="${SCRIPT_DIR}/DB2_Backup.sh"
CUSTNAME=`hostname | sed 's/c-db2wh-//; s/c-//; s/-db2u-0//; s/db2u/-/; s/-manage//;' | tr '[:lower:]' '[:upper:]'`
BUCKET_ALIAS=`db2 list storage access | grep ${CONTAINER} -B4 | grep ALIAS | awk -F '=' '{print $2}'`
HSTYPE="Backup"
ICD_LOG=${SCRIPT_DIR}/.Maillive.log

# -- Valid only for MAS-CP4D customers 
if (( ${CUSTNAME} )) ; then 
   CUSTNAME=`echo ${CONTAINER} | awk -F '-backup-' '{print $2}'  | awk -F '-pr-' '{print $1}' | tr '[:lower:]' '[:upper:]'`
fi 

# -- Database Environment 
if [[ ${BUCKET_ALIAS} == "IBMCOS" ]]; then 
	DBENV="MAS MS"
else
	DBENV="MAS SaaS"
fi

# -- Create ICD Incident , If Backup fails 

CREATE_ICD() {
	HTYPE=`echo ${HSTYPE} | tr '[:lower:]' '[:upper:]'`
	DES="$1"
	echo "############################" >> ${ICD_LOG}
	LONGDES=`cat ${ICD_LOG} | sed 's/"//g' | sed "s/'//g"`
	LONGDES=`echo "<pre> ${LONGDES} </pre>"`

   # -- Verify the ICD URL Status 
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
         "reportedpriority":4,
         "internalpriority":4,
         "reportedby":"DB2",
         "affectedperson":"${DBENV}",
         "ownergroup":"HSDBA",
         "description_longdescription":"${LONGDES}",
         "siteid":"001",
         "classstructureid":"1341",
         "classificationid":"IN-DBPERF",
         "hshost":"${HOSTNAME}",
         "hstype":"${HTYPE}"
      }'
!
   /bin/bash .curl_${DBNAME}_ICD.sh > .curl_${DBNAME}_ICD.out 2>&1

}

# -- Verify the day of the week
if [[ ${DOW} = ${DAYOFFULL} ]] ; then
   BKPTYPE="FULL"
else 
   BKPTYPE="DIFF"
fi

# -- Loop through the available databases in the instance 

DBS=`db2 list db directory | grep -B5 "Indirect" | grep "Database name" |  awk '{ print $4 }'`
for DBNAME in ${DBS}
do
   cd ${SCRIPT_DIR}
   ${BACKUP_SCRIPT} ${DB2INSTANCE} ${DBNAME} ${NUMOFBKUPTOKEEP} ${BKPTYPE} 2>.BackupLOG.stderr > .BackupLOG.out
   RC=$?
   if [[ ${RC} -ne 0 ]]; then
      LONGDES="Failure to start the Backup job ${DATETIME} CUST=${CUSTNAME} ${RC}"
      # -- Send Failure notification to a slack channel
      cat << ! >.curl_${DBNAME}_RUN.sh
         curl -X POST -H 'Content-type: application/json' --data '{"text":"$LONGDES"}' ${SLACKURL}
!
      /bin/bash .curl_${DBNAME}_RUN.sh > .curl_${DBNAME}_RUN.out 2>&1

      # -- Create ICD ticket if fails  
      DES="${CUSTNAME} - ${DBENV} - ${DBNAME} - ${HOSTNAME} -- Failed to Start Backup!! "
      CREATE_ICD "${DES}"
   fi   

   # -- Execute Online Reorgs for qualified tables and indexes after every Full Backup
   if [[ ${DOW} = ${DAYOFFULL} ]] ; then
      /bin/bash ${SCRIPT_DIR}/reorgTablesIndexesInplace.sh -db ${DBNAME} -s MAXIMO -tb_stats -ix_stats -window 120 -tr > ${HOME}/maintenance/logs/reorgTablesIndexesInplace_${DATETIME}.log 2>&1
   fi

done

# -- Exeucte Runstats and Rebind for all tables daily 
/bin/bash ${SCRIPT_DIR}/runstats_rebind.sh >${SCRIPT_DIR}/.runstats_rebind.out 2>&1
#/bin/bash ${SCRIPT_DIR}/grant_check.sh bludb >${SCRIPT_DIR}/.grant_check.out 2>&1

# -- END OF SCRIPT
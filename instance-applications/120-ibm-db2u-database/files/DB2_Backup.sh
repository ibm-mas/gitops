#!/bin/ksh
#########################################################
#   DB2_Backup.sh 
#
#   Things to do:
#      Recovery history retention (days) (REC_HIS_RETENTN) = 0  >>> Need to set to 15 days   
#
#   The cron job on the cluster will supply the needed parameters for this script
#   If an on demand backup (Full) is required, the DB2_Backup.sh script can be called with the following parameters
#
#   Sample parameters
#  ./DB2_Backup.sh <instance name> <DB name> <# of backups to keep on file system> <full or incremntal>
#  ./DB2_Backup.sh ctginst1 BLUDB 15 full 2>>.BackupLOG.stderr > .BackupLOG.out  
#  ./DB2_Backup.sh ctginst1 BLUDB 15 inc 2>>.BackupLOG.stderr > .BackupLOG.out
#
#########################################################

# -- Script Usage 
if [[ $# -eq 4 ]]; then
   typeset -l dbinstance=$1 dbname=$2
   typeset -u DBINSTANCE=$1 DBNAME=$2
   typeset -i NUM_BACKUPS_TO_KEEP=$3
   typeset -l BKUP_TYPE=$4 
else
   print $(tput smso) "Usage! $0 dbinstance database number_of_backups_to_keep" $(tput rmso)
   exit 1
fi


# -- Default Parameters
HOSTNAME=$(hostname -a)
HOSTADDR=$(/sbin/ifconfig | grep "inet" | grep broadcast | awk '{print $2}') 
INSTNAME=$(/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | awk -F, '{print $4}' )
INSTHOME=$(/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | grep "${INSTNAME}" | awk -F ',' '{print $5}'| sed 's/\/sqllib//' )
NAMESPACE=$(hostname -A | awk -F '.' '{print $3}')
DATETIME=$(date +'%F_%T')

# -- Initialising Logs 
SCRIPTDIR=${INSTHOME}/bin                                    # -- Script Path
SCRIPTNAM="l$(basename "$0" | awk -F '.' '{print $1}')"      # -- Script Name
LOGFILE=${SCRIPTDIR}/.${SCRIPTNAM}.log                       # -- Script Log
ICDLOG=${SCRIPTDIR}/.${SCRIPTNAM}_ICD.log                    # -- Log for ICD
LOCKFILE=${SCRIPTDIR}/.${SCRIPTNAM}.lock                     # -- Lock file 
HSTYPE='Backup'

# ===========================================================================
# Invoking DB2 Profile 
# ===========================================================================

if [[ ! -f "${INSTHOME}/sqllib/db2profile" ]]; then
   echo "ERROR - ${INSTHOME}/sqllib/db2profile not found"
   EXIT_STATUS=1
else
   . ${INSTHOME}/sqllib/db2profile
fi

# ===========================================================================
# Invoking PROPS Profile 
# ===========================================================================

if [[ "${INSTHOME}" =~ "blumeta" ]]; then 
   . /mnt/backup/bin/.PROPS
else
   . ${INSTHOME}/bin/.PROPS
fi

# -- Backup Parameters 
#COSBACKUPBUCKET="${CONTAINER}"
BUCKET_ALIAS=$(db2 list storage access | grep ${CONTAINER} -B4 | grep ALIAS | awk -F '=' '{print $2}' | sort -u | egrep -m 1 "AWSCOS|IBMCOS")
BACKUP_BASE="/mnt/backup/"
BACKUP_LOGS=${SCRIPTDIR}/${INSTNAME}
#BACKUP_PATH=DB2REMOTE://${BUCKET_ALIAS}/${CONTAINER}/backups-${APPENV}/${HOSTNAME}
BACKUP_PATH=/mnt/backup/BKP/
CLEAN_LOG=${BACKUP_LOGS}/.cleanup.LOG
BKP_LOG=${SCRIPTDIR}/.${DBNAME}_BackupLOG.log
BKP_AUDIT_LOG=${BACKUP_LOGS}/.BackupLOG
BKP_HIS_LOG=${BACKUP_LOGS}/backhist
HSTYPE="Backup"

# ===========================================================================
# Debug Options
# ===========================================================================

 set -x;       # Uncomment to debug this shell script
# set -n;       # Uncomment to check your syntax, without execution.

#===========================================================================
# Functions
#===========================================================================

# -- Initialising variables
function initParms {

   # -- Declaring the Db environment 
   if [[ "${INSTNAME}" == "ctginst1" ]]; then
        DBENV="FLEX"
        CUSTNAME=$(hostname -a | awk '{print $2}' | cut -d '-' -f '1,2' | tr '[:lower:]' '[:upper:]')
   else
         if [[ "${CONTAINER}" =~ "massaas" ]]; then 
            DBENV="MASSAAS"
            ASSETNUM="10000-MASSAAS"
         else
            DBENV="MASMS"
            ASSETNUM="10000-MASMS"
         fi 
           
         # -- Generate Customer name 
         if [[ "${NAMESPACE}" == "mas-cp4d" || "${NAMESPACE}" == "mas-cpd" ]] ; then  
            CUSTNAME=$(echo ${CONTAINER} | awk -F '-backup-' '{print $2}'  | awk -F '-pr-' '{print $1}' | tr '[:lower:]' '[:upper:]')
         else
            CUSTNAME=$(hostname | sed 's/c-db2wh-//; s/c-db2u-//; s/c-//; s/-db2u-0//; s/db2u/-/; ' | tr '[:lower:]' '[:upper:]' )
         fi 

   fi 
   # -- HSHOST name for MASMS/SaaS
   NS=$(echo ${NAMESPACE} | sed 's/mas-//; s/-core//; s/-manage//; s/-facilities//; s/-db2u//;');

   if [[ "${NAMESPACE}" =~ "manage" ]] ; then 
      HSHOST="main.manage.${NS}.suite"
   elif [[ "${NAMESPACE}" =~ "core" ]]; then
      HSHOST="main.home.${NS}.suite"
   elif [[ "${NAMESPACE}" =~ "monitor" ]]; then
      HSHOST="main.monitor.${NS}.suite"
   elif [[ "${NAMESPACE}" =~ "facilities" ]]; then
      HSHOST="main.facilities.${NS}.suite"
   fi
}

# -- Function to send Slack notification  

SLACK_NOTIFY() {

   SLACKDES="$1"      
   # -- Send Failure notification to a slack channel
   cat << ! >.curl_${DBNAME}_slack.sh
      curl -X POST -H 'Content-type: application/json' --data '{"text":"${SLACKDES}"}' ${SLACKURL}
!
   /bin/bash .curl_${DBNAME}_slack.sh > .curl_${DBNAME}_slack.out 2>&1
}

# -- Create ICD Incident , If Backup fails 

CREATE_ICD() {
   #HSTYPE=$(echo ${HSTYPE} | tr '[:lower:]' '[:upper:]')
   DES="$1"
   LONGDES=$(cat ${ICDLOG} | sed 's/"//g' | sed "s/'//g")
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
         "hstype":"${HSTYPE}",
         "hshost":"${HSHOST}",
         "hshostname":"${HSHOST}"
      }'
!
   /bin/bash .curl_${DBNAME}_ICD.sh > .curl_${DBNAME}_ICD.out 2>&1

}

# -- Delete old log file
if [[ -f ${ICDLOG} ]]; then
   rm ${ICDLOG}
fi

# -- Create the backup log directory if it doesnt exists
if [[ ! -d ${BACKUP_LOGS} ]]; then
   mkdir -m 755 ${BACKUP_LOGS}
fi

# -- Setting backup type 
if [[ "${BKUP_TYPE}" == "full" ]]; then 
   BKPTYPE="FULL"
else 
   BKPTYPE="DIFF"
fi

#===========================================================================
# Script Execution starts from here 
#===========================================================================

# -- Function call to initilise the env parameters
initParms

ln=80
printf "%${ln}s\n" | tr ' ' '-'                             | tee    ${BKP_LOG} 
printf "%-25s %s\n" "Script Start Time" ":: ${DATETIME}"    | tee -a ${BKP_LOG} 
printf "%-25s %s\n" "Hostname"          ":: ${HOSTNAME}"    | tee -a ${BKP_LOG} 
printf "%-25s %s\n" "HostIP"            ":: ${HOSTADDR}"    | tee -a ${BKP_LOG} 
printf "%-25s %s\n" "Namespace"         ":: ${NAMESPACE}"   | tee -a ${BKP_LOG} 
printf "%-25s %s\n" "Database Name"     ":: ${DBNAME}"      | tee -a ${BKP_LOG} 
printf "%-25s %s\n" "Backup Type"       ":: ${BKPTYPE}"     | tee -a ${BKP_LOG} 
printf "%-25s %s\n" "COS Bucket"        ":: ${CONTAINER}"   | tee -a ${BKP_LOG} 
printf "\n%${ln}s\n" | tr ' ' '-'                           | tee -a ${BKP_LOG} 


# -- Check for the existance of /home/ctginst1/sqllib/db2dump/libdb2compr.so...if it exists, delete it
COMPRESS_LOC=${INSTHOME}/sqllib/db2dump/libdb2compr.so
if [[ -f ${COMPRESS_LOC} ]]; then
   rm ${COMPRESS_LOC}
fi
      
# -- Check to see if the Instance is up and Running
ps -ef | grep db2sysc | grep -v grep  > /dev/null 2>&1
if [[ $? -eq 1 ]]; then
   cat ${BKP_LOG} > ${ICDLOG}
   echo "${HOSTNAME}, Instance is not Active, Backup cannot Run!!!" | tee ${INSTHOME}/bin/LASTbkupRUN | tee -a ${BKP_LOG} ${ICDLOG} > /dev/null 2>&1

   SLACKDES="${CUSTNAME} - ${DBENV} - ${HOSTNAME}, Instance is not Active, Backup cannot Initiate !! " 
   DES="${CUSTNAME} - ${DBENV} - ${DBNAME} - ${HOSTNAME} -- Instance is not Active, Backup cannot Initiate !! "

   # -- Send error notification to Slack 
   #SLACK_NOTIFY "${SLACKDES}"

   # -- Create ICD ticket if fails  
   CREATE_ICD "${DES}"

   # -- End the script execution 
   exit
fi

# -- Verify whether Database is Standby
db2pd -hadr -db ${DBNAME} | awk -F= '/HADR_ROLE/ {print $2}' | grep STANDBY > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo "This is a HADR Database" | tee -a ${BKP_LOG} 
    echo "Backup successful. The timestamp for this backup image is : HADR_DB" | tee -a ${BKP_LOG}  
    echo "${HOSTNAME}, HADR, NO BACKUPS" > ${INSTHOME}/bin/LASTbkupRUN 2>&1
    exit 0
fi
      
# -- Archive the logs for Database      
db2 -v "ARCHIVE LOG FOR DB ${DBNAME}" | tee -a ${BKP_LOG} 
sleep 20

# -- Starting backup for the database
if [[ ${NUM_BACKUPS_TO_KEEP} -gt 0 ]]; then

   if [[ "${BKUP_TYPE}" == "full" ]]; then
      db2 -v "BACKUP DB ${DBNAME} ONLINE TO ${BACKUP_PATH} COMPRESS UTIL_IMPACT_PRIORITY 50 INCLUDE LOGS WITHOUT PROMPTING" | tee -a ${BKP_LOG} 
   else 
      db2 -v "BACKUP DB ${DBNAME} ONLINE INCREMENTAL DELTA TO ${BACKUP_PATH} COMPRESS UTIL_IMPACT_PRIORITY 50 INCLUDE LOGS WITHOUT PROMPTING" | tee -a ${BKP_LOG} 
   fi   

   grep -Fq "Backup successful." ${BKP_LOG}
   if [[ $? -ne 0 ]]; then 
      cat ${BKP_LOG} > ${ICDLOG}

      SLACKDES="${CUSTNAME} - ${DBENV} - ${HOSTNAME} -- ${BKPTYPE} ${HSTYPE} Failed . . . Please investigate ! ! ! "
      DES="${CUSTNAME} - ${DBENV} - ${DBNAME} - ${HOSTNAME} -- ${BKPTYPE} ${HSTYPE} Failed !"

      # -- Send error notification to Slack 
      #SLACK_NOTIFY "${SLACKDES}"
      # -- Create ICD ticket if fails  
      CREATE_ICD "${DES}"
   fi
fi

# -- Copy keystore to COS
DBKEYSTORE=$(db2 get dbm cfg | grep KEYSTORE_LOCATION | awk -F '= ' '{ print $2}' )
if [[ ! -z ${DBKEYSTORE} ]]; then 

    KEYSTORE_LOCATION=$(echo ${DBKEYSTORE} | sed 's#/[^/]*$##' )
    KEYSTORE_NAME=$(echo ${DBKEYSTORE} | awk -F'/' '{sub(/\.[^.]*$/, "", $NF); print $NF}')
    
    SOURCE1=${KEYSTORE_LOCATION}/${KEYSTORE_NAME}.p12
    SOURCE2=${KEYSTORE_LOCATION}/${KEYSTORE_NAME}.sth
    TARGET1=backups-${APPENV}/${HOSTNAME}/KEYSTORE/${KEYSTORE_NAME}.p12
    TARGET2=backups-${APPENV}/${HOSTNAME}/KEYSTORE/${KEYSTORE_NAME}.sth

    DB2V=$(db2level | grep Inform | awk '{print $5}' | sed 's/",//')
    if [[ "${DB2V}" == "v11.5.7.0" ]]; then

        db2RemStgManager S3 put server=${HOSTNAME} auth1=${PARM1} auth2=${PARM2} container=${CONTAINER} source=${SOURCE1} target=${TARGET1}
        db2RemStgManager S3 put server=${HOSTNAME} auth1=${PARM1} auth2=${PARM2} container=${CONTAINER} source=${SOURCE2} target=${TARGET2}

    else
        db2RemStgManager ALIAS PUT source=${SOURCE1} target=DB2REMOTE://${BUCKET_ALIAS}//${TARGET1}
        db2RemStgManager ALIAS PUT source=${SOURCE2} target=DB2REMOTE://${BUCKET_ALIAS}//${TARGET2}
    fi

fi

# -- Exclude files that arent backups, e.g. backhist listing.   

typeset -i NO_BACKUPS=$(~/bin/CheckCOS.sh | grep -i ${DBNAME} | cut -d/ -f3 | grep 001 | wc -l)
echo "Number of Backups in the bucket :: ${NO_BACKUPS}" | tee -a ${BKP_LOG} 

# -- Prune the history file, if and only if the last backup succeeded.
   
if [[ ${NUM_BACKUPS_TO_KEEP} -gt 0 && ${NO_BACKUPS} -ge ${NUM_BACKUPS_TO_KEEP} ]]; then
   db2 -v CONNECT TO ${DBNAME} > /dev/null 2>&1

   TIMESTMP=$(db2 -x "select coalesce(max(start), 17890713235959) from \
                (select bigint(start_time) - 1 as start, \
                row_number() over(order by start_time desc) as backup \
                from   sysibmadm.db_history              \
                where  operation = 'B'                   \
                and    objecttype = 'D'                  \
                and    devicetype = 'D'                  \
                and    sqlcode is null                   \
                and    sqlwarn is null                   \
                ) as zzz                                 \
                where backup = ${NUM_BACKUPS_TO_KEEP}" | tr -d ' ' ) 

   db2 -v "PRUNE HISTORY ${TIMESTMP} WITH FORCE OPTION AND DELETE" | tee -a ${BKP_LOG}

   # -- Loop until the recovery history file is stable and then report it
   RC=999
   typeset -i no_loops=0
   while [[ $RC -gt 0 ]]
   do
      db2 -v list history backup since ${TIMESTMP} for ${DBNAME} > ${BKP_HIS_LOG}
      RC=$?
      #print RC for list history was $RC 
      #cat ${BKP_HIS_LOG} >> ${BKP_LOG}  2>&1
      if [[ $no_loops -gt 720 ]]; then
         # -- then youve been waiting an hour
         print $0 "Im tired of waiting for the recovery history file to stabilise. Im giving up" | tee -a ${BKP_LOG}
         break
      else
         sleep 5
         let no_loops=no_loops+1
      fi
   done
   
   #echo "Content of backhist file: " 
   #cat ${BKP_HIS_LOG}
   db2 -v commit          > /dev/null 2>&1
   db2 -v connect reset   > /dev/null 2>&1
   db2 -v terminate       > /dev/null 2>&1
else
   TIMESTMP=$(date -d '7 days ago' +"%Y%m%d")
   db2 -v list history backup since ${TIMESTMP} for ${DBNAME} > ${BKP_HIS_LOG}
fi

sleep 20

# -- Prune the archive logs and archive log history file
if [[ ${NUM_BACKUPS_TO_KEEP} -eq 0 ]]; then
   db2 -v connect to ${DBNAME} > /dev/null 2>&1
   db2 -x "select location from sysibmadm.db_history where operation = 'X' and operationtype = '1' " > ${BACKUP_LOGS}/archivelog.zaplist

   for LOG in $(cat ${BACKUP_LOGS}/archivelog.zaplist)
   do
      printf "$(date +'%F %T')\t%-110s\t%12d k\n" "${LOG}" "$(du -sk ${LOG} | awk '{print $1}')" >> ${CLEAN_LOG}
   done

   # --  Prune history of archive log
   TIMESTMP=$(db2 -x "select max(start_time) from sysibmadm.db_history where operation = 'X' and operationtype = '1'" | tr -d ' ')
   db2 -v PRUNE HISTORY ${TIMESTMP} WITH FORCE OPTION AND DELETE | tee -a ${BKP_LOG}
   wait
   db2 -v commit          > /dev/null 2>&1
   db2 -v connect reset   > /dev/null 2>&1
   db2 -v terminate       > /dev/null 2>&1

fi

# --  Copy the current backup Log to the Backup history log file    
cat ${BKP_LOG} >> ${BKP_AUDIT_LOG} 2>&1
cat ${BKP_HIS_LOG} >> ${BKP_AUDIT_LOG} 2>&1

DATETIME=$(date +'%F_%T');
printf "%-25s %s\n" "Script End Time" ":: ${DATETIME}"  | tee -a ${BKP_LOG} ${BKP_AUDIT_LOG}

# -- END OF SCRIPT
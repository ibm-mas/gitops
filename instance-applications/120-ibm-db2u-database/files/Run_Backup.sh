#!/bin/bash
#set -x

#########################################################
#                Run_Backup.sh 
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
#   BACKUPTYPE = Is determined from the `date` command and the DAYOFFULL value
#   DB2INSTANCE = Pulled from the environment
#   HOSTNAME
#   DBNAME = Pulled from the `db2 list db directory`
#   
#    Backup command issued
#   ./DB2_Backup.sh ${DB2INSTANCE} ${DBNAME} ${NUMOFBKUPTOKEEP} ${BACKUPTYPE} 2>>.BackupLOG.stderr > .BackupLOG.out
#########################################################

. /mnt/backup/bin/.PROPS

DBINSTANCE=`whoami`
HOSTNAME=`hostname`
BACKUP_DIR=${HOME}/bin
BACKUP_SCRIPT=DB2_Backup.sh
DATETIME=`date +%Y-%m-%d_%H%M%S`;

if [ ! -f "${HOME}/sqllib/db2profile" ]
then
   echo "ERROR - ${HOME}/sqllib/db2profile not found"
   EXIT_STATUS=1
else
   . ${HOME}/sqllib/db2profile
fi


DOW=`date |  awk '{print $1}'`

 if [ ${DOW} = ${DAYOFFULL} ] ; then
   BACKUPTYPE=full
 else 
    BACKUPTYPE=inc
 fi

DBS=`db2 list db directory | grep -B5 "Indirect" | grep "Database name" |  awk '{ print $4 }'`
for DBNAME in ${DBS}
do
 cd ${BACKUP_DIR}
 ./DB2_Backup.sh ${DB2INSTANCE} ${DBNAME} ${NUMOFBKUPTOKEEP} ${BACKUPTYPE} 2>.BackupLOG.stderr > .BackupLOG.out

 RC=$?
 if [ ${RC} -ne 0 ]; then

   longdes="Failure to start the Backup job ${DATETIME} CUST=${CUSTNAME}      ${RC}"
  ##  Send Failure notification to a slack channel  ##
  cat << ! >.curl_${DBNAME}_RUN.sh
  curl -X POST -H 'Content-type: application/json' --data '{"text":"$longdes"}' $SLACKURL
!
/bin/bash .curl_${DBNAME}_RUN.sh > .curl_${DBNAME}_RUN.out 2>&1

  #####   Create ICD Incident  ####
  #######   If Backup fails  ###
   des="${DBINSTANCE} - Backup - ${HOSTNAME} ${DBNAME} ${CUSTNAME} - MASMS -- Backup Failed"
   echo "TESTING $instance - Backup - $ ${DBNAME}  - Backup Failed" > .Maillive.log
   echo "############################"             >> .Maillive.log
   #cat  $BACK_LOG                   >> .Maillive.log
   longdes=`cat .Maillive.log | sed 's/"//g' | sed "s/'//g"`
   ICD_URL="https://servicedesk.mro.com"
   if ! curl -k -s --connect-timeout 3 ${ICD_URL} >/dev/null; then
       ICD_URL="https://servicedesk.cds.mro.com"
   fi

cat << ! >.curl_${DBNAME}_ICD.sh
  curl --insecure --location --request POST "${ICD_URL}/maximo_mif/oslc/os/hsincident?lean=1" \
  --header 'Authorization: Basic Y2RzaW50ZGJhOklSZWFsbHlMb3ZlUHVwcGllcw==' \
  --header 'Content-Type: application/json' \
  --data '{
  "description":"$des",
  "reportedpriority":4,
  "internalpriority":4,
  "reportedby":"DB2",
  "affectedperson":"CTGINST1",
  "description_longdescription":"$longdes",
  "siteid":"001",
  "classstructureid":"1341",
  "classificationid":"IN-DBPERF",
  "hshost":"{servicedesk-pdb-sjc03-2.cds.mro.com:0:50}",
  "hstype":"BACKUP"
  }'
!
/bin/bash .curl_${DBNAME}_ICD.sh > .curl_${DBNAME}_ICD.out 2>&1

fi   
done
/bin/bash ${HOME}/bin/runstats_rebind.sh  >${HOME}/bin/.runstats_rebind.out 2>&1
/bin/bash ${HOME}/bin/grant_check.sh bludb  >${HOME}/bin/.grant_check.out 2>&1

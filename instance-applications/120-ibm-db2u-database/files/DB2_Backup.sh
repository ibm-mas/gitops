#!/bin/ksh
#set -x

#########################################################
#	DB2_Backup.sh 
#
#	Things to do:
#		Recovery history retention (days) (REC_HIS_RETENTN) = 0  >>> Need to set to 15 days	
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
   typeset -l instance=$1 dbname=$2
   typeset -u INSTANCE=$1 DBNAME=$2
   typeset -i NUM_BACKUPS_TO_KEEP=$3
   typeset -l BKUP_TYPE=$4 

else
   print `tput smso` "Usage! $0 instance database number_of_backups_to_keep" `tput rmso`
   exit 1
fi

# -- Standard Parameters 
HOSTNAME=`hostname`
NAMESPACE=`hostname -A | awk -F '.' '{print $3}'`
DBINSTANCE=`whoami`
DATETIME=`date +'%F_%T'`;
INSTANCE_HOME=`/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | grep "${DBINSTANCE}" | awk -F ',' '{print $5}'| cut -d/ -f 1,2,3,4,5`
IP=`/sbin/ifconfig  | grep "inet" | grep broadcast | awk '{print $2}'`
CUSTNAME=`hostname | sed 's/c-db2wh-//; s/c-//; s/-db2u-0//; s/db2u/-/; s/-manage//;' | tr '[:lower:]' '[:upper:]'`
SCRIPT_DIR=${INSTANCE_HOME}/bin

# -- Source DB2 Profile

if [[ ! -f "${INSTANCE_HOME}/sqllib/db2profile" ]]; then
   echo "ERROR - ${INSTANCE_HOME}/sqllib/db2profile not found"
   EXIT_STATUS=1
else
   . ${INSTANCE_HOME}/sqllib/db2profile
fi

set -x 
# -- Source the PROPS file 		
. /mnt/backup/bin/.PROPS

# -- Backup Parameters 

COSBACKUPBUCKET="${CONTAINER}"
BUCKET_ALIAS=`db2 list storage access | grep ${COSBACKUPBUCKET} -B4 | grep ALIAS | awk -F '=' '{print $2}'`
BACKUP_BASE="/mnt/backup"
BACKUP_LOGS=${SCRIPT_DIR}/${DBINSTANCE}
BACKUP_PATH=DB2REMOTE://${BUCKET_ALIAS}/${COSBACKUPBUCKET}/backups-${APPENV}/${HOSTNAME}
ARCBKP_PATH=${BACKUP_LOGS}/${DATETIME}
CLEAN_LOG=${BACKUP_LOGS}/.cleanup.LOG
Maillog="/tmp/.backup_maillog"
BACK_LOG=${SCRIPT_DIR}/.${DBNAME}_BackupLOG.out
ICD_LOG=${SCRIPT_DIR}/.Maillive.log
HSTYPE="Backup"

# -- Valid only for MAS-CP4D Customers 
if (( ${CUSTNAME} )) ; then 
   CUSTNAME=`echo ${CONTAINER} | awk -F '-backup-' '{print $2}'  | awk -F '-pr-' '{print $1}' | tr '[:lower:]' '[:upper:]'`
fi 

# -- Database Environment 
if [[ ${BUCKET_ALIAS} == "IBMCOS" ]]; then 
	DBENV="MASMS"
else
	DBENV="MAS_SaaS"
fi

# -- Function to send Slack notification  

SLACK_NOTIFY() {

	SLACKDES="$1"		
	# -- Send Failure notification to a slack channel
	cat << ! >.curl_${DBNAME}.sh
		curl -X POST -H 'Content-type: application/json' --data '{"text":"${SLACKDES}"}' ${SLACKURL}
!
	/bin/bash .curl_${DBNAME}.sh > .curl_${DBNAME}.out 2>&1

}

# -- Create ICD Incident , If Backup fails 

CREATE_ICD() {
	HTYPE=`echo ${HSTYPE} | tr '[:lower:]' '[:upper:]'`
	DES="$1"
	echo "############################" >> ${ICD_LOG}
	LONGDES=`cat ${ICD_LOG} | sed 's/"//g' | sed "s/'//g"`
	LONGDES=`echo "<pre> ${LONGDES} </pre>"`

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

# -- Delete old log file
if [[ -f $Maillog ]]; then
    rm $Maillog
fi

# -- Create the backup log directory if it doesnt exists
if [[ ! -d ${BACKUP_LOGS} ]]; then
	mkdir -m 755 ${BACKUP_LOGS}
fi

# -- Setting backup type 
if [[ ${BKUP_TYPE} == 'full' ]]; then 
    BKPTYPE="FULL"
else 
    BKPTYPE="DIFF"
fi

# -- Script Execution starts from here 

echo -e "\n-------------------------------------"       | tee ${BACK_LOG}
echo -e "Backup Start Time \t :: ${DATETIME}"           | tee -a ${BACK_LOG}
echo -e "COS Bucket \t\t :: ${COSBACKUPBUCKET}"         | tee -a ${BACK_LOG}
echo -e "\nHostname \t\t :: ${HOSTNAME}"                | tee -a ${BACK_LOG}
echo -e "Namespace \t\t :: ${NAMESPACE}"                | tee -a ${BACK_LOG}
echo -e "HostIP \t\t\t :: ${IP}"                        | tee -a ${BACK_LOG}
echo -e "-------------------------------------\n"       | tee -a ${BACK_LOG}

# -- Check for the existance of /home/ctginst1/sqllib/db2dump/libdb2compr.so...if it exists, delete it
COMPRESS_LOC=${INSTANCE_HOME}/sqllib/db2dump/libdb2compr.so
if [[ -f ${COMPRESS_LOC} ]]; then
	rm ${COMPRESS_LOC}
fi
		
# -- Check to see if the Instance is up and Running
ps -ef | grep db2sysc | grep -v grep  > /dev/null 2>&1
if [[ $? -eq 1 ]]; then
	echo "Instance is not active "      
	echo "${HOSTNAME}, Instance is not Active, BACKUP cannot Run!" | tee ${INSTANCE_HOME}/bin/LASTbkupRUN ${ICD_LOG} >/dev/null
	echo "############################"     >> ${ICD_LOG}
	cat ${BACK_LOG}                         >> ${ICD_LOG}

	SLACKDES="${CUSTNAME} - ${DBENV} - ${HOSTNAME}, Instance is not Active, Backup cannot Run! " 
    DES="${CUSTNAME} - ${DBENV} - ${DBNAME} - ${HOSTNAME} -- Instance is not Active,  Backup cannot Run!! "

	# -- Send error notification to Slack 
	SLACK_NOTIFY "${SLACKDES}"

	# -- Create ICD ticket if fails  
	CREATE_ICD "${DES}"

	# -- End the script execution 
	exit
fi

# -- Verify whether Database is Standby
db2pd -hadr -db ${DBNAME} | awk -F= '/HADR_ROLE/ {print $2}' | grep STANDBY > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo "This is a HADR Database"      
    echo "Backup successful. The timestamp for this backup image is : HADR_DB"      
    echo "${HOSTNAME}, HADR, NO BACKUPS" > ${INSTANCE_HOME}/bin/LASTbkupRUN
    exit 0
fi
		
# -- Archive the logs for Database		
db2 -v "ARCHIVE LOG FOR DB ${DBNAME}" | tee -a ${BACK_LOG}
sleep 20

# -- Starting backup for the database
if [[ ${NUM_BACKUPS_TO_KEEP} -gt 0 ]]; then

	if [[ ${BKUP_TYPE} = 'full' ]]; then
	   db2 -v "BACKUP DB ${DBNAME} ONLINE TO ${BACKUP_PATH} COMPRESS UTIL_IMPACT_PRIORITY 50 INCLUDE LOGS WITHOUT PROMPTING" | tee -a ${BACK_LOG}
	else 
	   db2 -v "BACKUP DB ${DBNAME} ONLINE INCREMENTAL DELTA TO ${BACKUP_PATH} COMPRESS UTIL_IMPACT_PRIORITY 50 INCLUDE LOGS WITHOUT PROMPTING" | tee -a ${BACK_LOG}
	fi   

	grep -Fq "Backup successful." ${BACK_LOG}
	if [[ $? -ne 0 ]]; then 
		echo "${CUSTNAME} - ${DBENV} - ${HOSTNAME}, ${BKPTYPE} DB Backup Failed ! Database Backup issues !!!" > ${ICD_LOG}
		echo "############################"     >> ${ICD_LOG}
		cat ${BACK_LOG}                         >> ${ICD_LOG}

		SLACKDES="${CUSTNAME} - ${DBENV} - ${HOSTNAME}, ${BKPTYPE} DB Backup Failed . . . Please investigate ! ! ! "
   		DES="${CUSTNAME} - ${DBENV} - ${DBNAME} - ${HOSTNAME} -- ${BKPTYPE} ${HSTYPE} Failed !"

		# -- Send error notification to Slack 
		SLACK_NOTIFY "${SLACKDES}"
		# -- Create ICD ticket if fails  
		CREATE_ICD "${DES}"
	fi
fi

# -- Copy keystore to COS
SOURCE1=/mnt/blumeta0/db2/keystore/keystore.p12
SOURCE2=/mnt/blumeta0/db2/keystore/keystore.sth
TARGET1=backups-${APPENV}/${HOSTNAME}/KEYSTORE/keystore.p12
TARGET2=backups-${APPENV}/${HOSTNAME}/KEYSTORE/keystore.sth

DB2V=`db2level | grep Inform | awk '{print $5}' | sed 's/",//'`
if [[ ${DB2V} == "v11.5.7.0" ]]; then

	db2RemStgManager S3 put server=${HOSTNAME} auth1=${PARM1} auth2=${PARM2} container=${CONTAINER} source=${SOURCE1} target=${TARGET1}
	db2RemStgManager S3 put server=${HOSTNAME} auth1=${PARM1} auth2=${PARM2} container=${CONTAINER} source=${SOURCE2} target=${TARGET2}

else
	db2RemStgManager ALIAS PUT source=${SOURCE1} target=DB2REMOTE://${BUCKET_ALIAS}//${TARGET1}
	db2RemStgManager ALIAS PUT source=${SOURCE2} target=DB2REMOTE://${BUCKET_ALIAS}//${TARGET2}
fi

# -- Exclude files that arent backups, e.g. backhist listing.	

typeset -i NO_BACKUPS=`~/bin/CheckCOS.sh | grep -i ${DBNAME} | cut -d/ -f3 | grep 001 | wc -l`
echo "Number of Backups in the bucket :: ${NO_BACKUPS}"

# -- Prune the history file, if and only if the last backup succeeded.
	
if [[ ${NUM_BACKUPS_TO_KEEP} -gt 0 && ${NO_BACKUPS} -ge ${NUM_BACKUPS_TO_KEEP} ]]; then
	db2 -v CONNECT TO ${DBNAME} | tee -a ${BACK_LOG}

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
		                where backup = ${NUM_BACKUPS_TO_KEEP}" )

	db2 -v "PRUNE HISTORY ${TIMESTMP} WITH FORCE OPTION AND DELETE" | tee -a ${BACK_LOG}

	# -- Loop until the recovery history file is stable and then report it
	RC=999
	typeset -i no_loops=0
	while [[ $RC -gt 0 ]]
	do
		db2 -v list history backup since ${TIMESTMP} for ${DBNAME} > ${BACKUP_LOGS}/backhist
		RC=$?
		print RC for list history was $RC
		cat ${BACKUP_LOGS}/backhist >> ${BACK_LOG}  
		if [[ $no_loops -gt 720 ]]; then
			# -- then youve been waiting an hour
			print $0 "Im tired of waiting for the recovery history file to stabilise. Im giving up"
			break
		else
			sleep 5
			let no_loops=no_loops+1
		fi
	done
	
	echo "Content of backhist file: "
	cat ${BACKUP_LOGS}/backhist
	db2 -v commit 			| tee -a ${BACK_LOG}
	db2 -v connect reset 	| tee -a ${BACK_LOG}
	db2 -v terminate 		| tee -a ${BACK_LOG}
fi

sleep 20

# -- Prune the archive logs and archive log history file
if [[ ${NUM_BACKUPS_TO_KEEP} -eq 0 ]]; then
	db2 -v connect to ${DBNAME} | tee -a ${BACK_LOG}
	db2 -x "select location from sysibmadm.db_history where operation = 'X' and operationtype = '1' " > ${BACKUP_LOGS}/archivelog.zaplist

	for LOG in `cat ${BACKUP_LOGS}/archivelog.zaplist`
	do
		printf "`date +'%F %T'`\t%-110s\t%12d k\n" "${LOG}" "`du -sk ${LOG} | awk '{print $1}'`" >> ${CLEAN_LOG}
	done

	# --  prune history in step
	TIMESTMP=$(db2 -x "select max(start_time) from sysibmadm.db_history where operation = 'X' and operationtype = '1'")
	db2 -v PRUNE HISTORY ${TIMESTMP} WITH FORCE OPTION AND DELETE | tee -a ${BACK_LOG}
	wait
	db2 -v commit 			| tee -a ${BACK_LOG}
	db2 -v connect reset 	| tee -a ${BACK_LOG}
	db2 -v terminate 		| tee -a ${BACK_LOG}
fi
			
DATETIME=`date +%Y-%m-%d_%H%M%S`;
echo "BACKUP End time :: ${DATETIME}" >> ${BACK_LOG}

# --  Copy the current backup LOG to the Backup LOG history file 	
cat ${BACK_LOG} >> ${BACKUP_LOGS}/.BackupLOG

# -- END OF SCRIPT

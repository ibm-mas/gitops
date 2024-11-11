	#!/bin/ksh
	set -x

	#########################################################
	#                DB2_Backup.sh 
	#
	#                               Things to do:
	#             Recovery history retention (days)     (REC_HIS_RETENTN) = 0  >>> Need to set to 15 days	
	#
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

		
	. /mnt/backup/bin/.PROPS

	####  COSBACKUPBUCKET=masms-pp-1-cos-backup-pseg-test-pr-wdc
	####  For testing
	TESTMSG="########   TESTING    ###########"
	echo  ${COSBACKUPBUCKET}
	COSBACKUPBUCKET=${CONTAINER}
	####  TESTING URL

		Server=`hostname`
		instance=`whoami`
		FULLIMAGE=
		DATETIME=`date +%Y-%m-%d_%H%M%S`;
		BACKUP_BASE=/mnt/backup
		BACKUP_LOGS=${BACKUP_BASE}/${DB2INSTANCE}
		BACKUP_PATH=DB2REMOTE://AWSCOS/${COSBACKUPBUCKET}/backups-manage/${HOSTNAME}
		ARCBKP_PATH=${BACKUP_PATH}/${DATETIME}
		CLEAN_LOG=${BACKUP_PATH}/.cleanup.log
		instance_home=`/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | grep "${instance}" | awk -F ',' '{print $5}'| cut -d/ -f 1,2,3,4,5`
		IP=`/sbin/ifconfig  | grep "inet" | grep broadcast | awk '{print $2}'`
		BACK_LOG=$instance_home/bin/.$2_BackupLOG.out
		Maillog="/tmp/.backup_maillog"
		

	SLACK_NOTIFY()
	{
		   des="$instance - Backup - $Server ${database} -- DATABASE Backup issues"
		   echo "${CUSTNAME} - $instance - Backup - $Server $IP ${database} DATABASE Backup issues" 					> .Maillive.log
		   echo "############################"             								                               >> .Maillive.log
		   cat  ${BACK_LOG}                            									                               >> .Maillive.log
		   longdes=`cat .Maillive.log | sed 's/"//g' | sed "s/'//g"`
		   slackdes=" BACKUP FAILED for ${Server} - ${CONTAINER}} ...Please investigate           "
		
	###  Send Failure notification to a slack channel  ##
cat << ! >.curl_$database.sh
	curl -X POST -H 'Content-type: application/json' --data '{"text":"$slackdes"}' ${SLACKURL}
!
	/bin/bash .curl_$database.sh > .curl_$database.out 2>&1

	  #####   Create ICD Incident  ####
	  #######   If Backup fails  ###
	   des="${CUSTNAME} - ${instance} - Backup - ${HOSTNAME} ${database} - MASMS -- Backup Failed"
	   echo "############################"             >> .Maillive.log
	   longdes=`cat .Maillive.log | sed 's/"//g' | sed "s/'//g"`
	   longdes=`echo "<pre> ${longdes} </pre>"`
	   ICD_URL="https://servicedesk.mro.com"
	   if ! curl -k -s --connect-timeout 3 ${ICD_URL} >/dev/null; then
	       ICD_URL="https://servicedesk.cds.mro.com"
	   fi
cat << ! >.curl_${database}_ICD.sh
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
	/bin/bash .curl_${database}_ICD.sh > .curl_${database}_ICD.out 2>&1

	}



		if [ ! -f "$instance_home/sqllib/db2profile" ]
		then
		   echo "ERROR - $instance_home/sqllib/db2profile not found"
		   EXIT_STATUS=1
		else
		   . $instance_home/sqllib/db2profile
		fi
		
		
		if [ -f $Maillog ]
		then
		        rm $Maillog
		fi
		
		echo "COS bucket = ${COSBACKUPBUCKET} " 			> $BACK_LOG
		echo "BACKUP Start time : ${DATETIME}"  			>> $BACK_LOG
		echo " "                                			>> $BACK_LOG
		echo ${HOSTNAME}                        			>> $BACK_LOG
		echo " "                                			>> $BACK_LOG
		echo " "                               				>> $BACK_LOG
		
		if [[ $# -eq 4 ]]
		then
		   typeset -l instance=$1 database=$2
		   typeset -u INSTANCE=$1 DATABASE=$2
		   typeset -i num_backups_to_keep=$3
		   typeset -l BKUP_TYPE=$4

	##### until the db is bounced to pickup the TRACKMOD parm..We have to hardcode a FULL backup
	#####BKUP_TYPE=full
	###  BKUP_TYPE = full or inc ####
		else
		   print `tput smso` "Usage! $0 instance database number_of_backups_to_keep" `tput rmso`
		   exit 1
		fi
		
	###   Check for the existance of /home/ctginst1/sqllib/db2dump/libdb2compr.so...if it exists, delete it
		COMPRESS_LOC=$instance_home/sqllib/db2dump/libdb2compr.so
		if [[ -f ${COMPRESS_LOC} ]]
		then
			rm ${COMPRESS_LOC}
		fi
		
	###   Check to see if the database is  Running
		ps -ef | grep db2sys | grep -v grep  > /dev/null 2>&1
		if [ $? -eq 1 ]; then
		   echo "Database is not active "      
		   echo "$Server,Database Not Active,BACKUP Not Run" > $instance_home/bin/LASTbkupRUN

	###  Send error alert	
	SLACK_NOTIFY
		exit
		fi
		
	###   Check to see if the database is HADR
		db2pd -hadr -db ${database} | awk -F= '/HADR_ROLE/ {print $2}' | grep STANDBY > /dev/null 2>&1
		if [ $? -eq 0 ]; then
		    echo "This is a HADR database"      
		    echo "Backup successful. The timestamp for this backup image is : HADR_DB"      
		    echo "$Server,HADR,NO BACKUPS" > $instance_home/bin/LASTbkupRUN
		    exit 0
		fi
		
	### Create the backup directory if it doesnt already exist
		if [[ -d $BACKUP_LOGS ]]
		then :
			else mkdir -m 755 ${BACKUP_LOGS}
		fi
		
		echo "BACKUP Start time : ${DATETIME}"  
		echo " "                               
		echo $Server                      
		echo " "                             
		echo " "                            
		
		db2 -v archive log for db $database | tee -a $BACK_LOG
		sleep 30
		
		if [[ $num_backups_to_keep -gt 0 ]]
		then
	### Backup database 
		if [ ${BKUP_TYPE} = 'full' ] ; then
		   db2 -v backup db $database online to $BACKUP_PATH compress  UTIL_IMPACT_PRIORITY 50 include logs without prompting | tee -a $BACK_LOG
		else 
		   db2 -v backup db $database online INCREMENTAL DELTA to $BACKUP_PATH compress  UTIL_IMPACT_PRIORITY 50 include logs without prompting | tee -a $BACK_LOG
		fi   
		   grep -Fq "Backup successful." $BACK_LOG
		   if [ $? = 0 ]
                     then
		      Backup_timestamp=`grep timestamp $BACK_LOG | cut -d: -f2`

	###  Need to find all the files associate with the backup ## 
	###
	###
	###   Need to change this to the db2RemStgManager command to get a list of all backup images just created
	###
	###

		#  fi    
                else
                  SLACK_NOTIFY
              #    exit
		   fi
		fi

        ######## Copy keystore to COS
 set -x       
        SOURCE1=/mnt/blumeta0/db2/keystore/keystore.p12
        SOURCE2=/mnt/blumeta0/db2/keystore/keystore.sth
        TARGET1=backups-manage/${HOSTNAME}/KEYSTORE/keystore.p12
        TARGET2=backups-manage/${HOSTNAME}/KEYSTORE/keystore.sth

        DB2V=`db2level | grep Inform | awk '{print $5}' | sed 's/",//'`
        if [ ${DB2V} = "v11.5.7.0" ]
        then
           db2RemStgManager S3 put server=${SERVER} auth1=${PARM1} auth2=${PARM2} container=${CONTAINER} source=${SOURCE1} target=${TARGET1}
           db2RemStgManager S3 put server=${SERVER} auth1=${PARM1} auth2=${PARM2} container=${CONTAINER} source=${SOURCE2} target=${TARGET2}

        else
           db2RemStgManager ALIAS PUT source=${SOURCE1} target=DB2REMOTE://AWSCOS//${TARGET1}
           db2RemStgManager ALIAS PUT source=${SOURCE2} target=DB2REMOTE://AWSCOS//${TARGET2}
        fi



	# exclude files that arent backups, e.g. backhist listing.	
		typeset -i no_backups=`./CheckCOS.sh | grep -i ${database}| cut -d/ -f3| grep 001 |wc -l`
		echo " number of backups $no_backups"
	###  Prune the history file, if and only if the last backup succeeded.
	###  Remove archive transaction logs for expired backups, if there are a requisite number of successful backups.
	###  Remove expired backups in step.
		
		if [[ $num_backups_to_keep -gt 0 && $no_backups -ge $num_backups_to_keep ]]
		then
		   db2 -v connect to $database | tee -a $BACK_LOG
		 
		   timestmp=$(db2 -x "select coalesce(max(start), 17890713235959) from \
		                        (select bigint(start_time) - 1 as start, \
		                        row_number() over(order by start_time desc) as backup \
		                        from   sysibmadm.db_history              \
		                        where  operation = 'B'                   \
		                        and    objecttype = 'D'                  \
		                        and    devicetype = 'D'                  \
		                        and    sqlcode is null                   \
		                        and    sqlwarn is null                   \
		                        ) as zzz                                 \
		                        where backup = $num_backups_to_keep" )

		   db2 -v prune history $timestmp WITH FORCE OPTION and delete | tee -a $BACK_LOG

		
	###  loop until the recovery history file is stable and then report it
		   RC=999
		   typeset -i no_loops=0
		   while [[ $RC -gt 0 ]]
		   do
		      db2 -v list history backup since $timestmp for $database > ${BACKUP_LOGS}/backhist
		      RC=$?
		      print RC for list history was $RC
		      cat ${BACKUP_LOGS}/backhist >> $BACK_LOG  
		      if [[ $no_loops -gt 720 ]]
		      then
	### then youve been waiting an hour
		         print $0 "Im tired of waiting for the recovery history file to stabilise. Im giving up"
		         break
		      else
		         sleep 5
		         let no_loops=no_loops+1
		      fi
		   done
		   echo "Content of backhist file:"
		   cat ${BACKUP_LOGS}/backhist
		   db2 -v commit | tee -a $BACK_LOG
		
		   db2 -v connect reset | tee -a $BACK_LOG
		   db2 -v terminate | tee -a $BACK_LOG
		fi
		sleep 30
		
		if [[ $num_backups_to_keep -eq 0 ]]
		then
		   db2 -v connect to $database | tee -a $BACK_LOG
		   db2 -x "select location                 \
		           from   sysibmadm.db_history     \
		           where  operation = 'X'          \
		           and    operationtype = '1' "    > $BACKUP_LOGS/archivelog.zaplist
		   for log in `cat $BACKUP_LOGS/archivelog.zaplist`
		   do
		       printf "`date +'%F %T'`\t%-110s\t%12d k\n" "${log}" "`du -sk ${log} | awk '{print $1}'`" >> ${CLEAN_LOG}
		   done
	###  prune history in step
		   timestmp=$(db2 -x "select max(start_time) from sysibmadm.db_history where operation = 'X' and operationtype = '1'")
		   db2 -v prune history $timestmp WITH FORCE OPTION and delete | tee -a $BACK_LOG
		   wait
		   db2 -v commit | tee -a $BACK_LOG
		   db2 -v connect reset | tee -a $BACK_LOG
		   db2 -v terminate | tee -a $BACK_LOG
		fi
		
		
		DATETIME=`date +%Y-%m-%d_%H%M%S`;
		echo "BACKUP End time : ${DATETIME}" >> $BACK_LOG
		
		if [[ ${BKUP_STATUS} -gt 0 ]]
		then
	###  Send error alert
	SLACK_NOTIFY	


		fi

	###  Copy the current backup log to the Backup log history file 	
		cat  $BACK_LOG >>   ${BACKUP_LOGS}/.BackupLOG


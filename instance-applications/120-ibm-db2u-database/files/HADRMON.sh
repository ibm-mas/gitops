#!/bin/bash
#uthor:  Fu Le Qing (Roking)
#		    Email:	 leqingfu@cn.ibm.com
#       Date:    07-24-2019
#
#       Description: This script detects the the HADR state, and then  
#              create a task in service desk once the error is caught. 
#
# ********          THIS NEEDS TO BE RUN AS INSTANCE OWNER.   **************
#
#       Revision history:
#               07-24-2019      Fu Le Qing (Roking)
#                       Original version
# ***************************************************************************
#               11-06-2019      Fu Le Qing (Roking)
#               Add running information for audit      
#               05-08-2020      Fu Le Qing (Roking)
#               change to monitor the specified database 
#               07-07-2021      Fu Le Qing (Roking)
#               sent to servicedesk through RSLC API                          
# ***************************************************************************
# run as below: 
# ./HADRMON.sh database_name                            
# ***************************************************************************
#set -x
CUSTNAME=SMRT_SDB
instance="db2inst1"
. /mnt/backup/bin/.PROPS

if [ ! -f "${HOME}/sqllib/db2profile" ]
then   
   echo "ERROR - ${HOME}/sqllib/db2profile not found" 
   exit
else
   . ${HOME}/sqllib/db2profile
fi

if [[ $# != 1 ]];then
        echo "Usage: command  database_name"
        exit
fi

HADRMON="/tmp/.hadrmon"
Maillog="/tmp/.Maillog"

For_audit="${HOME}/bin/LOGS/.HADRcheck.out"

DATETIME=`date +%Y-%m-%d_%H%M%S`


SLACK_NOTIFY()
{
           des="$instance - HADR sync issues $Server ${database} -- DATABASE "
           echo "${CUSTNAME} - $instance - HADR sync issues - $HOSTNAME $IP ${database} DATABASE"                         > .Maillive.log
           echo "############################"                                                                          >> .Maillive.log
           #echo "${TESTMSG}"                                                                                           >> .Maillive.log
           echo "${longdes} "                                                                                           >> .Maillive.log
           longdes=`cat .Maillive.log | sed 's/"//g' | sed "s/'//g"`

###  Send Failure notification to a slack channel  ##
cat << ! >.curl_$database.sh
curl -X POST -H 'Content-type: application/json' --data '{"text":"$longdes"}' $SLACKURL
!
/bin/bash .curl_$database.sh > .curl_$database.out 2>&1
}


if [ -f $HADRMON ]
then 
	rm $HADRMON
fi 

if [ -f $Maillog ]
then 
	rm $Maillog
fi 

if [[ -f /mnt/backup/bin/.PROPS ]]
then
	Server=`cat /mnt/backup/bin/.PROPS | grep CONTAINER | cut -d= -f2`
else
	Server=`hostname`
fi
if [ ! -n "$Server" ];then
    Server=`hostname`
fi
IP=`hostname -i`
USERNAME=`whoami`

status_check()
{    
  if [[ "$1" == "SUPERASYNC" ]]
  then
    if [[ "$2" != "REMOTE_CATCHUP" ]]
    then
      STATEWELL_DDB=0                   
    fi
    if echo $3 | grep -Ei "maxdb|tridb|bludb" >/dev/null
    then
      if [[ "$4" == "$5" ]]
      then
        echo "The Standby database(DDB/AUX) ARCH number is $4 at ${DATETIME}" >> $For_audit
        echo "The Primary database          ARCH number is $5 at ${DATETIME}" >> $For_audit
        echo "Primary and Standby databases(DDB/AUX) are in sync"                >> $For_audit    
      else
        echo "The Standby database(DDB/AUX) ARCH number is $4 at ${DATETIME}" >> $For_audit
        echo "The Primary database          ARCH number is $5 at ${DATETIME}" >> $For_audit
        echo "Primary and Standby databases(DDB/AUX) are out of sync"                >> $For_audit
      fi         
    fi      
  else
   if [[ "$2" != "PEER" ]]
   then
      STATEWELL=0
   fi
   if echo $3 | grep -Ei "maxdb|tridb|bludb" >/dev/null
   then
     if [[ "$4" == "$5" ]]
     then
       echo "The Standby database ARCH number is $4 at ${DATETIME}" >> $For_audit
       echo "The Primary database ARCH number is $5 at ${DATETIME}" >> $For_audit
       echo "Primary and Standby databases are in sync"                >> $For_audit  
     else
       echo "The Standby database ARCH number is $4 at ${DATETIME}" >> $For_audit
       echo "The Primary database ARCH number is $5 at ${DATETIME}" >> $For_audit
       echo "Primary and Standby databases are out of sync"                >> $For_audit
     fi
   fi
  fi   
}
flag_instance=0
instance_status=`db2gcf -s | grep  "Available" | wc -l`
if [[ "$instance_status" != "1" ]]
then
  flag_instance=1
  if [[ ! -f ${HOME}/.NOSEND_$instance ]]
  then
    des="$Server instance is not active"
    longdes="instance is not active. $Server $IP"
    ICD_URL="https://servicedesk.mro.com"
    if ! curl -k -s --connect-timeout 3 ${ICD_URL} >/dev/null; then
        ICD_URL="https://servicedesk.cds.mro.com"
    fi       
cat << ! >curl.sh
  curl --insecure --location --request POST "${ICD_URL}/maximo_mif/oslc/os/hsincident?lean=1" \
  --header 'Authorization: Basic <auth>' \
  --header 'Content-Type: application/json' \
  --data '{
  "description":"$des",
  "reportedpriority":4,
  "internalpriority":4,
  "reportedby":"DB2",
  "affectedperson":"DB2INST1",
  "description_longdescription":"$longdes",
  "siteid":"001",
  "classstructureid":"1341",
  "classificationid":"IN-DBPERF",
  "hshost":"${Server:0:50}",
  "hstype":"HADR"
  }'
!
SLACK_NOTIFY
    /bin/bash curl.sh > .curl_$database.out 2>&1   
    grep -v Received .curl.out | grep -v Dload | grep -v "\-\-:\-\-:\-\-" >$Maillog
    if [ -s $Maillog  ]; then
      echo "###################################################" >>$Maillog
      echo $longdes >>$Maillog
      mail -s "$Server HADR error, but failed to create task through OSLC API" `cat $Mail_recp` < $Maillog
    fi    
    echo "                              -----------------                  " >>$For_audit 
    echo "HADR is not active at ${DATETIME}"           >> $For_audit
    touch ${HOME}/.NOSEND_$instance       
  fi
  exit
fi

#dbs=(`db2 list db directory | grep -B 5 Indirect | grep "Database name" | cut -d= -f2`)
#for i in ${dbs[*]}
#do 
  i=$1
  database=${i}
  STATEWELL=1
  STATEWELL_DDB=1
  flag_db=0
  db2pd -db $i -hadr >$HADRMON
  inactive=`cat $HADRMON | grep -E "HADR is not active|not activated" | wc -l`
  if [[ "$inactive" == "1" ]]
  then
    flag_db=1
    if [[ ! -f ${HOME}/.NOSEND_$i ]]
    then
      #echo "TO: cds-incident@inotes.cdstest.mro.com"          	         > $Maillog
      #echo "From: $Server" 	        >> $Maillog      
      #echo "Subject: $USERNAME^HADR^$Server^4^HADR is not active" >> $Maillog
      #echo "HADR is not active. $Server $IP database:$i"             >> $Maillog 
      #cat  $Maillog  | /usr/lib/sendmail -t 
      des="$Server HADR is not active"
      longdes="HADR is not active. $Server $IP database:$i"  
      ICD_URL="https://servicedesk.mro.com"
      if ! curl -k -s --connect-timeout 3 ${ICD_URL} >/dev/null; then
          ICD_URL="https://servicedesk.cds.mro.com"
      fi
SLACK_NOTIFY
cat << ! >curl.sh
  curl --insecure --location --request POST "${ICD_URL}/maximo_mif/oslc/os/hsincident?lean=1" \
  --header 'Authorization: Basic <auth>' \
  --header 'Content-Type: application/json' \
  --data '{
  "description":"$des",
  "reportedpriority":4,
  "internalpriority":4,
  "reportedby":"DB2",
  "affectedperson":"DB2INST1",
  "description_longdescription":"$longdes",
  "siteid":"001",
  "classstructureid":"1341",
  "classificationid":"IN-DBPERF",
  "hshost":"${Server:0:50}",
  "hstype":"HADR"
  }'
!
      /bin/bash curl.sh > .curl.out 2>&1   
      grep -v Received .curl.out | grep -v Dload | grep -v "\-\-:\-\-:\-\-" >$Maillog
      if [ -s $Maillog  ]; then
        echo "###################################################" >>$Maillog
        echo $longdes >>$Maillog
        mail -s "$Server HADR error, but failed to create task through OSLC API" `cat $Mail_recp` < $Maillog
      fi         
      touch ${HOME}/.NOSEND_$i        
      if echo $i | grep -Ei "maxdb|tridb|bludb" >/dev/null
      then
        echo "                              -----------------                  " >>$For_audit 
        echo "HADR is not active at ${DATETIME}"           >> $For_audit     
      fi       
    fi
    #continue
    exit        
  fi

  mutitarget=`db2 get db cfg for $i | grep HADR_TARGET_LIST | grep "|" | wc -l`
  hadr_role=`db2 get db cfg for $i | grep "HADR database role" | cut -d= -f2 | sed 's/ //g'`
  if [[ "$mutitarget" == "1" ]] && [[ "$hadr_role" == "PRIMARY" ]]
  then      
    hadr_syncmode=`cat $HADRMON | grep HADR_SYNCMODE | head -1 | cut -d= -f2 | sed 's/ //g'`
    if [[ ! -n $hadr_syncmode ]]
    then
      hadr_syncmode=`db2 get db cfg for $i | grep HADR_SYNCMODE | cut -d= -f2 | sed 's/ //g'`
    fi
    hadr_state_sdb=`cat $HADRMON | grep HADR_STATE | head -1 | cut -d= -f2 | sed 's/ //g'`
    hadr_flags_sdb=`cat $HADRMON | grep HADR_FLAGS | head -1 | cut -d= -f2`
    hadr_flags_error_sdb=`cat $HADRMON | grep HADR_FLAGS | head -1 | grep -iE "ERROR|FULL|BLOCKED" | wc -l`
    standby_error_time_sdb=`cat $HADRMON | grep STANDBY_ERROR_TIME | head -1 | cut -d= -f2`
    primary_log_file=`cat $HADRMON | grep "PRIMARY_LOG_FILE" | head -1 | cut -d= -f2 | cut -d. -f1 | sed 's/ //'`
    standby_log_file=`cat $HADRMON | grep "STANDBY_LOG_FILE" | head -1 | cut -d= -f2 | cut -d. -f1 | sed 's/ //'`      
    
    if echo $i | grep -Ei "maxdb|tridb|bludb" >/dev/null
    then
      echo "                              -----------------                  " >> $For_audit
    fi      
    status_check $hadr_syncmode $hadr_state_sdb $i $standby_log_file $primary_log_file
    hadr_syncmode=`cat $HADRMON | grep HADR_SYNCMODE | tail -1 | cut -d= -f2 | sed 's/ //g'`
    if [[ ! -n $hadr_syncmode ]]
    then
      hadr_syncmode=`db2 get db cfg for $i | grep HADR_SYNCMODE | cut -d= -f2 | sed 's/ //g'`
    fi      
    hadr_state_ddb=`cat $HADRMON | grep HADR_STATE | tail -1 | cut -d= -f2 | sed 's/ //g'`
    hadr_flags_ddb=`cat $HADRMON | grep HADR_FLAGS | tail -1 | cut -d= -f2`
    hadr_flags_error_ddb=`cat $HADRMON | grep HADR_FLAGS | tail -1 | grep -iE "ERROR|FULL|BLOCKED" | wc -l`
    standby_error_time_ddb=`cat $HADRMON | grep STANDBY_ERROR_TIME | tail -1 | cut -d= -f2`
    primary_log_file=`cat $HADRMON | grep "PRIMARY_LOG_FILE" | tail -1 | cut -d= -f2 | cut -d. -f1 | sed 's/ //'`
    standby_log_file=`cat $HADRMON | grep "STANDBY_LOG_FILE" | tail -1 | cut -d= -f2 | cut -d. -f1 | sed 's/ //'`
    status_check $hadr_syncmode $hadr_state_ddb $i $standby_log_file $primary_log_file  
    flag_db_sdb=0
    flag_db_ddb=0
    if [[ "$STATEWELL" == "0" ]]
    then
        flag_db_sdb=1
        if [[ ! -f ${HOME}/.NOSEND_sdb_$i ]]
        then
          #echo "TO: cds-incident@inotes.cdstest.mro.com"          	         > $Maillog
          #echo "From: $Server" 	        >> $Maillog          
          #echo "Subject: $USERNAME^HADR^$Server^4^HADR is out of sync" >> $Maillog
          #echo "HADR(SDB) is out of sync. HADR_STATE:$hadr_state_sdb $Server $IP database:$i"     >> $Maillog 
          #cat  $Maillog  | /usr/lib/sendmail -t
          des="$Server HADR is out of sync"
          longdes="HADR(SDB) is out of sync. HADR_STATE:$hadr_state_sdb $Server $IP database:$i" 
          ICD_URL="https://servicedesk.mro.com"
          if ! curl -k -s --connect-timeout 3 ${ICD_URL} >/dev/null; then
              ICD_URL="https://servicedesk.cds.mro.com"
          fi       
SLACK_NOTIFY
cat << ! >curl.sh
  curl --insecure --location --request POST "${ICD_URL}/maximo_mif/oslc/os/hsincident?lean=1" \
  --header 'Authorization: Basic Y2RzaW50ZGJhOklSZWFsbHlMb3ZlUHVwcGllcw==' \
  --header 'Content-Type: application/json' \
  --data '{
  "description":"$des",
  "reportedpriority":4,
  "internalpriority":4,
  "reportedby":"DB2",
  "affectedperson":"DB2INST1",
  "description_longdescription":"$longdes",
  "siteid":"001",
  "classstructureid":"1341",
  "classificationid":"IN-DBPERF",
  "hshost":"${Server:0:50}",
  "hstype":"HADR"
  }'
!
          /bin/bash curl.sh > .curl.out 2>&1   
          grep -v Received .curl.out | grep -v Dload | grep -v "\-\-:\-\-:\-\-" >$Maillog
          if [ -s $Maillog  ]; then
            echo "###################################################" >>$Maillog
            echo $longdes >>$Maillog
            mail -s "$Server HADR error, but failed to create task through OSLC API" `cat $Mail_recp` < $Maillog
          fi         
          touch ${HOME}/.NOSEND_sdb_$i 
        fi          
    fi 
    if [[ "$STATEWELL_DDB" == "0" ]]
    then
        flag_db_ddb=1
        if [[ ! -f ${HOME}/.NOSEND_ddb_$i ]]
        then
          #echo "TO: cds-incident@inotes.cdstest.mro.com"          	         > $Maillog
          #echo "From: $Server" 	        >> $Maillog          
          #echo "Subject: $USERNAME^HADR^$Server^4^HADR is out of sync" >> $Maillog
          #echo "HADR(DDB/AUX) is out of sync. HADR_STATE:$hadr_state_ddb $Server $IP database:$i"     >> $Maillog 
          #cat  $Maillog  | /usr/lib/sendmail -t
          des="$Server HADR is out of sync"
          longdes="HADR(DDB/AUX) is out of sync. HADR_STATE:$hadr_state_ddb $Server $IP database:$i" 
          ICD_URL="https://servicedesk.mro.com"
          if ! curl -k -s --connect-timeout 3 ${ICD_URL} >/dev/null; then
              ICD_URL="https://servicedesk.cds.mro.com"
          fi       
SLACK_NOTIFY
cat << ! >curl.sh
  curl --insecure --location --request POST "${ICD_URL}/maximo_mif/oslc/os/hsincident?lean=1" \
  --header 'Authorization: Basic <auth>' \
  --header 'Content-Type: application/json' \
  --data '{
  "description":"$des",
  "reportedpriority":4,
  "internalpriority":4,
  "reportedby":"DB2",
  "affectedperson":"DB2INST1",
  "description_longdescription":"$longdes",
  "siteid":"001",
  "classstructureid":"1341",
  "classificationid":"IN-DBPERF",
  "hshost":"${Server:0:50}",
  "hstype":"HADR"
  }'
!
          /bin/bash curl.sh > .curl.out 2>&1   
          grep -v Received .curl.out | grep -v Dload | grep -v "\-\-:\-\-:\-\-" >$Maillog
          if [ -s $Maillog  ]; then
            echo "###################################################" >>$Maillog
            echo $longdes >>$Maillog
            mail -s "$Server HADR error, but failed to create task through OSLC API" `cat $Mail_recp` < $Maillog
          fi                  
          touch ${HOME}/.NOSEND_ddb_$i 
        fi
        #continue
        exit           
    fi
    if [[ "$hadr_flags_error_sdb" == "1" ]]
    then
      flag_db_sdb=1
      if [[ ! -f ${HOME}/.NOSEND_sdb_$i ]]
      then
        #echo "TO: cds-incident@inotes.cdstest.mro.com"          	         > $Maillog
        #echo "From: $Server" 	        >> $Maillog        
        #echo "Subject: $USERNAME^HADR^$Server^4^HADR(SDB) eror $hadr_flags_sdb" >> $Maillog
        #echo "HADR(SDB) eror $hadr_flags_sdb occured at $standby_error_time_sdb."   >> $Maillog 
        #echo "$Server $IP database:$i"  >> $Maillog 
        #cat  $Maillog  | /usr/lib/sendmail -t
        des="$Server HADR(SDB) eror $hadr_flags_sdb"
        longdes="HADR(SDB) eror $hadr_flags_sdb occured at $standby_error_time_sdb. $Server $IP database:$i"  
        ICD_URL="https://servicedesk.mro.com"
        if ! curl -k -s --connect-timeout 3 ${ICD_URL} >/dev/null; then
            ICD_URL="https://servicedesk.cds.mro.com"
        fi       
SLACK_NOTIFY
cat << ! >curl.sh
  curl --insecure --location --request POST "${ICD_URL}/maximo_mif/oslc/os/hsincident?lean=1" \
  --header 'Authorization: Basic <auth>' \
  --header 'Content-Type: application/json' \
  --data '{
  "description":"$des",
  "reportedpriority":4,
  "internalpriority":4,
  "reportedby":"DB2",
  "affectedperson":"DB2INST1",
  "description_longdescription":"$longdes",
  "siteid":"001",
  "classstructureid":"1341",
  "classificationid":"IN-DBPERF",
  "hshost":"${Server:0:50}",
  "hstype":"HADR"
  }'
!
        /bin/bash curl.sh > .curl.out 2>&1   
        grep -v Received .curl.out | grep -v Dload | grep -v "\-\-:\-\-:\-\-" >$Maillog
        if [ -s $Maillog  ]; then
          echo "###################################################" >>$Maillog
          echo $longdes >>$Maillog
          mail -s "$Server HADR error, but failed to create task through OSLC API" `cat $Mail_recp` < $Maillog
        fi                
        touch ${HOME}/.NOSEND_sdb_$i 
      fi       
    fi                         
    if [[ "$hadr_flags_error_ddb" == "1" ]]
    then
      flag_db_ddb=1
      if [[ ! -f ${HOME}/.NOSEND_ddb_$i ]]
      then
        #echo "TO: cds-incident@inotes.cdstest.mro.com"          	         > $Maillog
        #echo "From: $Server" 	        >> $Maillog           
        #echo "Subject: $USERNAME^HADR^$Server^4^HADR(DDB/AUX) eror $hadr_flags_ddb" >> $Maillog
        #echo "HADR(DDB/AUX) eror $hadr_flags_ddb occured at $standby_error_time_ddb."   >> $Maillog 
        #echo "$Server $IP database:$i"  >> $Maillog 
        #cat  $Maillog  | /usr/lib/sendmail -t
        des="$Server HADR(DDB/AUX) eror $hadr_flags_ddb"
        longdes="HADR(DDB/AUX) eror $hadr_flags_ddb occured at $standby_error_time_ddb. $Server $IP database:$i"  
        ICD_URL="https://servicedesk.mro.com"
        if ! curl -k -s --connect-timeout 3 ${ICD_URL} >/dev/null; then
            ICD_URL="https://servicedesk.cds.mro.com"
        fi       
SLACK_NOTIFY
cat << ! >curl.sh
  curl --insecure --location --request POST "${ICD_URL}/maximo_mif/oslc/os/hsincident?lean=1" \
  --header 'Authorization: Basic <auth>' \
  --header 'Content-Type: application/json' \
  --data '{
  "description":"$des",
  "reportedpriority":4,
  "internalpriority":4,
  "reportedby":"DB2",
  "affectedperson":"DB2INST1",
  "description_longdescription":"$longdes",
  "siteid":"001",
  "classstructureid":"1341",
  "classificationid":"IN-DBPERF",
  "hshost":"${Server:0:50}",
  "hstype":"HADR"
  }'
!
        /bin/bash curl.sh > .curl.out 2>&1   
        grep -v Received .curl.out | grep -v Dload | grep -v "\-\-:\-\-:\-\-" >$Maillog
        if [ -s $Maillog  ]; then
          echo "###################################################" >>$Maillog
          echo $longdes >>$Maillog
          mail -s "$Server HADR error, but failed to create task through OSLC API" `cat $Mail_recp` < $Maillog
        fi             
        touch ${HOME}/.NOSEND_ddb_$i   
      fi             
    fi                              
  else
    hadr_syncmode=`cat $HADRMON | grep HADR_SYNCMODE | cut -d= -f2 | sed 's/ //g'`
    if [[ ! -n $hadr_syncmode ]]
    then
      hadr_syncmode=`db2 get db cfg for $i | grep HADR_SYNCMODE | cut -d= -f2 | sed 's/ //g'`
    fi   
    hadr_state=`cat $HADRMON | grep HADR_STATE | cut -d= -f2 | sed 's/ //g'`
    hadr_flags=`cat $HADRMON | grep HADR_FLAGS | cut -d= -f2`
    hadr_flags_error=`cat $HADRMON | grep HADR_FLAGS | grep -iE "ERROR|FULL|BLOCKED" | wc -l`
    standby_error_time=`cat $HADRMON | grep STANDBY_ERROR_TIME | cut -d= -f2`
    primary_log_file=`cat $HADRMON | grep "PRIMARY_LOG_FILE" | cut -d= -f2 | cut -d. -f1 | sed 's/ //'`
    standby_log_file=`cat $HADRMON | grep "STANDBY_LOG_FILE" | cut -d= -f2 | cut -d. -f1 | sed 's/ //'`
    if echo $i | grep -Ei "maxdb|tridb|bludb" >/dev/null
    then
      echo "                              -----------------                  " >> $For_audit
    fi      
    status_check $hadr_syncmode $hadr_state $i $standby_log_file $primary_log_file
    flag_db=0
    if [[ "$STATEWELL" == "0" ]] || [[ "$STATEWELL_DDB" == "0" ]]
    then
        flag_db=1
        if [[ ! -f ${HOME}/.NOSEND_$i ]]
        then
          #echo "TO: cds-incident@inotes.cdstest.mro.com"          	         > $Maillog
          #echo "From: $Server" 	        >> $Maillog               
          #echo "Subject: $USERNAME^HADR^$Server^4^HADR is out of sync" >> $Maillog
          #echo "HADR is out of sync. HADR_STATE:$hadr_state $Server $IP database:$i"     >> $Maillog 
          #cat  $Maillog  | /usr/lib/sendmail -t
          des="$Server HADR is out of sync"
          longdes="HADR is out of sync. HADR_STATE:$hadr_state $Server $IP database:$i"    
          ICD_URL="https://servicedesk.mro.com"
          if ! curl -k -s --connect-timeout 3 ${ICD_URL} >/dev/null; then
              ICD_URL="https://servicedesk.cds.mro.com"
          fi       
SLACK_NOTIFY
cat << ! >curl.sh
  curl --insecure --location --request POST "${ICD_URL}/maximo_mif/oslc/os/hsincident?lean=1" \
  --header 'Authorization: Basic <auth>' \
  --header 'Content-Type: application/json' \
  --data '{
  "description":"$des",
  "reportedpriority":4,
  "internalpriority":4,
  "reportedby":"DB2",
  "affectedperson":"DB2INST1",
  "description_longdescription":"$longdes",
  "siteid":"001",
  "classstructureid":"1341",
  "classificationid":"IN-DBPERF",
  "hshost":"${Server:0:50}",
  "hstype":"HADR"
  }'
!
  #        /bin/bash curl.sh > .curl.out 2>&1   
          grep -v Received .curl.out | grep -v Dload | grep -v "\-\-:\-\-:\-\-" >$Maillog
          if [ -s $Maillog  ]; then
            echo "###################################################" >>$Maillog
            echo $longdes >>$Maillog
   #         mail -s "$Server HADR error, but failed to create task through OSLC API" `cat $Mail_recp` < $Maillog
          fi               
          touch ${HOME}/.NOSEND_$i
        fi  
        #continue
        exit          
    fi       
    if [[ "$hadr_flags_error" == "1" ]]
    then
      flag_db=1
      if [[ ! -f ${HOME}/.NOSEND_$i ]]
      then
        #echo "TO: cds-incident@inotes.cdstest.mro.com"          	         > $Maillog
        #echo "From: $Server" 	        >> $Maillog             
        #echo "Subject: $USERNAME^HADR^$Server^4^HADR eror $hadr_flags" >> $Maillog
        #echo "HADR eror $hadr_flags occured at $standby_error_time."   >> $Maillog 
        #echo "$Server $IP database:$i"  >> $Maillog 
        #cat  $Maillog  | /usr/lib/sendmail -t
        des="$Server HADR eror $hadr_flags"
        longdes="HADR eror $hadr_flags occured at $standby_error_time. $Server $IP database:$i"      
        ICD_URL="https://servicedesk.mro.com"
        if ! curl -k -s --connect-timeout 3 ${ICD_URL} >/dev/null; then
            ICD_URL="https://servicedesk.cds.mro.com"
        fi       

SLACK_NOTIFY

cat << ! >curl.sh
  curl --insecure --location --request POST "${ICD_URL}/maximo_mif/oslc/os/hsincident?lean=1" \
  --header 'Authorization: Basic <auth>' \
  --header 'Content-Type: application/json' \
  --data '{
  "description":"$des",
  "reportedpriority":4,
  "internalpriority":4,
  "reportedby":"DB2",
  "affectedperson":"DB2INST1",
  "description_longdescription":"$longdes",
  "siteid":"001",
  "classstructureid":"1341",
  "classificationid":"IN-DBPERF",
  "hshost":"${Server:0:50}",
  "hstype":"HADR"
  }'
!
        /bin/bash curl.sh > .curl.out 2>&1   
        grep -v Received .curl.out | grep -v Dload | grep -v "\-\-:\-\-:\-\-" >$Maillog
        if [ -s $Maillog  ]; then
          echo "###################################################" >>$Maillog
          echo $longdes >>$Maillog
          mail -s "$Server HADR error, but failed to create task through OSLC API" `cat $Mail_recp` < $Maillog
        fi        
        touch ${HOME}/.NOSEND_$i
      fi              
    fi   
  fi

  if [[ -f ${HOME}/.NOSEND_$i ]] && [[ "$flag_db" == "0" ]]
  then
    rm ${HOME}/.NOSEND_$i
  fi
  if [[ -f ${HOME}/.NOSEND_sdb_$i ]] && [[ "$flag_db_sdb" == "0" ]]
  then
    rm ${HOME}/.NOSEND_sdb_$i
  fi
  if [[ -f ${HOME}/.NOSEND_ddb_$i ]] && [[ "$flag_db_ddb" == "0" ]]
  then
    rm ${HOME}/.NOSEND_ddb_$i
  fi     
#done 

if [[ -f ${HOME}/.NOSEND_$instance ]] && [[ "$flag_instance" == "0" ]]
then
  rm ${HOME}/.NOSEND_$instance
fi

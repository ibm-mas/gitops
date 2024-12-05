#!/bin/bash
# ***************************************************************************
#       Author:  Fu Le Qing (Roking)
#		Email:	leqingfu@cn.ibm.com
#       Date:   05-08-2019
#
#       Description: Extract authorizations from database 
#
# ********          THIS NEEDS TO BE RUN AS INSTANCE OWNER.   **************
#
#       Revision history:
#               05-08-2019      Fu Le Qing (Roking)
#                       Original version
#               24-06-2024      Prudhviraj
#                       Added date and time to sql file
#
# ***************************************************************************
# run as below: 
# To extract all of the authorizations from database: 
#./extract_authorization.sh database_name
# To extract the specified users' authorizations from database: 
#./extract_authorization.sh database_name user_name                         
# ***************************************************************************
#set -x
instance=`/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | awk -F ',' '{print $4}'`
#instance_home=`/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | grep "${instance}" | awk -F ',' '{print $5}'| cut -d/ -f 1,2,3`
instance_home=/mnt/blumeta0/home/db2inst1
DT=`date +'%F-%H-%M'`
if [ ! -f "$instance_home/sqllib/db2profile" ]
then   
   echo "ERROR - $instance_home/sqllib/db2profile not found"  
   EXIT_STATUS=1
else

   . $instance_home/sqllib/db2profile
fi

if [[ $# != 1 ]] && [[ $# != 2 ]];then
        echo "Usage: command  database_name"
		echo "OR"
		echo "Usage: command  database_name user_name"
        exit
fi

GRANTS_FILE="$instance_home/bin/grants_$DT.sql"


if [ -f $GRANTS_FILE ]
then 
	rm $GRANTS_FILE
fi 

if [[ $# == 1 ]];then
	db2look -x -d $1 -o $GRANTS_FILE
	echo "The authorizations are saved into file:"
	echo $GRANTS_FILE
    exit
fi

if [[ $# == 2 ]];then
	typeset -u user
	user=$2
	db2look -x -d $1 | grep -w "TO USER \"$user"
    exit
fi

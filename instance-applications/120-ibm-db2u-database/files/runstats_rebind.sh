#!/bin/bash
# ***************************************************************************
#       Author:  Fu Le Qing (Roking)
#		Email:	leqingfu@cn.ibm.com
#       Date:   10-31-2018
#
#       Description: This script updates statistics of tables,
# 					 associated indexes in the database, and sends an email
#                    to a specified email list.
#
# ********          THIS NEEDS TO BE RUN AS INSTANCE OWNER.   **************
#
#       Revision history:
#               10-31-2018      Fu Le Qing (Roking)
#                       Original version
#               11-16-2018      Fu Le Qing (Roking)
#                    Skip the tables which are ongoing with reorg
#               09-08-2023      Fu Le Qing (Roking)
#                    Update for MAS
#
# ***************************************************************************
#
# ***************************************************************************
if [ -f /mnt/backup/bin/.PROPS ]
then
    . /mnt/backup/bin/.PROPS
    DOW=`date |  awk '{print $1}'`
    if [ ${DOW} != ${DAYOFFULL} ]
    then
        exit 0
    fi
fi

instance=`whoami`
instance_home=`/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | grep "${instance}" | awk -F ',' '{print $5}'| sed 's/\/sqllib//'`

pidfile="$instance_home/.`basename ${0}`.pid"
if [ -e ${pidfile} ] && $kill -0 `cat ${pidfile}` 2>/dev/null 
then
    exit 0
fi

echo $$ > ${pidfile}
trap "rm -f ${pidfile}; exit" SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM EXIT

if [ ! -f "$instance_home/sqllib/db2profile" ]
then
   echo "ERROR - $instance_home/sqllib/db2profile not found"
   exit 1
else
   . $instance_home/sqllib/db2profile
fi

RUNSTATS_TMP_FILE="$instance_home/.runstats.sql"
REBIND_TMP_FILE="$instance_home/.rebind.sql"

mkdir -p $instance_home/maintenance/logs
DATESTAMP=`date "+%Y-%m-%d-%H.%M.%S"`

for db in `db2 list db directory | grep -B 5 Indirect | grep "Database name" | cut -d= -f2`
do
	role=`db2 get db cfg for ${db} | grep "HADR database role" | cut -d= -f2 |sed 's/ //g'`
	if [ "$role" != "STANDBY" ]; then
		if [ -f $RUNSTATS_TMP_FILE ]
		then
			rm $RUNSTATS_TMP_FILE
		fi
		if [ -f $REBIND_TMP_FILE ]
		then
			rm $REBIND_TMP_FILE
		fi
		db2 connect to ${db} | tee $instance_home/maintenance/logs/runstats_${db}_${DATESTAMP}
		if [ $? -eq 0 ]; then
			db2 -x "select 'RUNSTATS ON TABLE \"' ||rtrim(tab.tabschema)||'\".\"'|| tab.tabname ||'\" WITH DISTRIBUTION ON KEY COLUMNS AND DETAILED INDEXES ALL ALLOW WRITE ACCESS;'
			from syscat.tables tab left join sysibmadm.SNAPTAB_REORG reg on tab.tabschema=reg.TABSCHEMA and tab.tabname=reg.TABNAME and reg.REORG_STATUS not in ('COMPLETED','STOPPED')
			where tab.type='T' and reg.tabname is null" > $RUNSTATS_TMP_FILE
			#db2 -x "select 'rebind package \"' ||rtrim(PKGSCHEMA)||'\".\"'|| PKGNAME ||'\";' from syscat.packages where PKGSCHEMA not in ('NULLID','NULLIDR1','NULLIDRA','SYSIBMADM','SYSIBMINTERNAL') and PKGSCHEMA not like 'NULL%' " > $REBIND_TMP_FILE
			echo "Begin processing of runstats @ $DATESTAMP ..." | tee -a $instance_home/maintenance/logs/runstats_${db}_${DATESTAMP}
			db2 -txvf $RUNSTATS_TMP_FILE | tee -a $instance_home/maintenance/logs/runstats_${db}_${DATESTAMP}
			echo "End processing of runstats  @ $DATESTAMP" | tee -a $instance_home/maintenance/logs/runstats_${db}_${DATESTAMP}

			#echo "Begin processing of rebind @ $DATESTAMP ..." | tee -a $instance_home/maintenance/logs/runstats_${db}_${DATESTAMP}
			#db2 -txvf $REBIND_TMP_FILE	| tee -a $instance_home/maintenance/logs/runstats_${db}_${DATESTAMP}
			#echo "End processing of rebind  @ $DATESTAMP" | tee -a $instance_home/maintenance/logs/runstats_${db}_${DATESTAMP}
			rm $RUNSTATS_TMP_FILE
			#rm $REBIND_TMP_FILE
			db2 terminate
    	fi
	fi
done

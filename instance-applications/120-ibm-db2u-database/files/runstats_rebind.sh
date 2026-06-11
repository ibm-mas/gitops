#!/bin/bash
# ***************************************************************************
#	Author:  Fu Le Qing (Roking)
#	Email:	leqingfu@cn.ibm.com
#	Date:   10-31-2018
#
#	Description: This script updates statistics of tables,
# 				associated indexes in the database, and sends an email
#               to a specified email list.
#
# ********          THIS NEEDS TO BE RUN AS INSTANCE OWNER.   **************
#
#	Revision history:
#		10-31-2018      Fu Le Qing (Roking)
#			Original version
#		11-16-2018      Fu Le Qing (Roking)
#			Skip the tables which are ongoing with reorg
#		09-08-2023      Fu Le Qing (Roking)
#			Update for MAS
#
# ***************************************************************************
#
# ***************************************************************************

# -- Source the Props file 
if [ -f /mnt/backup/bin/.PROPS ]
then
    . /mnt/backup/bin/.PROPS
    DOW=`date | awk '{print $1}'`
    if [ ${DOW} != ${DAYOFFULL} ]
    then
		echo "Runstats runs only on Day of Full backup. . . !!! Exiting !"
        exit 0
    fi
fi

# -- Standard Parameters
INSTANCE=`whoami`
INSTANCE_HOME=`/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | grep "${INSTANCE}" | awk -F ',' '{print $5}'| sed 's/\/sqllib//'`
mkdir -p ${INSTANCE_HOME}/maintenance/logs
DATESTAMP=`date "+%Y-%m-%d-%H.%M.%S"`

pidfile="${INSTANCE_HOME}/.`basename ${0}`.pid"
if [ -e ${pidfile} ] && $kill -0 `cat ${pidfile}` 2>/dev/null
then
    exit 0
fi

echo $$ > ${pidfile}
trap "rm -f ${pidfile}; exit" SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM EXIT

if [ ! -f "${INSTANCE_HOME}/sqllib/db2profile" ]
then
   echo "ERROR - ${INSTANCE_HOME}/sqllib/db2profile not found"
   exit 1
else
   . ${INSTANCE_HOME}/sqllib/db2profile
fi

# -- Debug Mode 
# set -x;       # Uncomment to debug this shell script
# set -n;       # Uncomment to check your syntax, without execution.

RUNSTATS_TMP_FILE="${INSTANCE_HOME}/bin/.runstats.sql"
REBIND_TMP_FILE="${INSTANCE_HOME}/bin/.rebind.sql"

for DB in `db2 list db directory | grep -B 5 Indirect | grep "Database name" | cut -d= -f2`
do
	RUNSTATS_REBIND_LOG="${INSTANCE_HOME}/maintenance/logs/runstats_rebind_${DB}_${DATESTAMP}.log"

	role=`db2 get db cfg for ${DB} | grep "HADR database role" | cut -d= -f2 |sed 's/ //g'`
	if [ "$role" != "STANDBY" ]; then
		if [[ -f ${RUNSTATS_TMP_FILE} ]]; then
			rm ${RUNSTATS_TMP_FILE}
		fi
		if [[ -f ${REBIND_TMP_FILE} ]]; then
			rm ${REBIND_TMP_FILE}
		fi

		db2 connect to ${DB} | tee ${RUNSTATS_REBIND_LOG}
		if [[ $? -eq 0 ]]; then
			db2 -x "select 'RUNSTATS ON TABLE \"' ||rtrim(tab.tabschema)||'\".\"'|| tab.tabname ||'\" ON ALL COLUMNS WITH DISTRIBUTION ON ALL COLUMNS AND DETAILED INDEXES ALL ALLOW WRITE ACCESS;' from syscat.tables tab left join sysibmadm.SNAPTAB_REORG reg on tab.tabschema=reg.TABSCHEMA and tab.tabname=reg.TABNAME and reg.REORG_STATUS not in ('COMPLETED','STOPPED') where tab.type='T' and reg.tabname is null" > ${RUNSTATS_TMP_FILE}
			
			echo -e "Begin processing of runstats @ ${DATESTAMP} ...\n" | tee -a ${RUNSTATS_REBIND_LOG}
			db2 -txvf ${RUNSTATS_TMP_FILE} | tee -a ${RUNSTATS_REBIND_LOG}
			echo -e "\nEnd processing of runstats @ ${DATESTAMP}" | tee -a ${RUNSTATS_REBIND_LOG}
			rm ${RUNSTATS_TMP_FILE}
	
			db2 -x "select 'rebind package \"' ||rtrim(PKGSCHEMA)||'\".\"'|| PKGNAME ||'\";' from syscat.packages where PKGSCHEMA not like 'SYSIBM%' and PKGSCHEMA not like 'NULL%' " > ${REBIND_TMP_FILE}
				
			echo -e "\n ----------------------------------------------- " | tee -a ${RUNSTATS_REBIND_LOG}
			echo -e "Begin processing of rebind @ ${DATESTAMP} ...\n" | tee -a ${RUNSTATS_REBIND_LOG}
			db2 -txvf ${REBIND_TMP_FILE} | tee -a ${RUNSTATS_REBIND_LOG}
			echo -e "\nEnd processing of rebind @ ${DATESTAMP}" | tee -a ${RUNSTATS_REBIND_LOG}
				
			rm ${REBIND_TMP_FILE}
			db2 terminate
		fi
	fi
done

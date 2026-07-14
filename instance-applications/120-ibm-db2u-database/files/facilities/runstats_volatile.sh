#!/bin/bash
# ***************************************************************************
#       Author:  Sakshi Singhroha
#       Date:   2026-06-23
#
#       Description: This script updates statistics for volatile tables
#                    (WF_EVENT and EF_QUEUE) that change frequently.
#                    Should run every 10 minutes.
#
# ********          THIS NEEDS TO BE RUN AS INSTANCE OWNER.   **************
#
#       Based on: MASCORE-10348 - DB2 runstats required on MREF databases
#
# ***************************************************************************

instance=`whoami`
instance_home=`/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | grep "${instance}" | awk -F ',' '{print $5}'| sed 's/\/sqllib//'`

pidfile="$instance_home/.`basename ${0}`.pid"
if [ -e ${pidfile} ] && kill -0 `cat ${pidfile}` 2>/dev/null 
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

mkdir -p $instance_home/maintenance/logs
DATESTAMP=`date "+%Y-%m-%d-%H.%M.%S"`

# Database and schema configuration
DATABASE="BLUDB"
SCHEMA="TRIDATA"

# Loop through all databases (in case there are multiple)
for db in `db2 list db directory | grep -B 5 Indirect | grep "Database name" | cut -d= -f2`
do
    # Check HADR role - only run on PRIMARY, skip STANDBY
    role=`db2 get db cfg for ${db} | grep "HADR database role" | cut -d= -f2 |sed 's/ //g'`
    if [ "$role" != "STANDBY" ]; then
        echo "Running volatile RUNSTATS on ${db} @ $DATESTAMP" | tee $instance_home/maintenance/logs/runstats_volatile_${db}_${DATESTAMP}
        
        db2 connect to ${db} | tee -a $instance_home/maintenance/logs/runstats_volatile_${db}_${DATESTAMP}
        if [ $? -eq 0 ]; then
            # RUNSTATS on WF_EVENT table
            echo "RUNSTATS ON TABLE ${SCHEMA}.WF_EVENT..." | tee -a $instance_home/maintenance/logs/runstats_volatile_${db}_${DATESTAMP}
            db2 "RUNSTATS ON TABLE ${SCHEMA}.WF_EVENT WITH DISTRIBUTION AND DETAILED INDEXES ALL ALLOW WRITE ACCESS" | tee -a $instance_home/maintenance/logs/runstats_volatile_${db}_${DATESTAMP}
            db2 "COMMIT" | tee -a $instance_home/maintenance/logs/runstats_volatile_${db}_${DATESTAMP}
            
            # RUNSTATS on EF_QUEUE table
            echo "RUNSTATS ON TABLE ${SCHEMA}.EF_QUEUE..." | tee -a $instance_home/maintenance/logs/runstats_volatile_${db}_${DATESTAMP}
            db2 "RUNSTATS ON TABLE ${SCHEMA}.EF_QUEUE WITH DISTRIBUTION AND DETAILED INDEXES ALL ALLOW WRITE ACCESS" | tee -a $instance_home/maintenance/logs/runstats_volatile_${db}_${DATESTAMP}
            db2 "COMMIT" | tee -a $instance_home/maintenance/logs/runstats_volatile_${db}_${DATESTAMP}
            
            db2 terminate
            echo "Completed volatile RUNSTATS on ${db} @ $DATESTAMP" | tee -a $instance_home/maintenance/logs/runstats_volatile_${db}_${DATESTAMP}
        fi
    else
        echo "Skipping ${db} - HADR role is STANDBY" | tee $instance_home/maintenance/logs/runstats_volatile_${db}_${DATESTAMP}
    fi
done

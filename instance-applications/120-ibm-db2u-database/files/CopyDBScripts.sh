#!/bin/bash

# Finding the Instance owner
INSTOWNER=`/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | awk -F ',' '{print $4}' `

# Finding Instnace owner Group
GRPID=`cat /etc/passwd | grep ${INSTOWNER} | cut -d: -f4`
INSTGROUP=`cat /etc/group | grep ${GRPID} | cut -d: -f1`

# Find the home directory
INSTHOME=` cat /etc/passwd | grep ${INSTOWNER} | cut -d: -f6`

# Resolving INSTOWNER's executables path (sqllib):
DBPATH=`/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | grep "${INSTOWNER}" | awk -F ',' '{print $5}' `

# Source the db2profile for the root user to be able to issue several db2 commands locally:
SOURCEPATH="$DBPATH/db2profile"
. $SOURCEPATH

cd /tmp/db2-scripts/

echo -e "\nCopying the files to bin directory under Instance Home . . . "
cp -rp .Prompt ${INSTHOME}/
cp -rp CheckCOS.sh ${INSTHOME}/bin/
cp -rp DB2_Backup.sh ${INSTHOME}/bin/
cp -rp Run_Backup.sh ${INSTHOME}/bin/
cp -rp RUNEXPORT.sh ${INSTHOME}/bin/
cp -rp Explain.ddl ${INSTHOME}/bin/
cp -rp RUN_OnDemandFULL_BKP.sh ${INSTHOME}/bin/
cp -rp runstats_rebind.sh ${INSTHOME}/bin/
cp -rp CreateRoles.sh ${INSTHOME}/bin/
cp -rp grant_check.sh ${INSTHOME}/bin/
cp -rp PostMaint.sh ${INSTHOME}/bin/
cp -rp reorgTablesIndexesInplace2.sh ${INSTHOME}/bin/
cp -rp extract_authorization.sh  ${INSTHOME}/bin
cp -rp HADRMON.sh ${INSTHOME}/bin

echo -e "\nCopying the file to bin/ITCS104 directory under Instance Home . . ."
# cp -rp db2shc ${INSTHOME}/bin/ITCS104/
cp -rp db2shc.cfg ${INSTHOME}/bin/ITCS104/
cp -rp FixInvalidObjects.sh ${INSTHOME}/bin/ITCS104/
cp -rp Build_remediat_Script.sh ${INSTHOME}/bin/ITCS104/
cp -rp RunCompliance.sh ${INSTHOME}/bin/ITCS104/

echo -e "\nCopying files to /mnt/backup/bin directory . . .";
sudo cp -rp cronRunBKP.sh  /mnt/backup/bin/
sudo chown db2uadm:wheel /mnt/backup/bin/cronRunBKP.sh

echo -e "\nCopying files to Managed directory under Instance Home . . .";
cp -rp Set_DB_COS_Storage.sh ${INSTHOME}/Managed/
cp -rp Reg-Large_TBSP.sh ${INSTHOME}/Managed/
cp HADR_config_primary.txt ${INSTHOME}/Managed
cp PostBackFlow.sh ${INSTHOME}/Managed
cp OwnerCheck.txt ${INSTHOME}/Managed

echo -e "\nCopying files to maintenance directory under Instance Home . . . ";
cp -rp reorgTablesIndexesInplace2_maintenance.sh ${INSTHOME}/maintenance/reorgTablesIndexesInplace2.sh
if [ ! -d ${INSTHOME}/maintenance/logs ] ; then
    mkdir -p ${INSTHOME}/maintenance/logs
    echo "${DATETIME}:Creating directory ${INSTHOME}/maintenance/logs"
   if [ $? != "0" ] ; then
        echo "${DATETIME}: ERROR: Unable to create directory ${INSTHOME}/maintenance/logs"
        exit 1
   fi
fi

sudo chown -R ${INSTOWNER}:${INSTGROUP} ${INSTHOME}/bin
sudo chown -R ${INSTOWNER}:${INSTGROUP} ${INSTHOME}/maintenance
sudo chown -R ${INSTOWNER}:${INSTGROUP} ${INSTHOME}/Managed
#!/bin/bash
# ***************************************************************************
#
#	Author			: Prudhviraj P
#	Email			: prudhvirajp@ibm.com
#	Date			: 15-11-2024
#	Description		: Script to drop TEMPTS and associated tablespaces and 
#					    recreate tablespaces with IBM default storage group
#		
# ***************   THIS NEEDS TO BE RUN AS INSTANCE OWNER    ***************
#
#   Revision history:
#       15-11-2024      Prudhviraj P
#           Original version
#               
# ***************************************************************************
#	USAGE	:
#				dropTempts.sh 
#
# ***************************************************************************

# -- ** DEBUG MODE **
# set -x            -- Enabling Debugging Mode
# set -n            -- To verify syntax errors

# -- Script Execution starts here

ST=$(date +%s)

# -- Declaring Parameters
DBNAME="BLUDB"
TMPSQL="/tmp/droprecreatetbsp.sql"

# -- Invoking DB2 Profile

INST=`/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | awk -F, '{print $4}'`
INSTHOME=`/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | grep "${INST}" | awk -F ',' '{print $5}'| cut -d/ -f 1,2,3`

. ${INSTHOME}/sqllib/db2profile

# -- Validate the DB is cataloged

DBS=`db2 list db directory | grep -E "Database alias" | awk -F '= ' '{print $2}'`

if grep -qw "${DBNAME}" <<< "${DBS}" ; then

    continue;
else
    echo "${DBNAME} is Not CATALOGED or Not FOUND!!!"
    exit 1;
fi

# -- Generate the Script for TEMPTS removal and recreate tabespaces

db2 "CONNECT TO ${DBNAME}" > /dev/null

TMPSTG=`db2 -x "SELECT VARCHAR(STORAGE_GROUP_NAME,20) FROM TABLE(ADMIN_GET_STORAGE_PATHS('',-1)) AS T WHERE STORAGE_GROUP_NAME like 'IBMDB2U%'" `	
TMPTBS=`db2 -x "SELECT VARCHAR(TBSP_NAME,30) FROM table (MON_GET_TABLESPACE('', -2)) WHERE TBSP_CONTENT_TYPE IN ('USRTEMP','SYSTEMP') and STORAGE_GROUP_NAME = '${TMPSTG}' " `
if [[ ! -z ${TMPSTG} ]]; then 

    echo "Tablespaces associated with \"${TMPSTG}\" in \"${DBNAME}\" ";
    db2 "SELECT char(TBSP_NAME,20) TBSP_NAME, char(STORAGE_GROUP_NAME,20) STORAGE_GROUP_NAME FROM table (MON_GET_TABLESPACE('', -2)) WHERE TBSP_USING_AUTO_STORAGE = 1 AND TBSP_CONTENT_TYPE IN ('ANY','LARGE', 'USRTEMP','SYSTEMP') ORDER BY STORAGE_GROUP_NAME"

    echo "CONNECT TO ${DBNAME};" > ${TMPSQL}
    for TS in ${TMPTBS} ; do

        echo "DROP TABLESPACE \"${TS}\";" >> ${TMPSQL}
        echo "CREATE TEMPORARY TABLESPACE \"${TS}\" IN DATABASE PARTITION GROUP IBMTEMPGROUP MANAGED BY AUTOMATIC STORAGE USING STOGROUP \"IBMSTOGROUP\" ;" >> ${TMPSQL}

    done

    echo "DROP STOGROUP \"${TMPSTG}\"; " >> ${TMPSQL}
    echo "COMMIT WORK; " >> ${TMPSQL}
    echo "CONNECT RESET; " >> ${TMPSQL}
    echo "TERMINATE; " >> ${TMPSQL}
else
    echo "NO TEMP STORAGE Found. Exiting . . . " ;
    exit 1;
fi
db2 "CONNECT RESET" > /dev/null

# -- Execute the script to drop and recreate the TEMPTS and tablespaces

db2 -tvf ${TMPSQL} -z ${TMPSQL}.log

rm -rf ${TMPSQL} 

db2 "CONNECT TO ${DBNAME}" > /dev/null
echo "After removing TEMPTS \"${TMPSTG}\" from \"${DBNAME}\""
db2 "SELECT char(TBSP_NAME,20) TBSP_NAME, char(STORAGE_GROUP_NAME,20) STORAGE_GROUP_NAME FROM table (MON_GET_TABLESPACE('', -2)) WHERE TBSP_USING_AUTO_STORAGE = 1 AND TBSP_CONTENT_TYPE IN ('ANY','LARGE', 'USRTEMP','SYSTEMP') ORDER BY STORAGE_GROUP_NAME"
db2 "CONNECT RESET" > /dev/null

# -- END of PROCESSING

ET=$(date +%s)
ELT=$((ET - ST))
((sec=ELT%60, ELT/=60, min=ELT%60, hrs=ELT/60))
DURATION=$(printf "Total Execution Time - %d Hrs : %d Mins : %d Secs" $hrs $min $sec)
echo -e "\n$DURATION" 

# -- END OF SCRIPT


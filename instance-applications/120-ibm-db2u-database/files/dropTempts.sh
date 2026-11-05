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
#       21-08-2026      Prudhviraj P
#           Looping through all databases and tablespaces associated to it
#               
# ***************************************************************************
#	USAGE	:
#				dropTempts.sh 
#
# ***************************************************************************

# -- Script Execution starts here

ST=$(date +%s)

# -- Declaring Parameters
TMPSQL="/tmp/droprecreatetbsp.sql"

# -- Invoking DB2 Profile

INSTNAME=$(/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | awk -F, '{print $4}')
INSTHOME=$(/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | grep "${INSTNAME}" | awk -F ',' '{print $5}'| sed 's/\/sqllib//')

. ${INSTHOME}/sqllib/db2profile

# -- ** DEBUG MODE **
# set -x            -- Enabling Debugging Mode
# set -n            -- To verify syntax errors

# -- Validate the DB is cataloged

DBS=$(db2 list db directory | grep -E "Database alias" | awk -F '= ' '{print $2}')

for DBNAME in "${DBS}" ; do 
    # -- Generate the Script for TEMPTS

    db2 "CONNECT TO ${DBNAME}" > /dev/null

    TMPSTG=$( db2 -x "SELECT VARCHAR(STORAGE_GROUP_NAME, 30) AS STOGROUP FROM TABLE(ADMIN_GET_STORAGE_PATHS('',-1)) AS T WHERE STORAGE_GROUP_NAME like 'IBMDB2U%'" | sed 's/[[:space:]]*$//' )
    TMPTBS=$( db2 -x "SELECT varchar(TBSP_NAME,20) TBSP_NAME FROM table (MON_GET_TABLESPACE('', -2)) WHERE TBSP_CONTENT_TYPE IN ('USRTEMP','SYSTEMP') and STORAGE_GROUP_NAME IN '${TMPSTG}' " | sed 's/[[:space:]]*$//' )
    if [[ ! -z ${TMPSTG} ]]; then 

        echo "Tablespaces associated with \"${TMPSTG}\" ";
        db2 "SELECT char(TBSP_NAME,20) TBSP_NAME, char(STORAGE_GROUP_NAME,20) STORAGE_GROUP_NAME FROM table (MON_GET_TABLESPACE('', -2)) WHERE TBSP_USING_AUTO_STORAGE = 1 AND TBSP_CONTENT_TYPE IN ('ANY','LARGE', 'USRTEMP','SYSTEMP') ORDER BY STORAGE_GROUP_NAME"

        echo "CONNECT TO ${DBNAME};" > ${TMPSQL}
        for TS in "${TMPTBS}" ; do

            echo "DROP TABLESPACE \"${TS}\";" >> ${TMPSQL}
            echo "CREATE TEMPORARY TABLESPACE \"${TS}\" IN DATABASE PARTITION GROUP IBMTEMPGROUP MANAGED BY AUTOMATIC STORAGE USING STOGROUP \"IBMSTOGROUP\" ;" >> ${TMPSQL}

        done

        echo -e "DROP STOGROUP \"${TMPSTG}\"; \nCOMMIT WORK; \nCONNECT RESET;  \nTERMINATE; " >> ${TMPSQL}
    else
        echo "NO TEMP STORAGE Found. Exiting . . . " ;
        #exit 1;
    fi
    db2 "CONNECT RESET" > /dev/null

done

# -- Execute the script to drop and recreate the TEMPTS and tablespaces

db2 -tvf ${TMPSQL} -z ${TMPSQL}.log
rm -rf ${TMPSQL} 

db2 "CONNECT TO ${DBNAME}" > /dev/null 
echo "After removing TEMPTS \"${TMPSTG}\" from \"${DBNAME}\""
db2 "SELECT char(TBSP_NAME,20) TBSP_NAME, char(STORAGE_GROUP_NAME,20) STORAGE_GROUP_NAME FROM table (MON_GET_TABLESPACE('', -2)) WHERE TBSP_USING_AUTO_STORAGE = 1 AND TBSP_CONTENT_TYPE IN ('ANY','LARGE', 'USRTEMP','SYSTEMP') ORDER BY STORAGE_GROUP_NAME"
db2 "CONNECT RESET" > /dev/null

# -- END OF SCRIPT


#!/bin/bash
##   CreateRoles.sh
################################################################################
#
#   Usage:   ./CreateRoles.sh <SCHEMA NAME>
#
#   Arguments:
#     $1 - Schema name to create roles for (required)
#          e.g. ./CreateRoles.sh MAXIMO   (for Manage DB2)
#               ./CreateRoles.sh TRIRIGA  (for Facilities DB2)
#
################################################################################

##Possibly need to grant the following on the non flex databases
##  db2 "grant execute on package nullid.SQLC2K26 to role maximo_read"
##  db2 "GRANT USAGE ON WORKLOAD SYSDEFAULTUSERWORKLOAD role maximo_read"
##  db2 "grant execute on package nullid.SYSSH200 to role maximo_read"
##  db2 grant select on syscat.schemata to role maximo_read
##  db2 grant select on syscat.tables to role maximo_read
##  db2 grant select on syscat.indexes to role maximo_read
##  db2 grant select on syscat.columns to role maximo_read

#set -x

db2 connect to bludb

DATETIME=`date +%Y%m%d_%H%M%S`;

for SCHEMANAME in $1
do
ROLES=`db2 -x "select char(ROLENAME,30) as ROLENAME from syscat.roles"`
ROLE="${SCHEMANAME}_read"
echo "" > temp
if ! grep -iqw "${ROLE}" <<< "${ROLES}" ; then
    echo "create role ${SCHEMANAME}_read;"  > temp
fi
USER=${SCHEMANAME}_READ
WRITE=${SCHEMANAME}_WRITE

db2 "select
'GRANT SELECT ON TABLE '||
RTRIM(TABSCHEMA) || '.\"' || RTRIM(tabname)||'\" TO ROLE ${USER};'
from
syscat.tables
where tabschema = '${SCHEMANAME}'" >> temp


db2 "select
'GRANT SELECT ON table  '||
RTRIM(viewSCHEMA) || '.' || RTRIM(viewname)||' TO ROLE ${USER};'
from
syscat.views
where viewschema = '${SCHEMANAME}'" >> temp
echo "grant selectin on schema ${SCHEMANAME} to role ${USER};" >> temp



cat temp        | grep -i ${SCHEMANAME}_read > ${USER}.sql
rm temp
echo "GRANT CONNECT ON DATABASE TO ROLE ${USER};" >>${USER}.sql
#echo "GRANT USE OF TABLESPACE MAXDATA TO ROLE ${USER};" >> ${USER}.sql
db2 -tvf ${USER}.sql > ${USER}_${DATETIME}.out

echo "" > temp
ROLE="${SCHEMANAME}_write"
if ! grep -iqw "${ROLE}" <<< "${ROLES}" ; then
    echo "create role ${SCHEMANAME}_write;"  > temp
fi
echo "grant updatein on schema ${SCHEMANAME} to role ${WRITE};" >> temp
echo "grant deletein on schema ${SCHEMANAME} to role ${WRITE};"  >> temp
echo "grant insertin on schema ${SCHEMANAME} to role ${WRITE};" >> temp
echo "grant selectin on schema ${SCHEMANAME} to role ${WRITE};" >> temp

db2 "select
'GRANT SELECT, insert, update, delete ON TABLE '||
RTRIM(TABSCHEMA) || '.\"' || RTRIM(tabname)||'\" TO ROLE ${WRITE};'
from
syscat.tables
where tabschema = '${SCHEMANAME}'" >> temp




cat temp         | grep -i ${SCHEMANAME}_write > ${WRITE}.sql
rm temp
echo "GRANT CONNECT ON DATABASE TO ROLE ${WRITE};" >>${WRITE}.sql
#echo "GRANT USE OF TABLESPACE MAXDATA TO ROLE ${WRITE};" >> ${WRITE}.sql

# _SEQ role is only created for MAXIMO (Manage) - not required for TRIDATA (Facilities)
if [[ "${SCHEMANAME}" != "TRIDATA" ]]; then
echo "" > temp
ROLE="${SCHEMANAME}_SEQ"
if ! grep -iqw "${ROLE}" <<< "${ROLES}" ; then
    echo "create role ${SCHEMANAME}_SEQ;"  > temp
fi
USER=${SCHEMANAME}_SEQ


db2 "select
'GRANT USAGE ON SEQUENCE '||
RTRIM(SEQSCHEMA) || '.\"' || RTRIM(SEQNAME)||'\" TO ROLE ${USER};'
from syscat.sequences where seqschema = '${SCHEMANAME}'" >> temp

cat temp        | grep -i ${USER}  > ${USER}.sql
rm temp
echo "GRANT CONNECT ON DATABASE TO ROLE ${USER};" >>${USER}.sql


db2 -tvf ${USER}.sql > ${USER}_${DATETIME}.out
fi
db2 -tvf ${WRITE}.sql > ${WRITE}_${DATETIME}.out
done

ROLES=`db2 -x "select char(ROLENAME,30) as ROLENAME from syscat.roles"`
echo "Creating the EXPLAIN ROLE"
ROLE="EXPLAIN"
if grep -iqw "${ROLE}" <<< "${ROLES}" ; then

    echo "${ROLE} is already present in the database ${DBNAME}"; 
    exit 1;
else
    echo "${ROLE} is Not FOUND, proceeding with creating the role "
    db2 -tvf Explain.ddl
fi


db2 terminate

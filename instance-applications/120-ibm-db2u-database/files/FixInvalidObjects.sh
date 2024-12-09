#!/bin/bash
################################################################################
# To be run as the instance owner of the database
#
#
################################################################################

DATETIME=`date +%Y%m%d_%H%M%S`;
DBNAME=BLUDB

db2 connect to ${DBNAME}

echo " all invalid objects"
db2 "SELECT substr(objectschema,1,20) objectschema, substr(objectname,1,30) objectname, routinename, objecttype FROM syscat.invalidobjects"

db2 "select 'CALL SYSPROC.ADMIN_REVALIDATE_DB_OBJECTS(NULL, ''' || OBJECTSCHEMA ||''', NULL);' from SYSCAT.INVALIDOBJECTS group by objectschema" > FixObjects.sql
cat FixObjects.sql | grep CALL > TEMP
mv TEMP FixObjects.sql
db2 -tvf FixObjects.sql

echo "checking again for invalid objects (query should return zero resluts"

db2 "SELECT substr(objectschema,1,20) objectschema, substr(objectname,1,30) objectname, routinename, objecttype FROM syscat.invalidobjects"

db2 connect reset

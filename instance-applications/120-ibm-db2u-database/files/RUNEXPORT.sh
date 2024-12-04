#!/bin/bash
################################################################################
# THIS NEEDS TO BE RUN AS INSTANCE OWNER.
################################################################################
instance=`whoami`
instance_home=`/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | grep "${instance}" | awk -F ',' '{print $5}'| cut -d/ -f 1,2,3`
if [ -f "$instance_home/sqllib/db2profile" ]
then
   . $instance_home/sqllib/db2profile
fi
if [ -s "$instance_home/Scripts/.PROPS" ]
then
   . $instance_home/Scripts/.PROPS
fi
db=BLUDB
DATETIME=`date +%Y%m%d_%H%M%S`

if [ ! -d  /mnt/backup/db2inst1/Exports ]
 then
 mkdir -p /mnt/backup/db2inst1/Exports
fi

   export_path=/mnt/backup/db2inst1/Exports
mkdir -p ${export_path}/${db}_${DATETIME}
cd ${export_path}/${db}_${DATETIME}
db2move $db export -l ./lobs/
db2look -d $db -e -l -x -o $db.ddl
cd ..
zip -r -q -o ${db}_${DATETIME}.zip ./${db}_${DATETIME}
echo -e "All of the files are saved under folder ${export_path}/${db}_${DATETIME} and compressed into file ${export_path}/${db}_${DATETIME}.zip. \nPlease remember to remove folder ${export_path}/${db}_${DATETIME} if it's not needed any more."

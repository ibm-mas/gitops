#!/bin/bash


DBNAME=bludb

echo "###  Set parameters based on Maximo best practices  ###"
db2 update db cfg for ${DBNAME} using LOGPRIMARY 100
db2 update db cfg for ${DBNAME} using LOGSECOND 156
db2 update db cfg for ${DBNAME} using LOGFILSIZ 32768
db2 update db cfg for ${DBNAME} using MIRRORLOGPATH /mnt/backup/MIRRORLOGPATH
db2 update db cfg for ${DBNAME} using NUM_DB_BACKUPS 60
db2 update db cfg for ${DBNAME} using LOGARCHCOMPR1 ON
db2 update db cfg for ${DBNAME} using REC_HIS_RETENTN 60
db2 update db cfg for ${DBNAME} using AUTO_DEL_REC_OBJ ON
db2 update db cfg for ${DBNAME} using TRACKMOD YES
db2 update db cfg for ${DBNAME} using DDL_CONSTRAINT_DEF ON
db2 update db cfg for ${DBNAME} using AUTO_DB_BACKUP OFF
db2 update db cfg for ${DBNAME} using STMT_CONC LITERALS

echo "###  set the tmp backup location   ###"
db2set DB2_OBJECT_STORAGE_LOCAL_STAGING_PATH=/mnt/backup/staging
echo "###  Enable PIT recovery  ###"
db2set DB2_CDE_REDUCED_LOGGING=REDUCED_REDO:NO


db2stop force;
ipclean;
db2start;


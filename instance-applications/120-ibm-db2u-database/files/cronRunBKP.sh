#!/bin/bash
set -x

date
DATETIME=`date +%Y-%m-%d_%H%M%S`;
export COSBACKUPBUCKET=$1
export CUSTNAME=$2
export CUSTNAME="Please Set"
sudo -E -u db2inst1 echo "${COSBACKUPBUCKET}, ${CUSTNAME}, ${DATETIME}" >> /mnt/backup/bin/Bucket
		#sudo --preserve-env=COSBACKUPBUCKET -u db2inst1 /mnt/blumeta0/home/db2inst1/bin/Run_Backup.sh
sudo -E -u db2inst1 /mnt/blumeta0/home/db2inst1/bin/Run_Backup.sh
date

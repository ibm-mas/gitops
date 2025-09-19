
INSTOWNER=`/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | awk -F ',' '{print $4}' `
# Resolving the Administration Server owner:

# Find the home directory
INSTHOME=` cat /etc/passwd | grep ${INSTOWNER} | cut -d: -f6`

DEST_USER=`db2 list applications show detail | cut -d" " -f1 | grep -v DB2INST1 | grep -v CTGINST1 | grep -v CONNECT |grep MANA  | grep -v "\-\-" |grep -v MONITOR | sort -n | uniq | tail -1`
SCRIPT=/mnt/backup/bin/PostBF_Scripts.sh

    echo "db2 connect to bludb" > ${SCRIPT}
    echo "db2 GRANT DBADM,CREATETAB,BINDADD,CONNECT,CREATE_NOT_FENCED_ROUTINE,IMPLICIT_SCHEMA,LOAD,CREATE_EXTERNAL_ROUTINE,QUIESCE_CONNECT ON DATABASE TO USER ${DEST_USER}" >> ${SCRIPT}
    echo "db2 GRANT USE OF TABLESPACE MAXDATA TO USER ${DEST_USER}" >> ${SCRIPT}
    echo "db2 GRANT DBADM WITHOUT DATAACCESS WITHOUT ACCESSCTRL ON DATABASE  TO USER ${DEST_USER}" >> ${SCRIPT}
    echo "db2 GRANT SECADM ON DATABASE  TO USER ${DEST_USER}" >> ${SCRIPT}
    echo "db2 GRANT DATAACCESS ON DATABASE  TO USER ${DEST_USER} " >> ${SCRIPT}
    echo "db2 GRANT ACCESSCTRL ON DATABASE  TO USER ${DEST_USER}" >> ${SCRIPT}
    echo "db2 GRANT ACCESSCTRL ON DATABASE  TO USER ${DEST_USER} " >> ${SCRIPT}

### Update KAFKA
  echo "db2 \"update maximo.MSGHUBPROVIDERCFG set PROPVALUE=null where propname='BOOTSTRAPSERVERS' and provider='KAFKA'\" " >> ${SCRIPT}
  echo "db2 \"update maximo.MSGHUBPROVIDERCFG set PROPVALUE=null where propname='PASSWORD' and provider='KAFKA'\" "  >> ${SCRIPT}
  echo "db2 \"commit\" " >> ${SCRIPT}
  echo "  "
  echo "  " 

  echo "db2set db2comm=tcpip,ssl" >> ${SCRIPT}
  echo "db2stop force ; ipclean ; db2start" >> ${SCRIPT}


chmod 755 ${SCRIPT}

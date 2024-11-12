. /mnt/backup/bin/.PROPS

echo " "
echo "        ##### BUCKET = ${CONTAINER} #####"
echo " " 


. /mnt/backup/bin/.PROPS

DB2V=`db2level | grep Inform | awk '{print $5}' | sed 's/",//'`
    if [ ${DB2V} = "v11.5.7.0" ]
     then

        db2RemStgManager S3 list server=${SERVER} auth1=${PARM1} auth2=${PARM2} container=${CONTAINER}
    else
        db2RemStgManager ALIAS LIST source=DB2REMOTE://AWSCOS//
    fi


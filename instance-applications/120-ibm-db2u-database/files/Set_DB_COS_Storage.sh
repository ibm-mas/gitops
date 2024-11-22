. /mnt/backup/bin/.PROPS
if db2 list storage access | grep AWSCOS; then
    echo "AWSCOS is available already."
else
    echo "AWSCOS is not available. Creating"
    db2 catalog storage access alias AWSCOS VENDOR S3 server ${SERVER} user ${PARM1} password ${PARM2} container ${CONTAINER}
fi
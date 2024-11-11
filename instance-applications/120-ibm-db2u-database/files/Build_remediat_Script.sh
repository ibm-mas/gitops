echo "create role COLLECTIVE;" > Rem.sql
FILE=NOTSET-db2-c-db2wh-*.info

echo "GRANT ROLE COLLECTIVE TO USER DB2GSE; " >> Rem.sql
echo "GRANT ROLE COLLECTIVE TO USER MAXIMO; " >> Rem.sql
echo "GRANT ROLE COLLECTIVE TO USER BLU_CONNECT_NORMAL; " >> Rem.sql                                                                                                       
echo "GRANT ROLE COLLECTIVE TO USER BLU_CONNECT_TRUSTED;  " >> Rem.sql                                                                                                     
echo "GRANT ROLE COLLECTIVE TO USER DASHDB_ENTERPRISE_ADMIN; " >> Rem.sql                                                                                                  
echo "GRANT ROLE COLLECTIVE TO USER DASHDB_ENTERPRISE_USER;         " >> Rem.sql                                                                                           
echo "GRANT ROLE COLLECTIVE TO USER SCANIAPRODMANAGEDB; " >> Rem.sql
echo "GRANT ROLE COLLECTIVE TO USER ST_INFORMTN_SCHEMA;" >> Rem.sql
echo "GRANT ROLE COLLECTIVE TO USER DB2GSE; " >> Rem.sql
echo "GRANT ROLE COLLECTIVE TO USER NULLIDRA; " >> Rem.sql
echo "GRANT ROLE COLLECTIVE TO USER NULLIDR1; " >> Rem.sql
echo "GRANT ROLE COLLECTIVE TO USER NULLID; " >> Rem.sql
echo "GRANT ROLE COLLECTIVE TO USER BLUADMIN_MON;" >> Rem.sql
echo "GRANT ROLE COLLECTIVE TO USER DSADM;" >> Rem.sql
#echo "GRANT ROLE COLLECTIVE TO USER SCANIAPRODMANAGEDB;" >> Rem.sql



##### Get the Schema issues
grep VIOL ${FILE} | grep Schema | sed 's/|//g' | awk '{print "REVOKE " $4 " ON SCHEMA " $2 " from " $3 ";"}' | sed 's/Schema-//' >> Rem.sql
grep VIOL ${FILE} | grep Schema | sed 's/|//g' | awk '{print "GRANT " $4 " ON SCHEMA " $2 " TO ROLE COLLECTIVE;"}' | sed 's/Schema-//' >> Rem.sql

grep VIOL ${FILE} | grep SELECT | sed 's/|//g' | awk '{print "REVOKE " $4 " ON TABLE " $2 " from " $3 ";"}' >> Rem.sql
grep VIOL ${FILE} | grep SELECT| sed 's/|//g' | awk '{print "GRANT " $4 " ON TABLE " $2 " TO ROLE COLLECTIVE;"}' >> Rem.sql

db2 connect to bludb
db2 -tvf Rem.sql | tee .Rem.out
db2 connect reset

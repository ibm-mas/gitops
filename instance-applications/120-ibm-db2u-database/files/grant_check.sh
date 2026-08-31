#!/bin/bash
# ***************************************************************************
#       Author:  Fu Le Qing (Roking)
#		Email:	leqingfu@cn.ibm.com
#       Date:   11-28-2018
#
#       Description: This script check the privileges of role upon tables, 
# 					 grant the new tables to role, and sends an email 
#                    to a specified email list. 
#
# ********          THIS NEEDS TO BE RUN AS INSTANCE OWNER.   **************
#
#       Revision history:
#               11-28-2018      Fu Le Qing (Roking)
#                       Original version  
#               04-24-2019      Fu Le Qing (Roking)
#               Grant read-only role to the existing read user 
#               Grant read-write role to the existing write user  
#               05-05-2019      Fu Le Qing (Roking)
#               Grant usage on sequences to read role 
#               Grant alter on sequences to write role   
#               12-23-2019      Fu Le Qing (Roking)
#               Skip statistics view
#               02-28-2020      Fu Le Qing (Roking)
#               Add blacklist: input table name into file blacklist without schema
#               05-13-2022      Fu Le Qing (Roking)
#               Skip alias
#               10-17-2023      Fu Le Qing (Roking)
#               Update for MAS
# ***************************************************************************
# run as below: 
# ./grant_check.sh database_name | tee -a .grant_check.out                              
# ***************************************************************************
instance=`whoami`
instance_home=`/usr/local/bin/db2greg -dump | grep -ae "I," | grep -v "/das," | grep "${instance}" | awk -F ',' '{print $5}'| sed 's/\/sqllib//'`

blacklist=$instance_home/Scripts/blacklist_grant

pidfile="$instance_home/.`basename ${0}`.pid"
if [ -e ${pidfile} ] && kill -0 `cat ${pidfile}` 2>/dev/null 
then
    exit 0
fi

echo $$ > ${pidfile}
trap "rm -f ${pidfile}; exit" SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM EXIT

if [ ! -f "$instance_home/sqllib/db2profile" ]
then   
   echo "ERROR - $instance_home/sqllib/db2profile not found"  
   EXIT_STATUS=1
else
   . $instance_home/sqllib/db2profile
fi

if [[ $# != 1 ]];then
        echo "Usage: command  database_name"
        exit
fi

GRANT_TEMP="/tmp/grant_temp.sql"
Mail_recp=$instance_home/CDS/Monitoring/bin/maildba.lst
if [[ -f $instance_home/Scripts/.PROPS ]]
then
	Server=`cat $instance_home/Scripts/.PROPS | grep CUSTNAME | cut -d= -f2`
else
	Server=`hostname`
fi
if [ ! -n "$Server" ];then
    Server=`hostname`
fi
IP=`hostname -i`

if [ -f $GRANT_TEMP ]
then 
	rm $GRANT_TEMP
fi 

instance_status=`db2gcf -s | grep  "Available" | wc -l`
if [[ "$instance_status" != "1" ]]
then
	DATETIME=`date +%Y-%m-%d_%H:%M:%S`
	echo "Time : ${DATETIME}  Instance is down!" | tee /tmp/.grant_mail
	#mail -s "Instance is down $Server $IP" `cat $Mail_recp` < /tmp/.grant_mail
	rm /tmp/.grant_mail
	exit
fi

role=`db2 get db cfg for  $1 | grep "HADR database role" | cut -d= -f2 |sed 's/ //g'`
if [ "$role" != "STANDBY" ]; then
	db2 connect to $1
	if [ $? -eq 0 ]; then
		schemalist=(`db2 connect to $1 >/dev/null;db2 -x "select SCHEMANAME from syscat.SCHEMATA where SCHEMANAME in ('MAXIMO','TRIDATA','TRIRIGADC')"`)
		i=0
		while [[ $i -lt ${#schemalist[*]} ]]
		do	
			role_read=`db2 connect to $1 >/dev/null;db2 -x "select count(*) from syscat.roles where rolename='${schemalist[$i]}_READ'" | sed 's/\.//'`	
			if [[ $role_read -eq 0 ]]
			then
				echo "create role ${schemalist[$i]}_READ;" >>$GRANT_TEMP
			fi

			role_write=`db2 connect to $1 >/dev/null;db2 -x "select count(*) from syscat.roles where rolename='${schemalist[$i]}_WRITE'" | sed 's/\.//'`	
			if [[ $role_write -eq 0 ]]
			then
				echo "create role ${schemalist[$i]}_WRITE;" >>$GRANT_TEMP	
			fi	

			db2 -x "select case when NOT exists(
			select 1
			from syscat.DBAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_READ' and auth.CONNECTAUTH='Y')
			then 'GRANT CONNECT ON DATABASE TO role ${schemalist[$i]}_READ;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP		

			#db2 -x "select case when NOT exists(
			#select 1
			#from syscat.DBAUTH auth
			#where auth.GRANTEE='${schemalist[$i]}_READ' and auth.BINDADDAUTH='Y')
			#then 'GRANT BINDADD ON DATABASE TO role ${schemalist[$i]}_READ;' 
			#else '--'
			#end
			#from sysibm.sysdummy1"	>>$GRANT_TEMP			

			#db2 -x "select case when NOT exists(
			#select 1
			#from syscat.SCHEMAAUTH auth
			#where auth.GRANTEE='${schemalist[$i]}_READ' and auth.CREATEINAUTH='Y')
			#then 'GRANT CREATEIN ON schema ${schemalist[$i]} TO role ${schemalist[$i]}_READ;' 
			#else '--'
			#end
			#from sysibm.sysdummy1"	>>$GRANT_TEMP		

			db2 -x "select case when NOT exists(
			select 1
			from syscat.WORKLOADAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_READ' and auth.USAGEAUTH='Y' and auth.WORKLOADNAME='SYSDEFAULTUSERWORKLOAD')
			then 'grant usage on workload sysdefaultuserworkload TO role ${schemalist[$i]}_READ;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP				

			db2 -x "select case when NOT exists(
			select 1
			from syscat.PACKAGEAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_READ' and auth.EXECUTEAUTH='Y' and auth.PKGNAME ='SYSSH200')
			then 'grant execute on package nullid.SYSSH200 to role ${schemalist[$i]}_READ;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP	

			db2 -x "select case when NOT exists(
			select 1
			from syscat.PACKAGEAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_READ' and auth.EXECUTEAUTH='Y' and auth.PKGNAME ='SQLC2O27')
			and exists(
			select 1
			from syscat.packages where PKGNAME ='SQLC2O27'		
			)
			then 'grant execute on package nullid.SQLC2O27 to role ${schemalist[$i]}_READ;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP	

			db2 -x "select case when NOT exists(
			select 1
			from syscat.PACKAGEAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_READ' and auth.EXECUTEAUTH='Y' and auth.PKGNAME ='SQLC2O28')
			and exists(
			select 1
			from syscat.packages where PKGNAME ='SQLC2O28'		
			)
			then 'grant execute on package nullid.SQLC2O28 to role ${schemalist[$i]}_READ;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP		

			db2 -x "select case when NOT exists(
			select 1
			from syscat.PACKAGEAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_READ' and auth.EXECUTEAUTH='Y' and auth.PKGNAME ='SYSSH100')
			then 'grant execute on package nullid.SYSSH100 to role ${schemalist[$i]}_READ;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP				

			db2 -x "select case when NOT exists(
			select 1
			from syscat.PACKAGEAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_READ' and auth.EXECUTEAUTH='Y' and auth.PKGNAME ='SQLC2K26') 
			and exists(
			select 1 from syscat.packages where PKGNAME='SQLC2K26'
			)
			then 'grant execute on package nullid.SQLC2K26 to role ${schemalist[$i]}_READ;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP	

			db2 -x "select 'GRANT USAGE ON SEQUENCE \"'|| rtrim(seq.SEQSCHEMA) ||'\".\"'|| rtrim(seq.SEQNAME) || '\" TO role ${schemalist[$i]}_READ;' 
			from syscat.sequences seq
			left join syscat.SEQUENCEAUTH auth on seq.SEQSCHEMA=auth.SEQSCHEMA and seq.SEQNAME=auth.SEQNAME
			and GRANTEE='${schemalist[$i]}_READ' and auth.USAGEAUTH='Y' and GRANTEETYPE='R'
			where seq.SEQSCHEMA='${schemalist[$i]}' and auth.SEQNAME is null" >>$GRANT_TEMP				

			db2 -x "select 'GRANT SELECT ON TABLE \"'|| rtrim(tab.tabschema) ||'\".\"'|| rtrim(tab.tabname) || '\" TO role ${schemalist[$i]}_READ;' 
			from syscat.tables tab
			left join syscat.tabauth auth on tab.TABSCHEMA=auth.TABSCHEMA and tab.TABNAME=auth.TABNAME
			and GRANTEE='${schemalist[$i]}_READ' and auth.SELECTAUTH='Y' and GRANTEETYPE='R'
			where tab.TABSCHEMA='SYSCAT' and tab.TABNAME in ('SCHEMATA','TABLES','INDEXES','COLUMNS') and auth.tabname is null" >>$GRANT_TEMP		

			if [ -s $blacklist ]
			then 
                typeset -u string_read
                for tab in `cat $blacklist`
                do
                    string_read+="'"$tab"',"
                done
                tables=`echo $string_read | sed 's/.$//'`
			    db2 -x "select 'GRANT SELECT ON TABLE \"'|| rtrim(tab.tabschema) ||'\".\"'|| rtrim(tab.tabname) || '\" TO role ${schemalist[$i]}_READ;' 
			    from syscat.tables tab
			    left join syscat.tabauth auth on tab.TABSCHEMA=auth.TABSCHEMA and tab.TABNAME=auth.TABNAME
			    and GRANTEE='${schemalist[$i]}_READ' and auth.SELECTAUTH='Y' and GRANTEETYPE='R'
			    where tab.tabschema='${schemalist[$i]}' and tab.type<>'A' and auth.tabname is null and SUBSTR(tab.PROPERTY,19,1) <>'Y' and tab.tabname not in ($tables)" >>$GRANT_TEMP	                			    
             for tab in `cat $blacklist`
                do
			        typeset -u table_name=$tab
                    db2 -x "select 'revoke SELECT ON TABLE \"'|| rtrim(tabschema) ||'\".\"'|| rtrim(tabname) || '\" from role ${schemalist[$i]}_READ;' 
			        from syscat.tabauth 
			        where GRANTEE='${schemalist[$i]}_READ' and SELECTAUTH='Y' and tabschema='${schemalist[$i]}' and tabname='$table_name'" >>$GRANT_TEMP	
			        db2 -x "select 'revoke insert ON TABLE \"'|| rtrim(tabschema) ||'\".\"'|| rtrim(tabname) || '\" from role ${schemalist[$i]}_READ;' 
			        from syscat.tabauth 
			        where GRANTEE='${schemalist[$i]}_READ' and INSERTAUTH='Y' and tabschema='${schemalist[$i]}' and tabname='$table_name'" >>$GRANT_TEMP	
			        db2 -x "select 'revoke update ON TABLE \"'|| rtrim(tabschema) ||'\".\"'|| rtrim(tabname) || '\" from role ${schemalist[$i]}_READ;' 
			        from syscat.tabauth 
			        where GRANTEE='${schemalist[$i]}_READ' and DELETEAUTH='Y' and tabschema='${schemalist[$i]}' and tabname='$table_name'" >>$GRANT_TEMP	
			        db2 -x "select 'revoke delete ON TABLE \"'|| rtrim(tabschema) ||'\".\"'|| rtrim(tabname) || '\" from role ${schemalist[$i]}_READ;' 
			        from syscat.tabauth 
			        where GRANTEE='${schemalist[$i]}_READ' and UPDATEAUTH='Y' and tabschema='${schemalist[$i]}' and tabname='$table_name'" >>$GRANT_TEMP	
                done
            else
			    db2 -x "select 'GRANT SELECT ON TABLE \"'|| rtrim(tab.tabschema) ||'\".\"'|| rtrim(tab.tabname) || '\" TO role ${schemalist[$i]}_READ;' 
			    from syscat.tables tab
			    left join syscat.tabauth auth on tab.TABSCHEMA=auth.TABSCHEMA and tab.TABNAME=auth.TABNAME
			    and GRANTEE='${schemalist[$i]}_READ' and auth.SELECTAUTH='Y' and GRANTEETYPE='R'
			    where tab.tabschema='${schemalist[$i]}' and tab.type<>'A' and auth.tabname is null and SUBSTR(tab.PROPERTY,19,1) <>'Y'" >>$GRANT_TEMP	
			fi 	

			####db2 -x "select distinct 'grant role ${schemalist[$i]}_READ to user ' ||tab.GRANTEE||';'
			####from SYSCAT.TABAUTH tab 
			####left join syscat.roleauth ro on tab.GRANTEE=ro.GRANTEE and ro.ROLENAME='${schemalist[$i]}_READ' 
			####where ro.rolename is null and tab.GRANTEETYPE='U' and tab.GRANTEE <>'${schemalist[$i]}_READ' and tab.SELECTAUTH='Y' and tab.TABSCHEMA='${schemalist[$i]}'" >>$GRANT_TEMP			

			db2 -x "select case when NOT exists(
			select 1
			from syscat.DBAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_WRITE' and auth.CONNECTAUTH='Y')
			then 'GRANT CONNECT ON DATABASE TO role ${schemalist[$i]}_WRITE;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP		

			db2 -x "select case when NOT exists(
			select 1
			from syscat.DBAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_WRITE' and auth.BINDADDAUTH='Y')
			then 'GRANT BINDADD ON DATABASE TO role ${schemalist[$i]}_WRITE;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP			

			db2 -x "select case when NOT exists(
			select 1
			from syscat.SCHEMAAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_WRITE' and auth.CREATEINAUTH='Y')
			then 'GRANT CREATEIN ON schema ${schemalist[$i]} TO role ${schemalist[$i]}_WRITE;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP		

			db2 -x "select case when NOT exists(
			select 1
			from syscat.WORKLOADAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_WRITE' and auth.USAGEAUTH='Y' and auth.WORKLOADNAME='SYSDEFAULTUSERWORKLOAD')
			then 'grant usage on workload sysdefaultuserworkload TO role ${schemalist[$i]}_WRITE;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP				

			db2 -x "select case when NOT exists(
			select 1
			from syscat.PACKAGEAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_WRITE' and auth.EXECUTEAUTH='Y' and auth.PKGNAME ='SYSSH200')
			then 'grant execute on package nullid.SYSSH200 to role ${schemalist[$i]}_WRITE;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP		

			db2 -x "select case when NOT exists(
			select 1
			from syscat.PACKAGEAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_WRITE' and auth.EXECUTEAUTH='Y' and auth.PKGNAME ='SQLC2O27')
			and exists(
			select 1
			from syscat.packages where PKGNAME ='SQLC2O27'		
			)		
			then 'grant execute on package nullid.SQLC2O27 to role ${schemalist[$i]}_WRITE;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP			

			db2 -x "select case when NOT exists(
			select 1
			from syscat.PACKAGEAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_WRITE' and auth.EXECUTEAUTH='Y' and auth.PKGNAME ='SQLC2O28')
			and exists(
			select 1
			from syscat.packages where PKGNAME ='SQLC2O28'		
			)		
			then 'grant execute on package nullid.SQLC2O28 to role ${schemalist[$i]}_WRITE;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP

			db2 -x "select case when NOT exists(
			select 1
			from syscat.PACKAGEAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_WRITE' and auth.EXECUTEAUTH='Y' and auth.PKGNAME ='SYSSH100')
			then 'grant execute on package nullid.SYSSH100 to role ${schemalist[$i]}_WRITE;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP				

			db2 -x "select case when NOT exists(
			select 1
			from syscat.PACKAGEAUTH auth
			where auth.GRANTEE='${schemalist[$i]}_WRITE' and auth.EXECUTEAUTH='Y' and auth.PKGNAME ='SQLC2K26') 
			and exists(
			select 1 from syscat.packages where PKGNAME='SQLC2K26'
			)
			then 'grant execute on package nullid.SQLC2K26 to role ${schemalist[$i]}_WRITE;' 
			else '--'
			end
			from sysibm.sysdummy1"	>>$GRANT_TEMP		

			db2 -x "select 'GRANT ALTER ON SEQUENCE \"'|| rtrim(seq.SEQSCHEMA) ||'\".\"'|| rtrim(seq.SEQNAME) || '\" TO role ${schemalist[$i]}_WRITE;' 
			from syscat.sequences seq
			left join syscat.SEQUENCEAUTH auth on seq.SEQSCHEMA=auth.SEQSCHEMA and seq.SEQNAME=auth.SEQNAME
			and GRANTEE='${schemalist[$i]}_WRITE' and auth.ALTERAUTH='Y' and GRANTEETYPE='R'
			where seq.SEQSCHEMA='${schemalist[$i]}' and auth.SEQNAME is null" >>$GRANT_TEMP			

			db2 -x "select 'GRANT SELECT ON TABLE \"'|| rtrim(tab.tabschema) ||'\".\"'|| rtrim(tab.tabname) || '\" TO role ${schemalist[$i]}_WRITE;' 
			from syscat.tables tab
			left join syscat.tabauth auth on tab.TABSCHEMA=auth.TABSCHEMA and tab.TABNAME=auth.TABNAME
			and GRANTEE='${schemalist[$i]}_WRITE' and auth.SELECTAUTH='Y' and GRANTEETYPE='R'
			where tab.TABSCHEMA='SYSCAT' and tab.type<>'A' and tab.TABNAME in ('SCHEMATA','TABLES','INDEXES','COLUMNS') and auth.tabname is null" >>$GRANT_TEMP					

			if [ -s $blacklist ]
			then 
                typeset -u string_write
                for tab in `cat $blacklist`
                do
                    string_write+="'"$tab"',"
                done
                tables=`echo $string_write | sed 's/.$//'`
			    db2 -x "select 'GRANT SELECT,insert, update, delete ON TABLE \"'|| rtrim(tab.tabschema) ||'\".\"'|| rtrim(tab.tabname) || '\" TO role ${schemalist[$i]}_WRITE;' 
			    from syscat.tables tab
			    left join syscat.tabauth auth on tab.TABSCHEMA=auth.TABSCHEMA and tab.TABNAME=auth.TABNAME
			    and GRANTEE='${schemalist[$i]}_WRITE' and auth.SELECTAUTH='Y' and auth.INSERTAUTH='Y' and auth.DELETEAUTH='Y' and auth.UPDATEAUTH ='Y' and GRANTEETYPE='R'
			    where tab.tabschema='${schemalist[$i]}' and tab.type<>'A' and auth.tabname is null and SUBSTR(tab.PROPERTY,19,1) <>'Y' and tab.tabname not in ($tables) and tab.type <> 'V'" >>$GRANT_TEMP	
			    db2 -x "select 'GRANT SELECT ON TABLE \"'|| rtrim(tab.tabschema) ||'\".\"'|| rtrim(tab.tabname) || '\" TO role ${schemalist[$i]}_WRITE;' 
			    from syscat.tables tab
			    left join syscat.tabauth auth on tab.TABSCHEMA=auth.TABSCHEMA and tab.TABNAME=auth.TABNAME
			    and GRANTEE='${schemalist[$i]}_WRITE' and auth.SELECTAUTH='Y' and GRANTEETYPE='R'
			    where tab.tabschema='${schemalist[$i]}' and auth.tabname is null and SUBSTR(tab.PROPERTY,19,1) <>'Y' and tab.tabname not in ($tables) and tab.type='V'" >>$GRANT_TEMP	

                for tab in `cat $blacklist`
                do
			        typeset -u table_name=$tab
                    db2 -x "select 'revoke SELECT ON TABLE \"'|| rtrim(tabschema) ||'\".\"'|| rtrim(tabname) || '\" from role ${schemalist[$i]}_WRITE;' 
			        from syscat.tabauth 
			        where GRANTEE='${schemalist[$i]}_WRITE' and SELECTAUTH='Y' and tabschema='${schemalist[$i]}' and tabname='$table_name'" >>$GRANT_TEMP	
			        db2 -x "select 'revoke insert ON TABLE \"'|| rtrim(tabschema) ||'\".\"'|| rtrim(tabname) || '\" from role ${schemalist[$i]}_WRITE;' 
			        from syscat.tabauth 
			        where GRANTEE='${schemalist[$i]}_WRITE' and INSERTAUTH='Y' and tabschema='${schemalist[$i]}' and tabname='$table_name'" >>$GRANT_TEMP	
			        db2 -x "select 'revoke update ON TABLE \"'|| rtrim(tabschema) ||'\".\"'|| rtrim(tabname) || '\" from role ${schemalist[$i]}_WRITE;' 
			        from syscat.tabauth 
			        where GRANTEE='${schemalist[$i]}_WRITE' and DELETEAUTH='Y' and tabschema='${schemalist[$i]}' and tabname='$table_name'" >>$GRANT_TEMP	
			        db2 -x "select 'revoke delete ON TABLE \"'|| rtrim(tabschema) ||'\".\"'|| rtrim(tabname) || '\" from role ${schemalist[$i]}_WRITE;' 
			        from syscat.tabauth 
			        where GRANTEE='${schemalist[$i]}_WRITE' and UPDATEAUTH='Y' and tabschema='${schemalist[$i]}' and tabname='$table_name'" >>$GRANT_TEMP	
                done
            else
			    db2 -x "select 'GRANT SELECT,insert, update, delete ON TABLE \"'|| rtrim(tab.tabschema) ||'\".\"'|| rtrim(tab.tabname) || '\" TO role ${schemalist[$i]}_WRITE;' 
			    from syscat.tables tab
			    left join syscat.tabauth auth on tab.TABSCHEMA=auth.TABSCHEMA and tab.TABNAME=auth.TABNAME
			    and GRANTEE='${schemalist[$i]}_WRITE' and auth.SELECTAUTH='Y' and auth.INSERTAUTH='Y' and auth.DELETEAUTH='Y' and auth.UPDATEAUTH ='Y' and GRANTEETYPE='R'
			    where tab.tabschema='${schemalist[$i]}' and tab.type<>'A' and auth.tabname is null and SUBSTR(tab.PROPERTY,19,1) <>'Y' and tab.type <> 'V'" >>$GRANT_TEMP	
			    db2 -x "select 'GRANT SELECT ON TABLE \"'|| rtrim(tab.tabschema) ||'\".\"'|| rtrim(tab.tabname) || '\" TO role ${schemalist[$i]}_WRITE;' 
			    from syscat.tables tab
			    left join syscat.tabauth auth on tab.TABSCHEMA=auth.TABSCHEMA and tab.TABNAME=auth.TABNAME
			    and GRANTEE='${schemalist[$i]}_WRITE' and auth.SELECTAUTH='Y' and GRANTEETYPE='R'
			    where tab.tabschema='${schemalist[$i]}' and auth.tabname is null and SUBSTR(tab.PROPERTY,19,1) <>'Y' and tab.type='V'" >>$GRANT_TEMP	
			fi 	

			####db2 -x "select distinct 'grant role ${schemalist[$i]}_WRITE to user ' ||tab.GRANTEE||';'
			####from SYSCAT.TABAUTH tab
			####left join syscat.roleauth ro on tab.GRANTEE=ro.GRANTEE and ro.ROLENAME='${schemalist[$i]}_WRITE'
			####where ro.rolename is null and tab.GRANTEETYPE='U' and tab.GRANTEE <>'${schemalist[$i]}_WRITE' and tab.UPDATEAUTH='Y' and tab.TABSCHEMA='${schemalist[$i]}'" >>$GRANT_TEMP				

			if [ -s $GRANT_TEMP ]
			then 
				db2 -tcvf $GRANT_TEMP
				rm $GRANT_TEMP
			fi 		
			i=`expr $i + 1`
		done
	fi	
fi

#!/bin/sh
##
## HPS created Jan 2019
##
## http://www.ibm.com/developerworks/data/library/techarticle/dm-1307optimizerunstats/
## see Identifying fragmented indexes from statistics
## http://www.ibm.com/developerworks/data/library/techarticle/dm-1307optimizerunstats/#Listing%207
##0 23 * * 5 (. ~/sqllib/db2profile; ~/dba/bin/misc/reorgTablesIndexesInplace2.sh -s OMDB -tb_stats -if_stats -window 120 -tr >> ~/dba/logs/reorgTablesIndexesInplace2.sh.log 2>&1 )
## script to reorg tables online and indexes offline based on different criteria
## we need to be able to perform an online table reorg and an offline indexes all reorg in the same run of the script
##

UsageHelp()
{

	echo "Script to perform reorg tables, indexes online (inplace) "
	echo " also to REORG INDEXES ALL FOR TABLE offline"
	echo " db2 performs the online reorgs asynchronously"
	echo ""
	echo "Usage: ${0} [options]"
	echo " where [options] is one of the following:"
	echo "       -h:	displays this usage screen"
	echo "      -db:	dbname, default is all cataloged databases"
	echo ""
	echo "       -s:	table schemaname"
	echo "       -t:	table(s) to reorg"
	echo "-tb_stats:	reorg tables reported by REORGCHK_TB_STATS"
	echo "      -ti:	reorg table index(s), format must be TABSCHEMA.TABNAME.INDSCHEMA.INDNAME"
	echo "-ix_stats:	reorg table index(s) reported by REORGCHK_IX_STATS"
	echo "-if_stats:	reorg indexes all for table(s) offline as reported by index fragmentation NLEAF/SEQUENTIAL_PAGES columns"
	echo ""
	echo "      -ls:	list valid table sizes for a particular schema"
	echo "      -lf:	list all fragmented index details for a particular schema, based on valid table sizes"
	echo "      -lt:	list all tables to reorg based on REORGCHK_TB_STATS reorg column, based on valid table sizes"
	echo "      -li:	list all indexes to reorg based on REORGCHK_IX_STATS reorg column, based on valid table sizes"
	echo "       -l:	list tables/indexes that would be reorged"
	echo ""
	echo "    -ittx:	ignore tables over a specific threshold size in MBs, default is 20000 MB ie 20 GB"
	echo "    -ittn:	ignore tables under a specific threshold size in MBs, default is 10 MB"
	echo "     -mar:	maximum asynchronous reorgs allowed, default is 3"
	echo "     -log:	don't kick off a reorg if transaction log usage is over a certain percentage, default is 90%"
	echo "  -window:	stop reorg tables/indexes/runstats after a set maintenance timeout window, default is 240 minutes"
	echo "     -twa:	timeout window action: default=2 for online, 1 for offline"
	echo "          		1=allow current reorg(s) to continue"
	echo "          		2=stop current reorg(s)"
#	echo "          		3=stop current reorg(s) if < 80% complete and continue script"
	echo "  -ignore:	ignore specific tables from SYSIBMADM.ADMINTABINFO t0, SYSCAT.TABLES t1 "
	echo "          	eg \"$IGNORE_TABLES_EX\""
	echo "   -reorg:	table F1 F2 F3 filter reorg, default is *"
	echo "   -sleep:	SLEEP_INTERVAL_TIME, default is 60 seconds"
	echo ""
	echo "      -tr:	execute inplace table/index reorg"
	echo ""
	echo "    -trsi:	Retrieve table reorganization snapshot information from snap_get_tab_reorg and db2pd -reorgs index"
	echo ""
	echo "Examples:"
	echo " 1. ${0} -h"
	echo " 2. ${0} -db dbname -s omdb -ls"
	echo " 3. ${0} -s OMDB -t \"YFS_ITEM YFS_TASK_Q YFS_SHIPMENT\" -tb_stats -tr "
	echo " 4. ${0} -s OMDB -ti \"OMDB.YFS_SNAPSHOT.OMDB.YFS_SNAPSHOT_I1 OMDB.YFS_ITEM.OMDB.YFS_ITEM_PK\" -ix_stats -tr"
	echo " 5. ${0} -s OMDB -t \"YFS_ITEM YFS_SNAPSHOT YFS_IMPORT YFS_EXPORT\" -if_stats -tr"
	echo " 6. ${0} -s OMDB -tb_stats -mar 5 -window 10 -log 95 -ittx 30000 -tr"
	echo " 7. ${0} -s OMDB -tb_stats -mar 5 -window 10 -log 95 -ignore \"$IGNORE_TABLES_EX\" -reorg \"***\" -tr"
	echo " 8. ${0} -s OMDB -tb_stats -if_stats -ittx 100 -ittn 20 -tr"
	echo " 9. ${0} -trsi"

	echo ""

}

##
## function to check if a string is numeric
##
isNumeric()
{
	echo $1 | grep -E '^[0-9]+$' > /dev/null

	return $?

}


TRSI()
{
	db2 -v "select varchar(tabschema,9) as tabschema, varchar(tabname,32) as tabname,
		REORG_STATUS, REORG_COMPLETION, REORG_PHASE, REORG_CURRENT_COUNTER, REORG_MAX_COUNTER, 
--		varchar( varchar_format(REORG_START, 'YYYY-MM-DD HH24:MI:SS'),19) as REORG_START,
--		varchar( varchar_format(REORG_END, 'YYYY-MM-DD HH24:MI:SS'),19) as REORG_END,
		REORG_START, REORG_END,
		REORG_INDEX_ID, REORG_TBSPC_ID
		from table(snap_get_tab_reorg('')) 
		order by REORG_START asc
		with ur"
	
	db2pd -db $DBNAME -reorgs index | sed -n "/Index Reorg Stats:/,//p"
	

}

log() 
{
	TYPE=$1
	MSG="$2"

	DATE=$( date '+%d-%m-%Y %H:%M:%S' );

	# TYPE:
	# 0 = Critical
	# 1 = Warn
	# 3 = Info
	# 5 = Debug'
	if [ ${TYPE} -eq 0 ]; then
		TYPEMSG="Error"
	elif [ ${TYPE} -eq 1 ]; then
		TYPEMSG="Warning"
	elif [ ${TYPE} -eq 3 ]; then
		TYPEMSG="Info"
	elif [ ${TYPE} -eq 5 ]; then
		TYPEMSG="Debug"
	else
		TYPEMSG="Other"
	fi

	echo -e "${DATE} ${TYPEMSG}: ${MSG}" | tee -a $REORG_TABLE_INDEX_LOG

	return 0
}

initTABLE_IN_USE_ARRAY()
{

	local NUM_ITEMS=$1
	local jj;

	##
	## initialise the db2 TABLE_IN_USE_ARRAY
	##
	for((jj=0; jj<$NUM_ITEMS; jj++))
	do
		TABLE_IN_USE_ARRAY[$jj]=""
	done

	return 0

}

existTABLE_TABLE_IN_USE_ARRAY()
{

	local TABLE=$1
	local jj;
	##
	## check if table is in use
	##
	for((jj=0; jj<${#TABLE_IN_USE_ARRAY[@]}; jj++))
	do
		if [ "${TABLE_IN_USE_ARRAY[$jj]}" == "$TABLE" ]; then 
			return 0;
		fi
	done

	return 1;

}

addTABLE_TABLE_IN_USE_ARRAY()
{

	local TABLE=$1
	local jj;

	##
	## add table in empty slot
	##
	for((jj=0; jj<${#TABLE_IN_USE_ARRAY[@]}; jj++))
	do
		if [ "${TABLE_IN_USE_ARRAY[$jj]}" == "" ]; then 
			TABLE_IN_USE_ARRAY[$jj]=$TABLE;
			return 0;
		fi
	done

	return 1;
}

removeTABLE_TABLE_IN_USE_ARRAY()
{

	local TABLE=$1
	local jj;
	##
	## remove entry
	##
	for((jj=0; jj<${#TABLE_IN_USE_ARRAY[@]}; jj++))
	do
		if [ "${TABLE_IN_USE_ARRAY[$jj]}" == "$TABLE" ]; then 
			TABLE_IN_USE_ARRAY[$jj]="";
			return 0;
		fi
	done

	return 1;

}


listTABLE_IN_USE_ARRAY()
{

	local jj;
	##
	## list table entries
	##
	for((jj=0; jj<${#TABLE_IN_USE_ARRAY[@]}; jj++))
	do
		log 5 "TABLE_IN_USE_ARRAY $jj ${TABLE_IN_USE_ARRAY[$jj]}";
	done

	return 0;

}

getValidTablesToReorg()
{

	getValidTableSizes

	VALID_TABLES_TO_REORG=""
	VALID_TABLES_TO_REORG_RAW=""
	NUM_VALID_TABLES_TO_REORG=0
	for TABNAME in $VALID_TABLES
	do

		RAW=$( db2 -x "call REORGCHK_TB_STATS('T','$SCHEMANAME_IN.$TABNAME')" );
		RAW=$( echo "$RAW" | grep $SCHEMANAME_IN | grep $TABNAME | awk '{ if (NF == 12) print $0 }' | sed 's/ \+/ /g' | grep $REORG )
		rc=$?
		if [ $rc -eq 0 ]; then
			TABNAME=$( echo "$RAW" | awk '{print $2}' );
			[ "$VALID_TABLES_TO_REORG_RAW_DATA" == "" ] && VALID_TABLES_TO_REORG_RAW_DATA="$RAW" || VALID_TABLES_TO_REORG_RAW_DATA="$VALID_TABLES_TO_REORG_RAW_DATA\n$RAW"
		fi
		
	done

	## sort the tables based on REORG column
	VALID_TABLES_TO_REORG_RAW_DATA=$( echo -e "$VALID_TABLES_TO_REORG_RAW_DATA" | sort -k12 -r);
	VALID_TABLES_TO_REORG=$( echo -e "$VALID_TABLES_TO_REORG_RAW_DATA" | awk '{print $2}' );
	NUM_VALID_TABLES_TO_REORG=$( echo -e "$VALID_TABLES_TO_REORG" | wc -l );
	
	return 0
	
}

getValidIndexesToReorg()
{

	getValidTableSizes

	VALID_INDEXES_TO_REORG=""
	VALID_INDEXES_TO_REORG_RAW=""
	NUM_VALID_INDEXES_TO_REORG=0
	for TABNAME in $VALID_TABLES
	do

		RAW=$( db2 -x "call REORGCHK_IX_STATS('T','$SCHEMANAME_IN.$TABNAME')" );
		## this can return multiple indexes for same TABNAME
		RAW=$( echo "$RAW" | grep $SCHEMANAME_IN | grep $TABNAME | awk '{ if (NF == 21) print $0 }' | sed 's/ \+/ /g' | grep $REORG );
		rc=$?
		if [ $rc -eq 0 ]; then
			INDNAME=$( echo "$RAW" | awk '{print $1"."$2"."$3"."$4}' );
			[ "$VALID_INDEXES_TO_REORG_RAW_DATA" == "" ] && VALID_INDEXES_TO_REORG_RAW_DATA=$RAW || VALID_INDEXES_TO_REORG_RAW_DATA="$VALID_INDEXES_TO_REORG_RAW_DATA\n$RAW"
		fi
		
	done

	## sort the indexes based on REORG column
	VALID_INDEXES_TO_REORG_RAW_DATA=$( echo -e "$VALID_INDEXES_TO_REORG_RAW_DATA" | sort -k21 -r);
	VALID_INDEXES_TO_REORG=$( echo -e "$VALID_INDEXES_TO_REORG_RAW_DATA" | awk '{print $1"."$2"."$3"."$4}' );
	NUM_VALID_INDEXES_TO_REORG=$( echo -e "$VALID_INDEXES_TO_REORG" | wc -l );

	return 0
	
}

getValidFragmentedIndexes()
{

	##
	## http://www.ibm.com/developerworks/data/library/techarticle/dm-1307optimizerunstats/#Listing%207
	## 

	getValidTableSizes

	VALID_FRAGMENTED_INDEXES_RAW_DATA=$( db2 -x "select rtrim(tabschema)||' '||rtrim(tabname)||' '||rtrim(indschema)||' '||rtrim(indname)
			||' '||indcard||' '||stats_time||' '||lastused||' '||nleaf||' '||sequential_pages 
			from syscat.indexes where tabschema='$SCHEMANAME_IN' 
			and not (nleaf = 1 and sequential_pages = 0) 
			and not (nleaf = 0 and sequential_pages = 1) 
			and (nleaf - sequential_pages > 10)
			and tabname in ( $VALID_TABLES_FORMATTED )
			order by tabname 
			with ur"; );

	VALID_FRAGMENTED_INDEXES_RAW_DATA=$(echo "${VALID_FRAGMENTED_INDEXES_RAW_DATA}" | sed 's/ *$//g' );
	VALID_FRAGMENTED_INDEXES=$( echo "${VALID_FRAGMENTED_INDEXES_RAW_DATA}" | sed 's/ *$//g' | cut -d' ' -f2 | uniq )
	NUM_VALID_FRAGMENTED_INDEXES=$( echo "${VALID_FRAGMENTED_INDEXES}" | wc -l )


}

getValidTableSizes()
{

	VALID_TABLE_SIZES_RAW_DATA=$( db2 "select t0.tabname,
		( ( DATA_OBJECT_P_SIZE + INDEX_OBJECT_P_SIZE + LONG_OBJECT_P_SIZE + LOB_OBJECT_P_SIZE + XML_OBJECT_P_SIZE ) / 1024 ) as TOTAL_TABLE_MB,
		cast ((INDEX_OBJECT_P_SIZE / 1024) as integer) as INDEX_SIZE_MB	
		from SYSIBMADM.ADMINTABINFO t0, SYSCAT.TABLES t1
		where t0.tabschema='$SCHEMANAME_IN'
		and t0.tabschema=t1.tabschema
		and t0.tabname=t1.tabname
		$IGNORE_TABLES
		and ( ( DATA_OBJECT_P_SIZE + INDEX_OBJECT_P_SIZE + LONG_OBJECT_P_SIZE + LOB_OBJECT_P_SIZE + XML_OBJECT_P_SIZE ) / 1024 ) < $IGNORE_TABLE_SIZE_THRESHOLD_MAX
		and ( ( DATA_OBJECT_P_SIZE + INDEX_OBJECT_P_SIZE + LONG_OBJECT_P_SIZE + LOB_OBJECT_P_SIZE + XML_OBJECT_P_SIZE ) / 1024 ) > $IGNORE_TABLE_SIZE_THRESHOLD_MIN
		order by 2 desc
		with ur"; );
	rc=$?
	if [ $rc -eq 0 ]; then 
		VALID_TABLE_SIZES=$( echo "$VALID_TABLE_SIZES_RAW_DATA" | sed '1,3d' | sed '$d' | sed '$d' );	
		VALID_TABLE_SIZES=$( echo "$VALID_TABLE_SIZES" | awk 'BEGIN {ORS="\t"} { for(ii=1 ; ii<=NF ; ii++) print $ii; printf "\n"; }');
		VALID_TABLES=$( echo "$VALID_TABLE_SIZES" | awk '{print $1}' );
		NUM_VALID_TABLES=$( echo "$VALID_TABLE_SIZES" | wc -l );
		# log 3 "NUM_VALID_TABLES=$NUM_VALID_TABLES"

		VALID_TABLES_FORMATTED=""
		for TABLE in $VALID_TABLES
		do
			VALID_TABLES_FORMATTED="$VALID_TABLES_FORMATTED'$TABLE',"
		done
		VALID_TABLES_FORMATTED=$( echo "$VALID_TABLES_FORMATTED" | sed 's/,$//g' )
	else
		VALID_TABLES_FORMATTED="'UNKNOWN_TABNAME'"
	fi

}

## is TABLE within size limits < IGNORE_TABLE_SIZE_THRESHOLD_MAX and > IGNORE_TABLE_SIZE_THRESHOLD_MIN
isTableWithinSizeLimit()
{
	local SCHEMANAME=$1
	local TABNAME=$2
	local RC=""
	local rc=0

	RC=$( db2  -x "select tabname,
		( ( DATA_OBJECT_P_SIZE + INDEX_OBJECT_P_SIZE + LONG_OBJECT_P_SIZE + LOB_OBJECT_P_SIZE + XML_OBJECT_P_SIZE ) / 1024 ) as TOTAL_TABLE_MB
		from SYSIBMADM.ADMINTABINFO 
		where tabschema='$SCHEMANAME'
		and tabname = '$TABNAME'
		and ( ( DATA_OBJECT_P_SIZE + INDEX_OBJECT_P_SIZE + LONG_OBJECT_P_SIZE + LOB_OBJECT_P_SIZE + XML_OBJECT_P_SIZE ) / 1024 ) < $IGNORE_TABLE_SIZE_THRESHOLD_MAX
		and ( ( DATA_OBJECT_P_SIZE + INDEX_OBJECT_P_SIZE + LONG_OBJECT_P_SIZE + LOB_OBJECT_P_SIZE + XML_OBJECT_P_SIZE ) / 1024 ) > $IGNORE_TABLE_SIZE_THRESHOLD_MIN
		order by 2 desc
		with ur" );

	rc=$?
	return $rc

}

## create an list/array of table objects to reorg based on tabnames
createTableOBJECT_ARRAY()
{
	local TABNAMES="$1"
	local OBJECT_REORG_TABLE_TYPE=$2

	##
	## make the OBJECT_ARRAY for tables and indexes
	##
	if [ -z "$OBJECT_ARRAY" ]; then
		local let index=0;
	else
		local let index=${#OBJECT_ARRAY[@]};
	fi 
	local TID=0	## Table ID - always 0 for online table reorg
	local INDSCHEMA=NULL;
	local INDNAME=NULL;
	local LOCK_COUNT=0

	for TABNAME in $TABNAMES
	do
		## we need TABLEID, TBSPACEID for IF_STATS as the full TableName: may not be dispalyed in the db2pd output
		local RC=$( db2 -x "select TABLEID, TBSPACEID from syscat.tables where tabname='$TABNAME' and tabschema='$SCHEMANAME_IN'" )
		local rc=$?
		if [ $rc -eq 0 ]; then
			local TABLEID=$( echo $RC | awk '{print $1}' );
			local TBSPACEID=$( echo $RC | awk '{print $2}' );
			OBJECT_ARRAY[$index]="$SCHEMANAME_IN#$TABNAME#$INDSCHEMA#$INDNAME#$TID#NOTSTARTED#2019-01-01-00.00.00#2019-01-01-00.00.00#$TABLEID#$TBSPACEID#$LOCK_COUNT#$OBJECT_REORG_TABLE_TYPE"
			let index+=1
		fi
	done

}

## create an list/array of table objects to reorg based on indnames
createIndexOBJECT_ARRAY()
{

	local INDNAMES="$1"
	local OBJECT_REORG_TABLE_TYPE=$2	
	local let index=0
	local TABLEID=9999;
	local TBSPACEID=9999;
	local LOCK_COUNT=0;

	for INDEX in $INDNAMES
	do
		local TABSCHEMA=$( echo $INDEX | cut -d. -f1);
		local TABNAME=$( echo $INDEX | cut -d. -f2);
		local INDSCHEMA=$( echo $INDEX | cut -d. -f3);
		local INDNAME=$( echo $INDEX | cut -d. -f4);
		local RC=$( db2 -x "select IID from syscat.indexes where tabschema = '$TABSCHEMA' and tabname = '$TABNAME' and indschema = '$INDSCHEMA' and indname = '$INDNAME'");
		local rc=$?
		if [ $rc -eq 0 ]; then
			local IID=$( echo $RC | cut -d' ' -f1);
			OBJECT_ARRAY[$index]="$TABSCHEMA#$TABNAME#$INDSCHEMA#$INDNAME#$IID#NOTSTARTED#2019-01-01-00.00.00#2019-01-01-00.00.00#$TABLEID#$TBSPACEID#$LOCK_COUNT#$OBJECT_REORG_TABLE_TYPE"
			let index+=1
		fi
	done

}

##
## list out the objects and state
## this can be used for debugging
##
listOBJECT_ARRAY()
{
	
	local ii;
	log 3 "The following is for debug purposes, Num objects=${#OBJECT_ARRAY[@]}, $OBJECT_NUM_TB_STATS:$OBJECT_NUM_IX_STATS:$OBJECT_NUM_IF_STATS"
	for((ii=0; ii< ${#OBJECT_ARRAY[@]}; ii++))
	do
		   echo "${OBJECT_ARRAY[$ii]}" | tee -a $REORG_TABLE_INDEX_DEBUG
	done

}

## get the number tb_stats, ix_stats and if_stats objects
getNUM_OBJECT_REORG_TABLE_TYPE_OBJECT_ARRAY()
{

	local rc=0;
	local ii;
	for((ii=0; ii< ${#OBJECT_ARRAY[@]}; ii++))
	do
		if [ $( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f12 ) -eq $1 ]; then 
			let rc+=1;
		fi
	done

	return $rc;

}

##
## the main event
##
reorgTables()
{

	## variables that need to be reset on each run of the function
	NUM_REORGS_IN_PROGRESS=0;
	NUM_REORGS_KICKED_OFF=0;
	NUM_REORGS_COMPLETED=0;
	NUM_REORGS_STOPPED=0;
	NUM_REORGS_ABORTED=0;

	while true
	do

		## check reorg window maintenance time
		MAINTENANCE_TIMEOUT_WINDOW_TIME_NOW_SECONDS=$( date '+%s' );
		DIFF=$(( MAINTENANCE_TIMEOUT_WINDOW_TIME_NOW_SECONDS - REORG_TIMEOUT_WINDOW_START_TIME_SECONDS ));

		## safety valve - if for some reason the logic can't stop the reorgs
		if [ $DIFF -ge $(( REORG_TIMEOUT_WINDOW_SECONDS + REORG_TIMEOUT_OVERFLOW_VALVE )) ]; then 
			log 1 "REORG_TIMEOUT_OVERFLOW_VALVE detected";
			log 1 "Aborting reorgs"
			break;
		fi

		if [ $DIFF -ge $REORG_TIMEOUT_WINDOW_SECONDS ]; then

			REORG_TIMEOUT_WINDOW_COMPLETED=1;

			## -twa:	timeout window action: default=3
			##  			1=allow current reorg(s) to continue 
			##			2=stop current reorg(s)
			## 			3=stop current reorg(s) if < 80% complete
			if [ $REORG_TIMEOUT_WINDOW_ACTION -eq 1 ]; then

				log 3 "Reorg window ending, reorg window time exceeded, twa=$REORG_TIMEOUT_WINDOW_ACTION"
				break

			elif [ $REORG_TIMEOUT_WINDOW_ACTION -eq 2 ]; then

				## use of the REORG_TIMEOUT_WINDOW_COMPLETED_COUNTER
				## 0 = ABORT those not started and issue a STOP to those STARTED
				## 1 = loop again and see if script exits as all reorgs are COMPLETED and STOPPED and ABORTED
				## 2 = break out
				if [ $REORG_TIMEOUT_WINDOW_COMPLETED_COUNTER -eq 0 ]; then
					let REORG_TIMEOUT_WINDOW_COMPLETED_COUNTER+=1
					log 3 "Reorg window ending, reorg window time exceeded, twa=$REORG_TIMEOUT_WINDOW_ACTION"
					log 3 "Aborting reorgs NOTSTARTED and issuing a STOP to those that are STARTED"
				elif [ $REORG_TIMEOUT_WINDOW_COMPLETED_COUNTER -eq 1 ]; then
					let REORG_TIMEOUT_WINDOW_COMPLETED_COUNTER+=1
					log 3 "REORG_TIMEOUT_WINDOW_COMPLETED_COUNTER=$REORG_TIMEOUT_WINDOW_COMPLETED_COUNTER"
				elif [ $REORG_TIMEOUT_WINDOW_COMPLETED_COUNTER -eq 2 ]; then
					log 3 "REORG_TIMEOUT_WINDOW_COMPLETED_COUNTER=$REORG_TIMEOUT_WINDOW_COMPLETED_COUNTER"
					log 3 "breaking out of reorg loop"
					break;
				fi

			fi

		fi

		## loop for all OBJECTS - extract relevant data from OBJECT array
		## if we have NOTSTARTED in the OBJECT_ARRAY[N] - then kick off a reorg
		## then check tables reorg status
		for((ii=0; ii< ${#OBJECT_ARRAY[@]}; ii++))
		do
			## get table related info
			TABSCHEMA=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f1 );
			TABNAME=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f2 );
			INDSCHEMA=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f3 );
			INDNAME=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f4 );
			IID=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f5 );
			OBJECT_REORG_STATUS=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f6 );
			OBJECT_REORG_START=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f7 );
			OBJECT_REORG_END=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f8 );
			TABLEID=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f9 );
			TBSPACEID=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f10 );
			LOCK_COUNT=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f11 );
			OBJECT_REORG_TABLE_TYPE=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f12 );
			isTable=0;
			isIndex=0;
			if [ "$INDSCHEMA" == "NULL" -a "$INDNAME" == "NULL" ]; then
				isTable=1;
			else
				isIndex=1;
			fi

			if [ $OBJECT_REORG_TABLE_TYPE -ne $REORG_TABLE_TYPE ]; then 
				continue;
			fi
	
			# log 5 "${OBJECT_ARRAY[$ii]}"

			##
			## has OBJECT COMPLETED - no need to continue here
			##
			if [ "$OBJECT_REORG_STATUS" == "COMPLETED" -o "$OBJECT_REORG_STATUS" == "STOPPED" -o "$OBJECT_REORG_STATUS" == "ABORTED" ]; then	
				continue;
			fi		

			if [ $TB_STATS -eq 1 -o $IX_STATS -eq 2 ]; then

				## 
				## query db2 for REORG_STATUS etc - there may not be an entry so carry on
				##
				RC_SNAP=$( db2 -x "select REORG_STATUS, REORG_COMPLETION, REORG_PHASE, REORG_CURRENT_COUNTER, REORG_MAX_COUNTER, REORG_START, REORG_END, REORG_INDEX_ID, REORG_TBSPC_ID from table(snap_get_tab_reorg('')) where tabschema='$TABSCHEMA' and tabname='$TABNAME' and REORG_START > TIMESTAMP('$WINDOW_START_TIME_DB2') and REORG_INDEX_ID=$IID");
				rc=$?
				if [ $rc -ge 2 ]; then 
					log 0 "Possible error running select query against db2\nrc=$rc\nRC=$RC"
					continue;						
				fi

				if [ $rc -eq 0 ]; then
					RC=$( echo "$RC_SNAP" | awk 'BEGIN {ORS="\t"} { for(ii=1 ; ii<=NF ; ii++) print $ii; }')
					REORG_STATUS=$( echo "$RC_SNAP" | awk '{print $1}' );
					REORG_COMPLETION=$( echo "$RC_SNAP" | awk '{print $2}' );
					REORG_CURRENT_COUNTER=$( echo "$RC_SNAP" | awk '{print $4}' );
					REORG_MAX_COUNTER=$( echo "$RC_SNAP" | awk '{print $5}' );
					REORG_START=$( echo "$RC_SNAP" | awk '{print $6}' );
					REORG_END=$( echo "$RC_SNAP" | awk '{print $7}' );
					REORG_INDEX_ID=$( echo "$RC_SNAP" | awk '{print $8}' );

					REORG_PERCENT_COMPLETE=0
					if [ ! -z "$REORG_CURRENT_COUNTER" -a $REORG_CURRENT_COUNTER -gt 0 ]; then 
						if [ ! -z "$REORG_MAX_COUNTER" -a $REORG_MAX_COUNTER -gt 0 ]; then 
							if [ $REORG_MAX_COUNTER -ge $REORG_CURRENT_COUNTER ]; then 
								REORG_PERCENT_COMPLETE=$( echo $REORG_CURRENT_COUNTER $REORG_MAX_COUNTER | awk '{ print int (($1/$2)*100) }' );
							fi
						fi
					fi
				fi

				# log 5 "RC_SNAP=$RC_SNAP"

			elif [ $IF_STATS -eq 3 ]; then

				DB2PD_REORG_INDEX_RECORD=$( db2pd -db $DBNAME -reorgs index | grep -B1 -A11 -w "^TbspaceID: $TBSPACEID" | grep -B1 -A11 -w "TableID: $TABLEID" );
				rc=$?
				if [ $rc -eq 0 ]; then
					REORG_START=$(echo "$DB2PD_REORG_INDEX_RECORD" | grep '^Start Time:' | awk '{ print $3,$4}' );
					REORG_START_SECONDS=$(date --d="$REORG_START" '+%s');

					if [ $REORG_START_SECONDS -ge $IF_STATS_WINDOW_START_TIME_DB2 ]; then
						REORG_STATUS=$(echo "$DB2PD_REORG_INDEX_RECORD" | grep '^Status:' | awk '{ $1=""; print $0}' | sed 's/^[ \t]*//;s/[ \t]*$//' );
						## some differences between snap_get_tab_reorg and db2pd -reogrs index output
						if [ "$REORG_STATUS" == "In Progress" ]; then
							REORG_STATUS="STARTED";
						elif [ "$REORG_STATUS" == "Completed" ]; then 
							REORG_STATUS="COMPLETED";
						elif [ "$REORG_STATUS" == "Stopped" ]; then
							REORG_STATUS="STOPPED";
						fi
					
						REORG_END=$(echo "$DB2PD_REORG_INDEX_RECORD" | grep '^Start Time:' | grep 'End Time:' | awk '{ print $7,$8}' );
					fi
					
				fi


			fi


			##
			## has OBJECT been KICKED_OFF or STARTED
			## if it has check to see if is STARTED or COMPLETED
			## update OBJECT_ARRAY
			## update COMPLETION/STOPPED stats
			##
			if [ "$OBJECT_REORG_STATUS" == "KICKED_OFF" ] || [ "$OBJECT_REORG_STATUS" == "STARTED" ]; then	
				if [ ! -z "$REORG_STATUS" ]; then
					if [ "$REORG_STATUS" == "STARTED" -o "$REORG_STATUS" == "COMPLETED" -o "$REORG_STATUS" == "STOPPED" ]; then 
						OBJECT_ARRAY[$ii]="$TABSCHEMA#$TABNAME#$INDSCHEMA#$INDNAME#$IID#$REORG_STATUS#$REORG_START#$REORG_END#$TABLEID#$TBSPACEID#$LOCK_COUNT#$OBJECT_REORG_TABLE_TYPE"
					fi
			
					if [ "$REORG_STATUS" == "COMPLETED" -o "$REORG_STATUS" == "STOPPED" ]; then 

						removeTABLE_TABLE_IN_USE_ARRAY "$TABSCHEMA.$TABNAME"
						rc=$?
						if [ $rc -eq 1 ]; then 
							log 1 "Failed to remove table $TABSCHEMA.$TABNAME from TABLE_IN_USE_ARRAY";
						fi

						if [ "$REORG_STATUS" == "COMPLETED" ]; then
							let NUM_REORGS_COMPLETED+=1
						elif [ "$REORG_STATUS" == "STOPPED" ]; then
							let NUM_REORGS_STOPPED+=1
						fi

						let NUM_REORGS_IN_PROGRESS-=1
					fi

				fi

			##
			## OBJECT is NOSTARTED so KICK_OFF a reorg
			##
			elif [ "$OBJECT_REORG_STATUS" == "NOTSTARTED" ]; then

				## dont kick off any reorgs if window timeout passed and TWA=2
				## OBJECTS become ABORTED - UPDATE OBJECT_ARRAY 
				if [ $REORG_TIMEOUT_WINDOW_COMPLETED -eq 1 ] && [ $REORG_TIMEOUT_WINDOW_ACTION -eq 2 ] && [ $REORG_TIMEOUT_WINDOW_COMPLETED_COUNTER -eq 1 ]; then 
					REORG_STATUS=ABORTED;
					OBJECT_ARRAY[$ii]="$TABSCHEMA#$TABNAME#$INDSCHEMA#$INDNAME#$IID#$REORG_STATUS#$OBJECT_REORG_START#$OBJECT_REORG_END#$TABLEID#$TBSPACEID#$LOCK_COUNT#$OBJECT_REORG_TABLE_TYPE";
					let NUM_REORGS_ABORTED+=1;
					continue;	
					
				fi

				## is the TABLE already being used -if it is goto next OBJECT
				existTABLE_TABLE_IN_USE_ARRAY "$TABSCHEMA.$TABNAME"
				rc=$?
				[ $rc -eq 0 ] && continue;

				## we only want to kick off so many reorgs at any one time
				if [ $NUM_REORGS_IN_PROGRESS -eq $MAX_ASYNC_REORGS_ALLOWED ]; then
					continue;
				fi

				##
				## The table could already be locked - if it is then by-pass it
				## and ABORT if locked more than 10 times
				##
				TABLE_LOCKED=$( db2 "select APPLICATION_HANDLE, LOCK_OBJECT_TYPE, LOCK_MODE, LOCK_CURRENT_MODE, LOCK_STATUS, LOCK_COUNT, LOCK_HOLD_COUNT, TBSP_ID, TAB_FILE_ID from TABLE (MON_GET_LOCKS(NULL, -2)) where TBSP_ID=$TBSPACEID and TAB_FILE_ID=$TABLEID and LOCK_OBJECT_TYPE='TABLE' and LOCK_MODE='IX' with ur"; );
				rc=$?
				if [ $rc -eq 0 ]; then 
					let LOCK_COUNT+=1;
					log 1 "Appears table $TABSCHEMA.$TABNAME is already locked by another application(s), LOCK_COUNT=$LOCK_COUNT";
					log 1 "$TABLE_LOCKED";
					if [ $LOCK_COUNT -gt 10 ]; then 
						OBJECT_REORG_STATUS=ABORTED;
						let NUM_REORGS_ABORTED+=1;
						log 1 "Aborting table $TABSCHEMA.$TABNAME , LOCK_COUNT=$LOCK_COUNT";
					fi
OBJECT_ARRAY[$ii]="$TABSCHEMA#$TABNAME#$INDSCHEMA#$INDNAME#$IID#$OBJECT_REORG_STATUS#$OBJECT_REORG_START#$OBJECT_REORG_END#$TABLEID#$TBSPACEID#$LOCK_COUNT#$OBJECT_REORG_TABLE_TYPE";
					continue;
				fi
		
				##
				## do a check to see where we are on transaction log space - this could be improved!!!!
				##
				LOG_USED=$( db2 "select cast(LOG_UTILIZATION_PERCENT as decimal(5,2)) as PCTUSED, cast((TOTAL_LOG_USED_KB/1024) as Integer) as TOTUSEDMB,  cast((TOTAL_LOG_AVAILABLE_KB/1024) as Integer) as TOTAVAILMB, cast((TOTAL_LOG_USED_TOP_KB/1024) as Integer) as TOTUSEDTOPMB FROM   SYSIBMADM.LOG_UTILIZATION ");
				if [ ! -z "$LOG_USED" ]; then
					PCTUSED=$( echo "$LOG_USED" | awk '{ if(NF==4 && $2 ~/^[0-9]+$/) print int($1)}' );
					if [ ! -z "$PCTUSED" ]; then
						if [ $PCTUSED -gt $TRANSACTION_LOG_THRESHOLD_PCT ]; then
							log 1 "Will not kick off another reorg due to logfile PCTUSED above threshold of $LOG_THRESHOLD\n$LOG_USED"
							continue
						else
							log 3 "$LOG_USED"
						fi
					fi
				fi

				##
				## kick off another reorg 
				## if rc=0 then ok, else we ABORT the OBJECT and don't try again
				##
				log 3 ""

				if [ $TB_STATS -eq 1 -o $IX_STATS -eq 2 ]; then 

					if [ $isTable -eq 1 ]; then
					
						db2 -v "reorg table $TABSCHEMA.$TABNAME inplace allow write access"
						rc=$?

					elif [ $isIndex -eq 1 ]; then
						db2 -v "reorg table $TABSCHEMA.$TABNAME index $INDSCHEMA.$INDNAME inplace allow write access"
						rc=$?
					fi

				elif [ $IF_STATS -eq 3 ]; then 
				
					## for offline we throw a job at db2 and wait a few seconds and check the output
					## output could be "reorg indexes all for table ...", 
					##  or SQL error 
					##  or 'DB20000I  The REORG command completed successfully.'
					## not sure if there is a better way to do this
					TMPLOG="/tmp/$TABSCHEMA.$TABNAME.tmp";
					db2 -v "reorg indexes all for table $TABSCHEMA.$TABNAME allow write access" > $TMPLOG 2>&1 &
					sleep 5;
					cat $TMPLOG;
					RC=$( grep '^SQL' $TMPLOG);
					rc=$?
					if [ $rc -eq 0 ]; then 
						log 1 "Failed to kick off reorg\n$RC";
						rc=1;
					else
						## reorg could have finished then no need for the big sleep
						RC=$( grep 'DB20000I  The REORG command completed successfully.' $TMPLOG);
						if [ $? -eq 0 ]; then
							IF_STATS_BYPASS_SLEEP_INTERVAL_TIME=1;
						fi	
						rc=0;						

					fi
					rm -f $TMPLOG;

				fi

				if [ $rc -eq 0 ]; then
					REORG_STATUS=KICKED_OFF;
				else
					REORG_STATUS=ABORTED;
				fi
					OBJECT_ARRAY[$ii]="$TABSCHEMA#$TABNAME#$INDSCHEMA#$INDNAME#$IID#$REORG_STATUS#$OBJECT_REORG_START#$OBJECT_REORG_END#$TABLEID#$TBSPACEID#$LOCK_COUNT#$OBJECT_REORG_TABLE_TYPE";
				if [ $rc -ne 0 ]; then
					let NUM_REORGS_ABORTED+=1;
					continue
				fi

				## add the table to the TABLE_IN_USE_ARRAY
				addTABLE_TABLE_IN_USE_ARRAY "$TABSCHEMA.$TABNAME"
				rc=$?
				if [ $rc -eq 1 ]; then 
					log 1 "Failed to add table  $TABSCHEMA.$TABNAME to TABLE_IN_USE_ARRAY";
				fi
				let NUM_REORGS_KICKED_OFF+=1;
				let NUM_REORGS_IN_PROGRESS+=1;

				continue;
			
			fi	

			##
			## ouput STATUS
			##
			if [ $TB_STATS -eq 1 -o $IX_STATS -eq 2 ]; then 
				log 3 "$NUM_REORGS_IN_PROGRESS:$NUM_REORGS_KICKED_OFF:$NUM_REORGS_ABORTED:$NUM_REORGS_STOPPED:$NUM_REORGS_COMPLETED:$NUM_REORG_OBJECTS $TABSCHEMA.$TABNAME : $RC : $REORG_PERCENT_COMPLETE %" | tee -a $REORG_TABLE_INDEX_DEBUG
			elif [ $IF_STATS -eq 3 ]; then
				log 3 "$NUM_REORGS_IN_PROGRESS:$NUM_REORGS_KICKED_OFF:$NUM_REORGS_ABORTED:$NUM_REORGS_STOPPED:$NUM_REORGS_COMPLETED:$NUM_REORG_OBJECTS $TABSCHEMA.$TABNAME \n$DB2PD_REORG_INDEX_RECORD "| tee -a $REORG_TABLE_INDEX_DEBUG
			
			fi

			##
			## if reorg timeout then issue a stop to current reorgs that are STARTED 
			## no error checking for stopping a reorg
			## no need to update OBJECT array as it will be updated on next loop
			##

			if [ $TB_STATS -eq 1 -o $IX_STATS -eq 2 ]; then

				if [ "$REORG_STATUS" == "STARTED" ] && [ $REORG_TIMEOUT_WINDOW_COMPLETED -eq 1 ] && [ $REORG_TIMEOUT_WINDOW_ACTION -eq 2 ] && [ $REORG_TIMEOUT_WINDOW_COMPLETED_COUNTER -eq 1 ]; then


					if [ $isTable -eq 1 ]; then
						db2 -v "reorg table $TABSCHEMA.$TABNAME inplace stop"
						rc=$?
					elif [ $isIndex -eq 1 ]; then
						db2 -v "reorg table $TABSCHEMA.$TABNAME index $INDSCHEMA.$INDNAME inplace stop"
						rc=$?
					fi

				fi

			fi

		done  ## for OBJECT_ARRAY[@]

		## check if we are done with all OBJECTS
		if [ $((NUM_REORGS_COMPLETED + NUM_REORGS_STOPPED + NUM_REORGS_ABORTED)) -ge $NUM_REORG_OBJECTS ]; then 
			log 3 "All reorgs are completed, stopped or aborted, $NUM_REORGS_COMPLETED:$NUM_REORGS_STOPPED:$NUM_REORGS_ABORTED:$NUM_REORG_OBJECTS"
			break
		fi

		## wait some time
		if [ $IF_STATS -eq 3 ] && [ $IF_STATS_BYPASS_SLEEP_INTERVAL_TIME -eq 1 ]; then
			sleep 1;
			IF_STATS_BYPASS_SLEEP_INTERVAL_TIME=0;
		else
			sleep $SLEEP_INTERVAL_TIME
		fi

	done	## while true

}


## init
if [ -f ${HOME}/sqllib/db2profile ]; then
    . ${HOME}/sqllib/db2profile
fi

## script already running ?
if [ $( ps -ef | grep $0 | grep -v grep | wc -l ) -gt 2 ]; then 
       	echo "Warning: appears $0 already running"
	echo "$( ps -ef | grep $0 | grep -v grep )";
	exit 1
fi

SCRIPT=$(basename $0)
SCRIPT_DIR=$(dirname $0)
WHOAMI=$(whoami)
HOSTNAME=$(hostname)

## setup some temp work files
LOGDATE=$(date '+%Y%m%d');
REORG_TABLE_INDEX_LOG=/tmp/${SCRIPT}.tmp.123.log
rm -f $REORG_TABLE_INDEX_LOG
REORG_TABLE_INDEX_DEBUG=/tmp/${SCRIPT}.debug
rm -f $REORG_TABLE_INDEX_DEBUG

## control variables
LIST_ONLY=0
LIST_FRAGMENTED_INDEXES=0
LIST_VALID_TABLE_SIZES=0
LIST_REORGCHK_TB_STATS_TABLES=0
LIST_REORGCHK_IX_STATS_TABLES=0
EXECUTE_TABLE_REORG=0
IGNORE_TABLE_SIZE_THRESHOLD_MAX=20000;
IGNORE_TABLE_SIZE_THRESHOLD_MIN=10;
MAINTENANCE_TIMEOUT_WINDOW_MINUTES=240;
REORG_TIMEOUT_WINDOW_ACTION=2;
MAX_ASYNC_REORGS_ALLOWED=3;
TRANSACTION_LOG_THRESHOLD_PCT=90;
TB_STATS=0;
IF_STATS=0;
IX_STATS=0;
TRSI=0
IGNORE_TABLES_EX=" and t0.tabname not like '%\_H' escape '\' and t1.volatile != 'C' "
IGNORE_TABLES="";
REORG="*";
SLEEP_INTERVAL_TIME=60;
REORGCHK_TB_IF_STATS_OPTION="";
REORGCHK_TB_STATS=1;
REORGCHK_IF_STATS=3;

## user check
if [ $WHOAMI == "root" ]; then
	log 0 " This script should be not run as '$WHOAMI', but as instance owner."
	exit 1
fi

##
## command line arguments
##
while [ $# -gt 0 ]
do
	case $1 in
		-h|-H|-help|--help)		UsageHelp; exit 1 ;;

		-db)	shift; [ ! -z $1 ] && DB=$( echo $1 | tr '[a-z]' '[A-Z]' ) || { echo "Error: Must enter an argument for this option"; UsageHelp; exit 1 ; } ;;	
		-s)	shift; [ ! -z $1 ] && SCHEMANAME_IN=$( echo $1 | tr '[a-z]' '[A-Z]' ) || { echo "Error: Must enter an argument for this option"; UsageHelp; exit 1 ; } ;;
		-t)	shift; [ ! -z "$1" ] && TABLE_IN=$( echo "$1" | tr '[a-z]' '[A-Z]' ) || { echo "Error: Must enter an argument for this option"; UsageHelp; exit 1 ; } ;;
		-tb_stats) 	REORGCHK_TB_IF_STATS_OPTION+=$REORGCHK_TB_STATS; TB_STATS=1 ;;
		-ti)	shift; [ ! -z "$1" ] && INDEX_IN=$( echo "$1" | tr '[a-z]' '[A-Z]' ) || { echo "Error: Must enter an argument for this option"; UsageHelp; exit 1 ; } ;;	
		-ix_stats)	IX_STATS=2 ;;
		-if_stats)	REORGCHK_TB_IF_STATS_OPTION+=$REORGCHK_IF_STATS; IF_STATS=3 ;;
		-ittx)	shift; isNumeric $1 && { IGNORE_TABLE_SIZE_THRESHOLD_MAX=$1; } || { echo "Error: Must enter an numeric argument for this option"; UsageHelp; exit 1 ; } ;;
		-ittn)	shift; isNumeric $1 && { IGNORE_TABLE_SIZE_THRESHOLD_MIN=$1; } || { echo "Error: Must enter an numeric argument for this option"; UsageHelp; exit 1 ; } ;;

		-l)	LIST_ONLY=1 ;;
		-lf)	LIST_FRAGMENTED_INDEXES=1 ;;
		-ls)	LIST_VALID_TABLE_SIZES=1 ;;
		-lt)	LIST_REORGCHK_TB_STATS_TABLES=1 ;;
		-li)	LIST_REORGCHK_IX_STATS_TABLES=1 ;;

		-window)	shift; isNumeric $1 && { MAINTENANCE_TIMEOUT_WINDOW_MINUTES=$1; } || { echo "Error: Must enter an numeric argument for this option"; UsageHelp; exit 1 ; } ;;
	    	-twa)	shift; isNumeric $1 && { REORG_TIMEOUT_WINDOW_ACTION=$1; } || { echo "Error: Must enter an numeric argument for this option"; UsageHelp; exit 1 ; } ;;
		-mar)	shift; isNumeric $1 && { MAX_ASYNC_REORGS_ALLOWED=$1; } || { echo "Error: Must enter an numeric argument for this option"; UsageHelp; exit 1 ; } ;;
		-log)	shift; isNumeric $1 && { TRANSACTION_LOG_THRESHOLD_PCT=$1; } || { echo "Error: Must enter an numeric argument for this option"; UsageHelp; exit 1 ; } ;;
		-tr)	EXECUTE_TABLE_REORG=1 ;;

		-trsi)	TRSI=1 ;;
		-reorg)	shift; [ ! -z "$1" ] && REORG=$( echo "$1" ) || { echo "Error: Must enter an argument for this option"; UsageHelp; exit 1 ; } ;;	

		-ignore)	shift; [ ! -z "$1" ] && { IGNORE_TABLES="$1"; } || { echo "Error: Must enter an argument for this option"; UsageHelp; exit 1 ; } ;;

		-sleep) shift; isNumeric $1 && { SLEEP_INTERVAL_TIME=$1; } || { echo "Error: Must enter an numeric argument for this option"; UsageHelp; exit 1 ; } ;;

		(-*)    echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
		(*)     break;;
	esac

    shift

done

##
## some verification
##
if [ -z "$SCHEMANAME_IN" ]; then
	log 0 "must enter a schemaname"
	exit 1
fi

CHECK=1
if [ $CHECK -eq 0 ]; then 
	rc=0
	if [ $TB_STATS -eq 1 ] && [ $IX_STATS -eq 2 -o $IF_STATS -eq 3 ]; then
		rc=1;
	elif [ $IX_STATS -eq 2 ] && [ $TB_STATS -eq 1 -o $IF_STATS -eq 3 ]; then
		rc=1;
	elif [ $IF_STATS -eq 3 ] && [ $TB_STATS -eq 1 -o $IX_STATS -eq 2 ]; then 
		rc=1;
	fi
	if [ $rc -eq 1 ]; then
		log 0 "can't define more than one of -tb_stats, -ix_stats or -if_stats"
		exit 1
	fi

fi ## CHECK

if [ $TB_STATS -eq 1 ] && [ ! -z "$INDEX_IN" ]; then
	log 0 "can't define -ti with -tb_stats"
	exit 1
elif [ $IX_STATS -eq 2 ] && [ ! -z "$TABLE_IN" ]; then
	log 0 "can't define -t with -ix_stats"
	exit 1
elif [ $IF_STATS -eq 3 ] && [ ! -z "$INDEX_IN" ]; then
	log 0 "can't define -ti with -if_stats"
	exit 1
fi

if [ $TRANSACTION_LOG_THRESHOLD_PCT -gt 99 ]; then
	log 0 "-log option should be less than 100, TRANSACTION_LOG_THRESHOLD_PCT=$TRANSACTION_LOG_THRESHOLD_PCT"
	exit 1
fi
if [ $IGNORE_TABLE_SIZE_THRESHOLD_MIN -ge $IGNORE_TABLE_SIZE_THRESHOLD_MAX ]; then
	log 0 "option -ittx should be greater than option -ittn"
	exit 1
fi

## override some defaults for offline reorgs
#if [ $IF_STATS -eq 3 ]; then
#	MAX_ASYNC_REORGS_ALLOWED=1;
#	REORG_TIMEOUT_WINDOW_ACTION=1;
#	## make SLEEP_INTERVAL_TIME 1/3 for IF_STATS
#	SLEEP_INTERVAL_TIME=$( echo $SLEEP_INTERVAL_TIME | awk '{ print $1/3 }');
#fi

## fixup REORG filter string for grep
REORG=$( echo "$REORG" | sed 's/*/\\*/g' | sed 's/-/\\-/g');

## need to transform to seconds - easier to work with
## 3/4 time is for reorgs , 1/4 for runstats
MAINTENANCE_TIMEOUT_WINDOW_SECONDS=$(( 60 * MAINTENANCE_TIMEOUT_WINDOW_MINUTES ))
REORG_TIMEOUT_WINDOW_SECONDS=$( echo $MAINTENANCE_TIMEOUT_WINDOW_SECONDS | awk '{ print int(0.75*$1) }');
RUNSTATS_TIMEOUT_WINDOW_SECONDS=$( echo $MAINTENANCE_TIMEOUT_WINDOW_SECONDS | awk '{ print int(0.25*$1) }');

# echo "$MAINTENANCE_TIMEOUT_WINDOW_SECONDS $REORG_TIMEOUT_WINDOW_SECONDS $RUNSTATS_TIMEOUT_WINDOW_SECONDS"

##
## main
##
log 3 "Starting $0 at $(date) on $HOSTNAME"

DBNAMES=$( db2 list db directory | grep -E "alias|Indirect" | grep -B 1 Indirect | grep alias | awk '{print $4}' | sort )

##
## loops for all dbs
##
for DBNAME in $DBNAMES
do

	## just process the one db
	if [ ! -z "$DB" ] && [ "$DB" != "$DBNAME" ] ; then
		continue
	fi

	## can't run script on a STANDBY db
	ROLE=$(db2 "get db cfg for $DBNAME" | grep 'HADR database role' | cut -d '=' -f2 | sed 's/ *//g')
	if [ -z "$ROLE" ] || [ "$ROLE" == "" ]; then
		log 1 " Can't determine hadr database role from 'db2 get db cfg for $DBNAME'"
		continue
	elif [ "$ROLE" == "STANDBY" ]; then
		log 1 " Can't run script '${0}' for $DBNAME with hadr database role '$ROLE'"
		continue
	fi

	log 3 "DB=$DBNAME ..."

	db2 connect to $DBNAME >> /dev/null 2>&1
	rc=$?
	if [ $rc -ne 0 ]; then
		log 0 " can't connect to $DBNAME"
		continue	
	fi

	if [ $TRSI -eq 1 ]; then 
		TRSI
		continue

	elif [ $LIST_VALID_TABLE_SIZES -eq 1 ]; then
		getValidTableSizes
		log 3 "The following $NUM_VALID_TABLES are valid table sizes within the range $IGNORE_TABLE_SIZE_THRESHOLD_MIN MB and $IGNORE_TABLE_SIZE_THRESHOLD_MAX MB\n$VALID_TABLE_SIZES_RAW_DATA"
		continue		

	elif [ $LIST_FRAGMENTED_INDEXES -eq 1 ]; then 
		getValidFragmentedIndexes
		VALID_FRAMENTED_INDEXES_HEADER="TABSCHEMA TABNAME INDSCHEMA INDNAME INDCARD STATS_TIME LAST_USED NLEAF SEQUENTIAL_PAGES";
		log 3 "The following $NUM_VALID_FRAGMENTED_INDEXES are fragmenated indexes based on tables sizes within the range $IGNORE_TABLE_SIZE_THRESHOLD_MIN MB and $IGNORE_TABLE_SIZE_THRESHOLD_MAX MB\n$VALID_FRAMENTED_INDEXES_HEADER\n$VALID_FRAGMENTED_INDEXES_RAW_DATA"
		continue;	
	elif [ $LIST_REORGCHK_TB_STATS_TABLES -eq 1 ]; then
		getValidTablesToReorg
		REORGCHK_TB_STATS_HEADER="TABLE_SCHEMA TABLE_NAME CARD OVERFLOW NPAGES FPAGES ACTIVE_BLOCKS TSIZE F1 F2 F3 REORG";
		log 3 "The following $NUM_VALID_TABLES_TO_REORG are results from REORGCHK_TB_STATS based on tables sizes within the range $IGNORE_TABLE_SIZE_THRESHOLD_MIN MB and $IGNORE_TABLE_SIZE_THRESHOLD_MAX MB\n$REORGCHK_TB_STATS_HEADER\n$VALID_TABLES_TO_REORG_RAW_DATA"
		continue;

	elif [ $LIST_REORGCHK_IX_STATS_TABLES -eq 1 ]; then
		getValidIndexesToReorg
		REORGCHK_IX_STAT_HEADER="TABLE_SCHEMA TABLE_NAME INDEX_SCHEMA INDEX_NAME INDCARD NLEAF NUM_EMPTY_LEAFS NLEVELS NUMRIDS_DELETED FULLKEYCARD LEAF_RECSIZE NONLEAF_RECSIZE LEAF_PAGE_OVERHEAD NONLEAF_PAGE_OVERHEAD PCT_PAGES_SAVED F4 F5 F6 F7 F8 REORG";
		log 3 "The following $NUM_VALID_INDEXES_TO_REORG are results from REORGCHK_IX_STATS based on tables sizes within the range $IGNORE_TABLE_SIZE_THRESHOLD_MIN MB and $IGNORE_TABLE_SIZE_THRESHOLD_MAX MB\n$REORGCHK_IX_STAT_HEADER\n$VALID_INDEXES_TO_REORG_RAW_DATA"
		continue;


	fi


	INPLACE=1
	if [ $INPLACE -eq 1 ]; then

		log 3 " SCHEMA: $SCHEMANAME_IN"
		log 3 " TABLES: $TABLE_IN"
		log 3 "INDEXES: $INDEX_IN"

		##
		## input table(s) verification
		## verify input table exist
		## and table is within size limits
		## create the OBJECT_ARRAY that holds the relevant table information
		##
		if [ ! -z "$TABLE_IN" ]; then

			TABLE_IN=$( echo "$TABLE_IN" | tr ' ' '\n' );
			for TABNAME in $TABLE_IN
			do

				## make sure table exists
				RC=$( db2 -x "select tabname from syscat.tables where tabname = '$TABNAME' and tabschema = '$SCHEMANAME_IN' and type = 'T'");
				rc=$?
				if [ $rc -ne 0 ]; then
					log 0 "input command line table '$TABNAME' does not exist or is invalid"
					exit 1
				fi

				isTableWithinSizeLimit $SCHEMANAME_IN $TABNAME
				rc=$?
				if [ $rc -ne 0 ]; then 
					log 0 "Table $TABNAME is not within the range $IGNORE_TABLE_SIZE_THRESHOLD_MIN MB and $IGNORE_TABLE_SIZE_THRESHOLD_MAX MB"
					exit 1
				fi

			done
	
			if [ $TB_STATS -eq 1 ]; then
				createTableOBJECT_ARRAY "$TABLE_IN" $TB_STATS
			elif [ $IF_STATS -eq 3 ]; then
				createTableOBJECT_ARRAY "$TABLE_IN" $IF_STATS
			fi

		elif [ ${#REORGCHK_TB_IF_STATS_OPTION} -eq 2 ]; then
			for REORG_TYPE in 0 1  
			do
				if [ "${REORGCHK_TB_IF_STATS_OPTION:$REORG_TYPE:1}" == "1" ]; then 
					getValidTablesToReorg
					TABLE_IN="$VALID_TABLES_TO_REORG";
					createTableOBJECT_ARRAY "$TABLE_IN" $TB_STATS
				elif [ "${REORGCHK_TB_IF_STATS_OPTION:$REORG_TYPE:1}" == "3" ]; then 
					getValidFragmentedIndexes
					TABLE_IN="$VALID_FRAGMENTED_INDEXES"
					createTableOBJECT_ARRAY "$TABLE_IN" $IF_STATS
				fi
			done

		elif [ $TB_STATS -eq 1 ]; then 
			getValidTablesToReorg
			TABLE_IN="$VALID_TABLES_TO_REORG";
			createTableOBJECT_ARRAY "$TABLE_IN" $TB_STATS
		elif [ $IF_STATS -eq 3 ]; then 
			getValidFragmentedIndexes
			TABLE_IN="$VALID_FRAGMENTED_INDEXES"
			createTableOBJECT_ARRAY "$TABLE_IN" $IF_STATS
		fi

		## 
		## input indexes verification
		## verify input indexes exist
		##
		if [ ! -z "$INDEX_IN" ]; then
			INDEX_IN=$( echo "$INDEX_IN" | tr ' ' '\n' );
			for INDEX in $INDEX_IN
			do
				## make sure index exists, especially those input on command line
				TABSCHEMA=$( echo $INDEX | cut -d. -f1);
				TABNAME=$( echo $INDEX | cut -d. -f2);
				INDSCHEMA=$( echo $INDEX | cut -d. -f3);
				INDNAME=$( echo $INDEX | cut -d. -f4);
				RC=$( db2 -x "select indname from syscat.indexes where tabschema = '$TABSCHEMA' and tabname = '$TABNAME' and indschema = '$INDSCHEMA' and indname = '$INDNAME'");
				rc=$?
				if [ $rc -ne 0 ]; then
					log 0 " input command line index '$INDEX' does not exist"
					exit 1
				fi

				isTableWithinSizeLimit $TABSCHEMA $TABNAME
				rc=$?
				if [ $rc -ne 0 ]; then 
					log 0 "Table $TABNAME is not within the range $IGNORE_TABLE_SIZE_THRESHOLD_MIN MB and $IGNORE_TABLE_SIZE_THRESHOLD_MAX MB"
					exit 1
				fi

			done

			createIndexOBJECT_ARRAY "$INDEX_IN" $IX_STATS;
		##
		##
		elif [ $IX_STATS -eq 2 ]; then 
			getValidIndexesToReorg
			INDEX_IN="$VALID_INDEXES_TO_REORG"
			createIndexOBJECT_ARRAY "$INDEX_IN" $IX_STATS;
		fi

		## get the NUMBER of tables per reorg table type
		getNUM_OBJECT_REORG_TABLE_TYPE_OBJECT_ARRAY $TB_STATS; OBJECT_NUM_TB_STATS=$?;
		getNUM_OBJECT_REORG_TABLE_TYPE_OBJECT_ARRAY $IX_STATS; OBJECT_NUM_IX_STATS=$?;
		getNUM_OBJECT_REORG_TABLE_TYPE_OBJECT_ARRAY $IF_STATS; OBJECT_NUM_IF_STATS=$?;

		## just list out the OBJECT_ARRAY and exit
		if [ $LIST_ONLY -eq 1 ]; then

			listOBJECT_ARRAY;
			exit 1
		fi

		
		if [ $EXECUTE_TABLE_REORG -eq 1 ]; then


			## 
			## this is the main list of what we are going to reorg
			##
			echo ""

			listOBJECT_ARRAY;

#			exit 1

			##
			## setup some control variables for the main loop
			##  
			## REORG_STATUS COMPLETED PAUSED STARTED STOPPED TRUNCATE
			##
			MAINTENANCE_TIMEOUT_WINDOW_START_TIME_SECONDS=$( date '+%s' );	
			REORG_TIMEOUT_WINDOW_START_TIME_SECONDS=$( date '+%s' );
			WINDOW_START_TIME_DB2=$( date '+%Y-%m-%d-%H.%M.%S' );
			IF_STATS_WINDOW_START_TIME_DB2=$( date '+%s' );
			IF_STATS_BYPASS_SLEEP_INTERVAL_TIME=0;
			NUM_REORG_OBJECTS="${#OBJECT_ARRAY[@]}";
#			NUM_REORGS_IN_PROGRESS=0;
#			NUM_REORGS_KICKED_OFF=0;
#			NUM_REORGS_COMPLETED=0;
#			NUM_REORGS_STOPPED=0;
#			NUM_REORGS_ABORTED=0;
			REORG_TIMEOUT_OVERFLOW_VALVE=300;
			REORG_TIMEOUT_WINDOW_COMPLETED=0;
			REORG_TIMEOUT_WINDOW_COMPLETED_COUNTER=0;
			initTABLE_IN_USE_ARRAY 	$MAX_ASYNC_REORGS_ALLOWED

			## multi table reorg option 
			## online table reorg and offline index reorgs have different options
			MAX_ASYNC_REORGS_ALLOWED_ORG=$MAX_ASYNC_REORGS_ALLOWED;
			REORG_TIMEOUT_WINDOW_ACTION_ORG=$REORG_TIMEOUT_WINDOW_ACTION;
			SLEEP_INTERVAL_TIME_ORG=$SLEEP_INTERVAL_TIME;

			## override some defaults for offline reorgs
			#if [ $IF_STATS -eq 3 ]; then
			#	MAX_ASYNC_REORGS_ALLOWED=1;
			#	REORG_TIMEOUT_WINDOW_ACTION=1;
			#	## make SLEEP_INTERVAL_TIME 1/3 for IF_STATS
			#	SLEEP_INTERVAL_TIME=$( echo $SLEEP_INTERVAL_TIME | awk '{ print $1/3 }');
			#fi

			echo ""
			log 3 "Starting reorg of ..."

			if [ ${#REORGCHK_TB_IF_STATS_OPTION} -eq 2 ]; then
				for REORG_TYPE in 0 1  
				do

					if [ "${REORGCHK_TB_IF_STATS_OPTION:$REORG_TYPE:1}" == "1" ]; then
						TB_STATS=1;
						IF_STATS=0;
						NUM_REORG_OBJECTS=$OBJECT_NUM_TB_STATS;
						REORG_TABLE_TYPE=$TB_STATS;
						MAX_ASYNC_REORGS_ALLOWED=$MAX_ASYNC_REORGS_ALLOWED_ORG;
						REORG_TIMEOUT_WINDOW_ACTION=$REORG_TIMEOUT_WINDOW_ACTION_ORG;
						SLEEP_INTERVAL_TIME=$SLEEP_INTERVAL_TIME_ORG;

					elif [ "${REORGCHK_TB_IF_STATS_OPTION:$REORG_TYPE:1}" == "3" ]; then
						TB_STATS=0;
						IF_STATS=3;
						NUM_REORG_OBJECTS=$OBJECT_NUM_IF_STATS;
						REORG_TABLE_TYPE=$IF_STATS;
						MAX_ASYNC_REORGS_ALLOWED=1;
						REORG_TIMEOUT_WINDOW_ACTION=1;
						SLEEP_INTERVAL_TIME=$( echo $SLEEP_INTERVAL_TIME_ORG | awk '{ print $1/3 }');
					fi

					reorgTables		
				done
			else
				if [ $TB_STATS -eq 1 ]; then
					REORG_TABLE_TYPE=$TB_STATS;
				elif [ $IX_STATS -eq 2 ]; then
					REORG_TABLE_TYPE=$IX_STATS;
				elif [ $IF_STATS -eq 3 ]; then
					REORG_TABLE_TYPE=$IF_STATS;
				fi
				reorgTables
			fi
			
			## list current state of OBJECT_ARRAY
			listOBJECT_ARRAY;

			##
			## now do runstats
			##
			log 3 "Starting runstats of ..."
			RUNSTATS_TIMEOUT_WINDOW_START_TIME_SECONDS=$( date '+%s' );

			for((ii=0; ii< ${#OBJECT_ARRAY[@]}; ii++))
			do

				## check runstats window maintenance time
				MAINTENANCE_TIMEOUT_WINDOW_TIME_NOW_SECONDS=$( date '+%s' );
				DIFF=$(( MAINTENANCE_TIMEOUT_WINDOW_TIME_NOW_SECONDS - REORG_TIMEOUT_WINDOW_START_TIME_SECONDS ));
				if [ $DIFF -ge $(( REORG_TIMEOUT_WINDOW_SECONDS + RUNSTATS_TIMEOUT_WINDOW_SECONDS)) ]; then
					log 3 "$REORG_TIMEOUT_WINDOW_START_TIME_SECONDS 
$MAINTENANCE_TIMEOUT_WINDOW_TIME_NOW_SECONDS $REORG_TIMEOUT_WINDOW_SECONDS $RUNSTATS_TIMEOUT_WINDOW_SECONDS $DIFF"					
					log 3 "Runstats window ending, runstats window time exceeded"
					break
				fi

				## get table info
				TABSCHEMA=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f1 );
				TABNAME=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f2 );
				INDSCHEMA=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f3 );
				INDNAME=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f4 );
				IID=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f5 );
				OBJECT_REORG_STATUS=$( echo ${OBJECT_ARRAY[$ii]} | cut -d# -f6 );

				## only do a runstats if table/index has completed
				## verify stats time so we dont kick off another runstats on the same table
				if [ "$OBJECT_REORG_STATUS" == "COMPLETED" ]; then 
					STATS_TIME=$( db2 -x "select stats_time from syscat.tables where tabschema='$TABSCHEMA' and tabname='$TABNAME' and stats_time < TIMESTAMP('$WINDOW_START_TIME_DB2') " );
					rc=$?
					if [ $rc -eq 0 ]; then	
						log 3 "Starting runstats on $TABSCHEMA.$TABNAME"
						# db2 -v "runstats on table $TABSCHEMA.$TABNAME WITH DISTRIBUTION ON ALL COLUMNS AND SAMPLED DETAILED INDEXES ALL ALLOW WRITE ACCESS";
						db2 -v "runstats on table $TABSCHEMA.$TABNAME WITH DISTRIBUTION ON KEY COLUMNS AND SAMPLED DETAILED INDEXES ALL ALLOW WRITE ACCESS UTIL_IMPACT_PRIORITY 50";
						log 3 "Finished runstats on $TABSCHEMA.$TABNAME"
					fi
				fi

			done

		fi 	## EXECUTE_TABLE_REORG


	fi	## INPLACE


done ## DBNAMES

##
## cleanup
##

log 3 "Completed $0 at $(date)"

exit 0
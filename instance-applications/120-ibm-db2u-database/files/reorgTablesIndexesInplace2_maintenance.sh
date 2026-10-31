#!/bin/bash
#
# ==============================================================================
# Script: reorgs.sh
# Purpose: Perform DB2 online (inplace) table/index reorganizations, offline
#          index reorganizations (REORG INDEXES ALL FOR TABLE), and RUNSTATS
#          based on thresholds, maintenance windows, and log utilization.
# ==============================================================================
#
# -- Modifications/Updates on 01/May/26 by Prudhviraj Patrata
# -- Increased the default tablesize from 20GB to 100GB 
# -- Updated to use single database at a time
# -- Improved the readability of output of logs 
#


# Source DB2 environment if available
if [[ -f "${HOME}/sqllib/db2profile" ]]; then
    # shellcheck disable=SC1090
    . "${HOME}/sqllib/db2profile"
fi

# Ensure bash execution
if [[ -z "${BASH_VERSION:-}" ]]; then
    echo "Error: This script requires bash to run." >&2
    exit 1
fi

# set -x 
# ------------------------------------------------------------------------------
# Constants & Script Info
# ------------------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "$0")"
readonly HOSTNAME_VAL="$(hostname)"
readonly WHOAMI_VAL="$(whoami)"

# ------------------------------------------------------------------------------
# Default Configuration Variables
# ------------------------------------------------------------------------------
DBNAME=""
SCHEMANAME_IN=""
TABLE_IN=""
INDEX_IN=""

LIST_ONLY=0
LIST_FRAGMENTED_INDEXES=0
LIST_VALID_TABLE_SIZES=0
LIST_REORGCHK_TB_STATS_TABLES=0
LIST_REORGCHK_IX_STATS_TABLES=0
EXECUTE_TABLE_REORG=0
TRSI=0

IGNORE_TABLE_SIZE_THRESHOLD_MAX=100000  # in MB (100 GB)
IGNORE_TABLE_SIZE_THRESHOLD_MIN=10      # in MB
MAINTENANCE_TIMEOUT_WINDOW_MINUTES=240
REORG_TIMEOUT_WINDOW_ACTION=2
MAX_ASYNC_REORGS_ALLOWED=3
TRANSACTION_LOG_THRESHOLD_PCT=90
SLEEP_INTERVAL_TIME=60

TB_STATS=0
IF_STATS=0
IX_STATS=0
REORG_TABLE_TYPE=0
REORGCHK_TB_IF_STATS_OPTION=""
readonly REORGCHK_TB_STATS_FLAG=1
readonly REORGCHK_IF_STATS_FLAG=3

IGNORE_TABLES_EX=" and t0.tabname not like '%\_H' escape '\\' and t1.volatile != 'C' "
IGNORE_TABLES=""
REORG="*"

# Temporary logs
REORG_TABLE_INDEX_LOG="/tmp/${SCRIPT_NAME}.tmp.$$.log"
REORG_TABLE_INDEX_DEBUG="/tmp/${SCRIPT_NAME}.debug.$$.log"

# Internal tracking structures
declare -a OBJECT_ARRAY=()
declare -a TABLE_IN_USE_ARRAY=()

VALID_TABLE_SIZES_RAW_DATA=""
VALID_TABLE_SIZES=""
VALID_TABLES=""
NUM_VALID_TABLES=0
VALID_TABLES_FORMATTED=""

VALID_TABLES_TO_REORG_RAW_DATA=""
VALID_TABLES_TO_REORG=""
NUM_VALID_TABLES_TO_REORG=0

VALID_INDEXES_TO_REORG_RAW_DATA=""
VALID_INDEXES_TO_REORG=""
NUM_VALID_INDEXES_TO_REORG=0

VALID_FRAGMENTED_INDEXES_RAW_DATA=""
VALID_FRAGMENTED_INDEXES=""
NUM_VALID_FRAGMENTED_INDEXES=0

OBJECT_NUM_TB_STATS=0
OBJECT_NUM_IX_STATS=0
OBJECT_NUM_IF_STATS=0

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

UsageHelp() {
    cat << EOF
Script to perform DB2 table/index reorganizations online (inplace) 
and offline ("REORG INDEXES ALL FOR TABLE") based on fragmentation/statistics.

Usage: ${SCRIPT_NAME} [options]
Options:
  -h, --help    Displays this usage screen
  -db, -d       Database name (required)
  -s            Table schema name (required)

Reorg Criteria / Targets:
  -t            Table name(s) to reorg (space-delimited in quotes)
  -ti           Table index(es) in TABSCHEMA.TABNAME.INDSCHEMA.INDNAME format
  -tb_stats     Reorg tables reported by REORGCHK_TB_STATS
  -ix_stats     Reorg table indexes reported by REORGCHK_IX_STATS
  -if_stats     Reorg indexes all for table(s) offline based on NLEAF/SEQUENTIAL_PAGES

List / Query Operations:
  -ls           List valid table sizes for schema
  -lf           List fragmented index details for schema
  -lt           List tables to reorg based on REORGCHK_TB_STATS
  -li           List indexes to reorg based on REORGCHK_IX_STATS
  -l            List tables/indexes that would be reorged without executing
  -trsi         Retrieve table reorganization snapshot info from snap_get_tab_reorg & db2pd

Execution & Tuning:
  -tr           Execute inplace table/index reorganization
  -ittx <MB>    Ignore tables over threshold size in MB (default: 100000 MB = 100 GB)
  -ittn <MB>    Ignore tables under threshold size in MB (default: 10 MB)
  -mar <num>    Maximum asynchronous reorgs allowed (default: 3)
  -log <pct>    Skip reorg if transaction log usage exceeds percentage (default: 90%)
  -window <min> Maintenance timeout window in minutes (default: 240)
  -twa <1|2>    Timeout window action (default: 2)
                  1 = Allow current reorg(s) to complete
                  2 = Stop current reorg(s) and abort pending
  -ignore <sql> Additional WHERE predicate for table exclusions
  -reorg <pat>  REORG flag filter (e.g. "*", "***")
  -sleep <sec>  Sleep interval in seconds between monitoring checks (default: 60)

Examples:
  1. ${SCRIPT_NAME} -h
  2. ${SCRIPT_NAME} -db DBNAME -s MAXIMO -ls
  3. ${SCRIPT_NAME} -db DBNAME -s MAXIMO -t "YFS_ITEM YFS_TASK_Q YFS_SHIPMENT" -tb_stats -tr
  4. ${SCRIPT_NAME} -db DBNAME -s MAXIMO -ti "MAXIMO.YFS_SNAPSHOT.MAXIMO.YFS_SNAPSHOT_I1" -ix_stats -tr
  5. ${SCRIPT_NAME} -db DBNAME -s MAXIMO -t "YFS_ITEM YFS_SNAPSHOT" -if_stats -tr
  6. ${SCRIPT_NAME} -db DBNAME -s MAXIMO -tb_stats -mar 5 -window 120 -log 90 -ittx 30000 -tr
  7. ${SCRIPT_NAME} -db DBNAME -s MAXIMO -tb_stats -if_stats -ittx 10000 -ittn 20 -tr
  8. ${SCRIPT_NAME} -db DBNAME -trsi
EOF
}

isNumeric() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

log() {
    local level=$1
    local msg="$2"
    local datestr
    datestr="$(date '+%d-%m-%Y %H:%M:%S')"

    local typemsg="Other"
    case "$level" in
        0) typemsg="Error" ;;
        1) typemsg="Warning" ;;
        3) typemsg="Info" ;;
        5) typemsg="Debug" ;;
    esac

    echo -e "${datestr} ${typemsg} : ${msg}" | tee -a "$REORG_TABLE_INDEX_LOG"
}

cleanup() {
    rm -f "$REORG_TABLE_INDEX_LOG" "$REORG_TABLE_INDEX_DEBUG" /tmp/"${SCRIPT_NAME}".*.tmp
}
trap cleanup EXIT INT TERM

TRSI() {
    db2 -v "select varchar(tabschema,9) as tabschema, varchar(tabname,32) as tabname,
      REORG_STATUS, REORG_COMPLETION, REORG_PHASE, REORG_CURRENT_COUNTER, REORG_MAX_COUNTER, 
      VARCHAR_FORMAT(REORG_START, 'YYYY-MM-DD-HH24:MI:SS') as REORG_START,
      VARCHAR_FORMAT(REORG_END, 'YYYY-MM-DD-HH24:MI:SS') as REORG_END,
      REORG_INDEX_ID, REORG_TBSPC_ID
      from table(snap_get_tab_reorg('')) 
      order by REORG_START asc
      with ur"

    if [[ -n "$DBNAME" ]]; then
        db2pd -db "$DBNAME" -reorgs index | sed -n "/Index Reorg Stats:/,//p" 2>/dev/null || true
    fi
}

initTABLE_IN_USE_ARRAY() {
    local num_items=$1
    TABLE_IN_USE_ARRAY=()
    for ((jj=0; jj<num_items; jj++)); do
        TABLE_IN_USE_ARRAY[jj]=""
    done
}

existTABLE_TABLE_IN_USE_ARRAY() {
    local table="$1"
    local entry
    for entry in "${TABLE_IN_USE_ARRAY[@]}"; do
        if [[ "$entry" == "$table" ]]; then
            return 0
        fi
    done
    return 1
}

addTABLE_TABLE_IN_USE_ARRAY() {
    local table="$1"
    for ((jj=0; jj<${#TABLE_IN_USE_ARRAY[@]}; jj++)); do
        if [[ -z "${TABLE_IN_USE_ARRAY[jj]}" ]]; then
            TABLE_IN_USE_ARRAY[jj]="$table"
            return 0
        fi
    done
    return 1
}

removeTABLE_TABLE_IN_USE_ARRAY() {
    local table="$1"
    for ((jj=0; jj<${#TABLE_IN_USE_ARRAY[@]}; jj++)); do
        if [[ "${TABLE_IN_USE_ARRAY[jj]}" == "$table" ]]; then
            TABLE_IN_USE_ARRAY[jj]=""
            return 0
        fi
    done
    return 1
}

listTABLE_IN_USE_ARRAY() {
    for ((jj=0; jj<${#TABLE_IN_USE_ARRAY[@]}; jj++)); do
        log 5 "TABLE_IN_USE_ARRAY $jj ${TABLE_IN_USE_ARRAY[jj]}"
    done
}

getValidTableSizes() {
    local schemaname="$1"
    local tabname="$2"

    VALID_TABLE_SIZES_RAW_DATA=$(db2 "select char(t0.tabname,40) tabname,
      (( DATA_OBJECT_P_SIZE + INDEX_OBJECT_P_SIZE + LONG_OBJECT_P_SIZE + LOB_OBJECT_P_SIZE + XML_OBJECT_P_SIZE ) / 1024 ) as TOTAL_TABLE_MB,
      cast ((INDEX_OBJECT_P_SIZE / 1024 ) as integer) as INDEX_SIZE_MB   
      from TABLE(SYSPROC.ADMIN_GET_TAB_INFO('$schemaname', '$tabname')) as t0 , SYSCAT.TABLES t1
      where t0.tabschema=t1.tabschema
      and t0.tabname=t1.tabname
      $IGNORE_TABLES
      and (( DATA_OBJECT_P_SIZE + INDEX_OBJECT_P_SIZE + LONG_OBJECT_P_SIZE + LOB_OBJECT_P_SIZE + XML_OBJECT_P_SIZE ) / 1024 ) < $IGNORE_TABLE_SIZE_THRESHOLD_MAX
      and (( DATA_OBJECT_P_SIZE + INDEX_OBJECT_P_SIZE + LONG_OBJECT_P_SIZE + LOB_OBJECT_P_SIZE + XML_OBJECT_P_SIZE ) / 1024 ) > $IGNORE_TABLE_SIZE_THRESHOLD_MIN
      order by 2 desc
      with ur")
    local rc=$?

    if [[ $rc -eq 0 && -n "$VALID_TABLE_SIZES_RAW_DATA" ]]; then
        VALID_TABLE_SIZES=$(echo "$VALID_TABLE_SIZES_RAW_DATA" | sed '1,3d' | sed '$d' | sed '$d' | awk 'BEGIN {ORS="\t"} { for(ii=1 ; ii<=NF ; ii++) print $ii; printf "\n"; }')
        VALID_TABLES=$(echo "$VALID_TABLE_SIZES" | awk '{print $1}')
        if [[ -n "$VALID_TABLES" ]]; then
            NUM_VALID_TABLES=$(echo "$VALID_TABLES" | grep -c -v '^[[:space:]]*$')
            VALID_TABLES_FORMATTED=""
            for tbl in $VALID_TABLES; do
                VALID_TABLES_FORMATTED="${VALID_TABLES_FORMATTED}'$tbl',"
            done
            VALID_TABLES_FORMATTED="${VALID_TABLES_FORMATTED%,}"
        else
            NUM_VALID_TABLES=0
            VALID_TABLES_FORMATTED="'UNKNOWN_TABNAME'"
        fi
    else
        VALID_TABLES=""
        NUM_VALID_TABLES=0
        VALID_TABLES_FORMATTED="'UNKNOWN_TABNAME'"
    fi
}

getValidTablesToReorg() {
    VALID_TABLES_TO_REORG=""
    VALID_TABLES_TO_REORG_RAW_DATA=""
    NUM_VALID_TABLES_TO_REORG=0

    # Step 1: Identify all tables in the schema that need reorg via REORGCHK_TB_STATS
    # Run REORGCHK_TB_STATS first to populate SESSION.TB_STATS, then query it separately.
    local reorgchk_raw
    reorgchk_raw=$(db2 -x "call SYSPROC.REORGCHK_TB_STATS('S','$SCHEMANAME_IN')" >/dev/null | db2 -x "select rtrim(TABLE_SCHEMA), rtrim(TABLE_NAME), CARD, OVERFLOW, NPAGES, FPAGES, ACTIVE_BLOCKS, TSIZE, F1, F2, F3, REORG from SESSION.TB_STATS where REORG like '%*%' order by TABLE_SCHEMA,TABLE_NAME with UR" 2>/dev/null | awk '{ if (NF == 12) print $0 }' | sed 's/ \+/ /g' )
    if [[ -z "$reorgchk_raw" ]]; then
        return
    fi

    # Step 2: For each candidate table returned by reorgchk, validate its size
    getValidTableSizes "$SCHEMANAME_IN" ""

    while IFS= read -r row; do
        local tab
        tab=$(echo "$row" | awk '{print $2}')
        if echo "$VALID_TABLES" | grep -qw "$tab"; then
            if [[ -z "$VALID_TABLES_TO_REORG_RAW_DATA" ]]; then
                VALID_TABLES_TO_REORG_RAW_DATA="$row"
            else
                VALID_TABLES_TO_REORG_RAW_DATA="${VALID_TABLES_TO_REORG_RAW_DATA}"$'\n'"$row"
            fi
        fi
    done <<< "$reorgchk_raw"

    if [[ -n "$VALID_TABLES_TO_REORG_RAW_DATA" ]]; then
        VALID_TABLES_TO_REORG_RAW_DATA=$(echo "$VALID_TABLES_TO_REORG_RAW_DATA" | sort -k12 -r)
        VALID_TABLES_TO_REORG=$(echo "$VALID_TABLES_TO_REORG_RAW_DATA" | awk '{print $2}')
        NUM_VALID_TABLES_TO_REORG=$(echo "$VALID_TABLES_TO_REORG" | grep -c -v '^[[:space:]]*$')
    fi
}

getValidIndexesToReorg() {
    VALID_INDEXES_TO_REORG=""
    VALID_INDEXES_TO_REORG_RAW_DATA=""
    NUM_VALID_INDEXES_TO_REORG=0

    # Step 1: Identify all indexes in the schema that need reorg via REORGCHK_IX_STATS
    # Run REORGCHK_IX_STATS first to populate SESSION.IX_STATS, then query it separately.
    local reorgchk_raw
    reorgchk_raw=$(db2 -x "call SYSPROC.REORGCHK_IX_STATS('S','$SCHEMANAME_IN')" >/dev/null | db2 -x "select rtrim(TABLE_SCHEMA), rtrim(TABLE_NAME), rtrim(INDEX_SCHEMA), rtrim(INDEX_NAME), INDCARD, NLEAF, NUM_EMPTY_LEAFS, NLEVELS, NUMRIDS_DELETED, FULLKEYCARD, LEAF_RECSIZE, NONLEAF_RECSIZE, LEAF_PAGE_OVERHEAD, NONLEAF_PAGE_OVERHEAD, PCT_PAGES_SAVED, F4, F5, F6, F7, F8, REORG from SESSION.IX_STATS where REORG like '%*%' order by INDEX_SCHEMA, INDEX_NAME with UR" 2>/dev/null | awk '{ if (NF == 21) print $0 }' | sed 's/ \+/ /g' )

    if [[ -z "$reorgchk_raw" ]]; then
        return
    fi

    # Step 2: For each candidate index returned by reorgchk, validate its base table size
    getValidTableSizes "$SCHEMANAME_IN" ""

    while IFS= read -r row; do
        local tab
        tab=$(echo "$row" | awk '{print $2}')
        if echo "$VALID_TABLES" | grep -qw "$tab"; then
            if [[ -z "$VALID_INDEXES_TO_REORG_RAW_DATA" ]]; then
                VALID_INDEXES_TO_REORG_RAW_DATA="$row"
            else
                VALID_INDEXES_TO_REORG_RAW_DATA="${VALID_INDEXES_TO_REORG_RAW_DATA}"$'\n'"$row"
            fi
        fi
    done <<< "$reorgchk_raw"

    if [[ -n "$VALID_INDEXES_TO_REORG_RAW_DATA" ]]; then
        VALID_INDEXES_TO_REORG_RAW_DATA=$(echo "$VALID_INDEXES_TO_REORG_RAW_DATA" | sort -k21 -r)
        VALID_INDEXES_TO_REORG=$(echo "$VALID_INDEXES_TO_REORG_RAW_DATA" | awk '{print $1"."$2"."$3"."$4}')
        NUM_VALID_INDEXES_TO_REORG=$(echo "$VALID_INDEXES_TO_REORG" | grep -c -v '^[[:space:]]*$')
    fi
}

getValidFragmentedIndexes() {
    getValidTableSizes "$SCHEMANAME_IN" ""

    VALID_FRAGMENTED_INDEXES_RAW_DATA=$(db2 -x "select rtrim(tabschema)||' '||rtrim(tabname)||' '||rtrim(indschema)||' '||rtrim(indname)
        ||' '||indcard||' '||stats_time||' '||lastused||' '||nleaf||' '||sequential_pages 
        from syscat.indexes where tabschema='$SCHEMANAME_IN' 
        and not (nleaf = 1 and sequential_pages = 0) 
        and not (nleaf = 0 and sequential_pages = 1) 
        and (nleaf - sequential_pages > 10)
        and tabname in ( $VALID_TABLES_FORMATTED )
        order by tabname, indname
        with ur" 2>/dev/null || true)

    VALID_FRAGMENTED_INDEXES_RAW_DATA=$(echo "${VALID_FRAGMENTED_INDEXES_RAW_DATA}" | sed 's/ *$//g' | grep -v '^[[:space:]]*$' || true)
    if [[ -n "$VALID_FRAGMENTED_INDEXES_RAW_DATA" ]]; then
        VALID_FRAGMENTED_INDEXES=$(echo "${VALID_FRAGMENTED_INDEXES_RAW_DATA}" | cut -d' ' -f2 | sort -u)
        NUM_VALID_FRAGMENTED_INDEXES=$(echo "${VALID_FRAGMENTED_INDEXES}" | grep -c -v '^[[:space:]]*$')
    else
        VALID_FRAGMENTED_INDEXES=""
        NUM_VALID_FRAGMENTED_INDEXES=0
    fi
}

isTableWithinSizeLimit() {
    local schemaname="$1"
    local tabname="$2"

    local res
    res=$(db2 -x "select tabname,
      ( ( sum(DATA_OBJECT_P_SIZE) + sum(INDEX_OBJECT_P_SIZE) + sum(LONG_OBJECT_P_SIZE) + sum(LOB_OBJECT_P_SIZE) + sum(XML_OBJECT_P_SIZE) ) / 1024 ) as TOTAL_TABLE_MB
      from TABLE(SYSPROC.ADMIN_GET_TAB_INFO('$schemaname', '$tabname')) as t
      group by tabschema, tabname
      having ( ( sum(DATA_OBJECT_P_SIZE) + sum(INDEX_OBJECT_P_SIZE) + sum(LONG_OBJECT_P_SIZE) + sum(LOB_OBJECT_P_SIZE) + sum(XML_OBJECT_P_SIZE) ) / 1024 ) < $IGNORE_TABLE_SIZE_THRESHOLD_MAX
      and ( ( sum(DATA_OBJECT_P_SIZE) + sum(INDEX_OBJECT_P_SIZE) + sum(LONG_OBJECT_P_SIZE) + sum(LOB_OBJECT_P_SIZE) + sum(XML_OBJECT_P_SIZE) ) / 1024 ) > $IGNORE_TABLE_SIZE_THRESHOLD_MIN
      with ur" 2>/dev/null | grep -v '^[[:space:]]*$' || true)

    [[ -n "$res" ]]
}

createTableOBJECT_ARRAY() {
    local tabnames="$1"
    local object_reorg_table_type="$2"
    local idx=${#OBJECT_ARRAY[@]}
    local tid=0
    local indschema="NULL"
    local indname="NULL"
    local lock_count=0

    for tab in $tabnames; do
        local rc_out
        rc_out=$(db2 -x "select TABLEID, TBSPACEID from syscat.tables where tabname='$tab' and tabschema='$SCHEMANAME_IN' order by tabschema, tabname " 2>/dev/null || true)
        local tableid
        local tbspaceid
        tableid=$(echo "$rc_out" | awk '{print $1}')
        tbspaceid=$(echo "$rc_out" | awk '{print $2}')
        if [[ -n "$tableid" && -n "$tbspaceid" ]]; then
            OBJECT_ARRAY[idx]="$SCHEMANAME_IN#$tab#$indschema#$indname#$tid#NOTSTARTED#-#-#$tableid#$tbspaceid#$lock_count#$object_reorg_table_type"
            ((idx++))
        fi
    done
}

createIndexOBJECT_ARRAY() {
    local indnames="$1"
    local object_reorg_table_type="$2"
    local idx=${#OBJECT_ARRAY[@]}
    local tableid=9999
    local tbspaceid=9999
    local lock_count=0

    for ind in $indnames; do
        local tabschema tabname indschema indname
        tabschema=$(echo "$ind" | cut -d. -f1)
        tabname=$(echo "$ind" | cut -d. -f2)
        indschema=$(echo "$ind" | cut -d. -f3)
        indname=$(echo "$ind" | cut -d. -f4)

        local rc_out
        rc_out=$(db2 -x "select IID from syscat.indexes where tabschema = '$tabschema' and tabname = '$tabname' and indschema = '$indschema' and indname = '$indname' order by indschema, indname " 2>/dev/null || true)
        local iid
        iid=$(echo "$rc_out" | awk '{print $1}')
        if [[ -n "$iid" ]]; then
            OBJECT_ARRAY[idx]="$tabschema#$tabname#$indschema#$indname#$iid#NOTSTARTED#-#-#$tableid#$tbspaceid#$lock_count#$object_reorg_table_type"
            ((idx++))
        fi
    done
}

listOBJECT_ARRAY() {
    log 3 "Objects in queue: Total=${#OBJECT_ARRAY[@]} (TB_STATS:${OBJECT_NUM_TB_STATS}, IX_STATS:${OBJECT_NUM_IX_STATS}, IF_STATS:${OBJECT_NUM_IF_STATS})"
    printf "%-15s %-40s %-15s %-40s %-14s %-20s %-20s %-8s \n" \
        "TABSCHEMA" "TABNAME" "INDSCHEMA" "INDNAME" "REORG_STATUS" "REORG_START" "REORG_END" "LOCK_COUNT"

    for entry in "${OBJECT_ARRAY[@]}"; do
        IFS="#" read -r tabschema tabname indschema indname iid reorg_status obj_start obj_end tableid tbspaceid lock_count obj_type <<< "$entry"
        printf "%-15s %-40s %-15s %-40s %-14s %-20s %-20s %-8s \n" \
            "$tabschema" "$tabname" "$indschema" "$indname" "$reorg_status" "$obj_start" "$obj_end" "$lock_count"
    done
}

getNUM_OBJECT_REORG_TABLE_TYPE_OBJECT_ARRAY() {
    local target_type="$1"
    local count=0
    for entry in "${OBJECT_ARRAY[@]}"; do
        local obj_type
        obj_type=$(echo "$entry" | cut -d# -f12)
        if [[ "$obj_type" -eq "$target_type" ]]; then
            ((count++))
        fi
    done
    return "$count"
}

reorgTables() {
    local num_reorgs_in_progress=0
    local num_reorgs_kicked_off=0
    local num_reorgs_completed=0
    local num_reorgs_stopped=0
    local num_reorgs_aborted=0

    local reorg_timeout_window_completed=0
    local reorg_timeout_window_completed_counter=0
    local if_stats_bypass_sleep=0

    while true; do
        local now_seconds diff
        now_seconds=$(date '+%s')
        diff=$(( now_seconds - REORG_TIMEOUT_WINDOW_START_TIME_SECONDS ))

        # Overflow valve: safety abort if runaway
        if [[ $diff -ge $(( REORG_TIMEOUT_WINDOW_SECONDS + REORG_TIMEOUT_OVERFLOW_VALVE )) ]]; then
            log 1 "REORG_TIMEOUT_OVERFLOW_VALVE detected. Aborting reorgs."
            break
        fi

        # Maintenance window timeout check
        if [[ $diff -ge $REORG_TIMEOUT_WINDOW_SECONDS ]]; then
            reorg_timeout_window_completed=1
            if [[ $REORG_TIMEOUT_WINDOW_ACTION -eq 1 ]]; then
                log 3 "Reorg window time exceeded. Action=1 (allow current to complete)."
                break
            elif [[ $REORG_TIMEOUT_WINDOW_ACTION -eq 2 ]]; then
                if [[ $reorg_timeout_window_completed_counter -eq 0 ]]; then
                    ((reorg_timeout_window_completed_counter++))
                    log 3 "Reorg window time exceeded. Aborting NOTSTARTED and issuing STOP to STARTED."
                elif [[ $reorg_timeout_window_completed_counter -eq 1 ]]; then
                    ((reorg_timeout_window_completed_counter++))
                elif [[ $reorg_timeout_window_completed_counter -ge 2 ]]; then
                    log 3 "Breaking out of reorg loop after cleanup."
                    break
                fi
            fi
        fi

        # Process each object in array
        for ((ii=0; ii<${#OBJECT_ARRAY[@]}; ii++)); do
            IFS="#" read -r tabschema tabname indschema indname iid obj_status obj_start obj_end tableid tbspaceid lock_count obj_table_type <<< "${OBJECT_ARRAY[ii]}"

            # Only process matching reorg table type
            if [[ "$obj_table_type" -ne "$REORG_TABLE_TYPE" ]]; then
                continue
            fi

            # Skip completed/stopped/aborted
            if [[ "$obj_status" =~ ^(COMPLETED|STOPPED|ABORTED)$ ]]; then
                continue
            fi

            local is_table=0 is_index=0
            if [[ "$indschema" == "NULL" && "$indname" == "NULL" ]]; then
                is_table=1
            else
                is_index=1
            fi

            local live_status="" live_start="" live_end="" percent_complete=0 live_index_status=""

            # Query status for TB_STATS (1) / IX_STATS (2)
            if [[ $TB_STATS -eq 1 || $IX_STATS -eq 2 ]]; then
                local snap_raw
                snap_raw=$(db2 -x "select REORG_STATUS, REORG_COMPLETION, REORG_PHASE, REORG_CURRENT_COUNTER, REORG_MAX_COUNTER, VARCHAR_FORMAT(REORG_START, 'YYYY-MM-DD-HH24:MI:SS'), VARCHAR_FORMAT(REORG_END, 'YYYY-MM-DD-HH24:MI:SS'), REORG_INDEX_ID from table(snap_get_tab_reorg('')) where tabschema='$tabschema' and tabname='$tabname' and REORG_START > TIMESTAMP('$WINDOW_START_TIME_DB2') and REORG_INDEX_ID=$iid" 2>/dev/null || true)
                
                if [[ -n "$snap_raw" ]]; then
                    live_status=$(echo "$snap_raw" | awk '{print $1}')
                    local cur_counter max_counter
                    cur_counter=$(echo "$snap_raw" | awk '{print $4}')
                    max_counter=$(echo "$snap_raw" | awk '{print $5}')
                    live_start=$(echo "$snap_raw" | awk '{print $6}')
                    live_end=$(echo "$snap_raw" | awk '{print $7}')

                    if [[ -n "$cur_counter" && -n "$max_counter" && "$max_counter" -gt 0 && "$cur_counter" -gt 0 ]]; then
                        if [[ "$max_counter" -ge "$cur_counter" ]]; then
                            percent_complete=$(( cur_counter * 100 / max_counter ))
                        fi
                    fi
                fi

            # Query status for IF_STATS (3)
            elif [[ $IF_STATS -eq 3 ]]; then
                local pd_record
                pd_record=$(db2pd -db "$DBNAME" -reorgs index 2>/dev/null | grep -B1 -A11 -w "^TbspaceID: $tbspaceid" | grep -B1 -A11 -w "TableID: $tableid" || true)
                if [[ -n "$pd_record" ]]; then
                    local rec_start
                    rec_start=$(echo "$pd_record" | grep '^Start Time:' | awk '{ print $3,$4}' || true)
                    local rec_start_sec=0
                    if [[ -n "$rec_start" ]]; then
                        rec_start_sec=$(date -d "$rec_start" '+%s' 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$rec_start" '+%s' 2>/dev/null || echo 0)
                    fi

                    if [[ $rec_start_sec -ge $IF_STATS_WINDOW_START_TIME_DB2 ]]; then
                        local raw_status
                        raw_status=$(echo "$pd_record" | grep '^Status:' | awk '{ $1=""; print $0}' | sed 's/^[ \t]*//;s/[ \t]*$//' || true)
                        case "$raw_status" in
                            "In Progress") live_status="STARTED" ;;
                            "Completed")   live_status="COMPLETED" ;;
                            "Stopped")     live_status="STOPPED" ;;
                            *)             live_status="$raw_status" ;;
                        esac
                        live_end=$(echo "$pd_record" | grep '^Start Time:' | grep 'End Time:' | awk '{ print $7,$8}' || true)
                        local ind_status ind_cur
                        ind_status=$(echo "$pd_record" | grep "Status:" || true)
                        ind_cur=$(echo "$pd_record" | grep "Cur Index:" || true)
                        live_index_status=$(printf "%-25s %-10s" "$ind_status" "$ind_cur")
                    fi
                fi
            fi

            # Update state for KICKED_OFF or STARTED tasks
            if [[ "$obj_status" =~ ^(KICKED_OFF|STARTED)$ ]]; then
                if [[ -n "$live_status" ]]; then
                    if [[ "$live_status" =~ ^(STARTED|COMPLETED|STOPPED)$ ]]; then
                        obj_status="$live_status"
                        OBJECT_ARRAY[ii]="$tabschema#$tabname#$indschema#$indname#$iid#$obj_status#$live_start#$live_end#$tableid#$tbspaceid#$lock_count#$obj_table_type"
                    fi

                    if [[ "$live_status" =~ ^(COMPLETED|STOPPED)$ ]]; then
                        removeTABLE_TABLE_IN_USE_ARRAY "$tabschema.$tabname" || log 1 "Failed to remove $tabschema.$tabname from in-use tracking"
                        if [[ "$live_status" == "COMPLETED" ]]; then
                            ((num_reorgs_completed++))
                        else
                            ((num_reorgs_stopped++))
                        fi
                        ((num_reorgs_in_progress--))
                    fi
                fi

            # Kick off reorg for NOTSTARTED objects
            elif [[ "$obj_status" == "NOTSTARTED" ]]; then
                # Handle timeout abort
                if [[ $reorg_timeout_window_completed -eq 1 && $REORG_TIMEOUT_WINDOW_ACTION -eq 2 && $reorg_timeout_window_completed_counter -eq 1 ]]; then
                    obj_status="ABORTED"
                    OBJECT_ARRAY[ii]="$tabschema#$tabname#$indschema#$indname#$iid#$obj_status#$obj_start#$obj_end#$tableid#$tbspaceid#$lock_count#$obj_table_type"
                    ((num_reorgs_aborted++))
                    continue
                fi

                # Check if table is already being reorganized
                if existTABLE_TABLE_IN_USE_ARRAY "$tabschema.$tabname"; then
                    continue
                fi

                # Check concurrency limit
                if [[ $num_reorgs_in_progress -ge $MAX_ASYNC_REORGS_ALLOWED ]]; then
                    continue
                fi

                # Check table locks (Abort after 10 failed lock checks)
                local table_locked
                table_locked=$(db2 -x "select APPLICATION_HANDLE from TABLE (MON_GET_LOCKS(NULL, -2)) where TBSP_ID=$tbspaceid and TAB_FILE_ID=$tableid and LOCK_OBJECT_TYPE='TABLE' and LOCK_MODE='IX' with ur" 2>/dev/null | grep -v '^[[:space:]]*$' || true)
                if [[ -n "$table_locked" ]]; then
                    ((lock_count++))
                    log 1 "Table $tabschema.$tabname is currently locked (attempt: $lock_count)"
                    if [[ $lock_count -gt 10 ]]; then
                        obj_status="ABORTED"
                        ((num_reorgs_aborted++))
                        log 1 "Aborting reorg on $tabschema.$tabname due to persistent lock contention."
                    fi
                    OBJECT_ARRAY[ii]="$tabschema#$tabname#$indschema#$indname#$iid#$obj_status#$obj_start#$obj_end#$tableid#$tbspaceid#$lock_count#$obj_table_type"
                    continue
                fi

                # Check transaction log utilization
                local log_used pct_used
                log_used=$(db2 -x "select LOG_UTILIZATION_PERCENT FROM SYSIBMADM.MON_TRANSACTION_LOG_UTILIZATION" 2>/dev/null | tr -d ' ' || true)
                if [[ -n "$log_used" ]]; then
                    pct_used=$(echo "$log_used" | awk '{print int($1)}')
                    if [[ -n "$pct_used" && "$pct_used" -gt "$TRANSACTION_LOG_THRESHOLD_PCT" ]]; then
                        log 1 "Log utilization is at ${log_used}%, exceeding threshold (${TRANSACTION_LOG_THRESHOLD_PCT}%). Postponing new reorgs."
                        continue
                    fi
                fi

                # Launch reorganization
                local exec_rc=0
                if [[ $TB_STATS -eq 1 || $IX_STATS -eq 2 ]]; then
                    if [[ $is_table -eq 1 ]]; then
                        log 3 "Launching online table reorg for $tabschema.$tabname"
                        db2 "reorg table $tabschema.$tabname inplace allow write access" >/dev/null 2>&1
                        exec_rc=$?
                    elif [[ $is_index -eq 1 ]]; then
                        log 3 "Launching online index reorg for $tabschema.$tabname ($indschema.$indname)"
                        db2 "reorg table $tabschema.$tabname index $indschema.$indname inplace allow write access" >/dev/null 2>&1
                        exec_rc=$?
                    fi
                elif [[ $IF_STATS -eq 3 ]]; then
                    local tmplog="/tmp/${SCRIPT_NAME}.$tabschema.$tabname.$$.tmp"
                    log 3 "Launching offline index reorg (allow write access) for $tabschema.$tabname"
                    db2 -v "reorg indexes all for table $tabschema.$tabname allow write access" > "$tmplog" 2>&1 &
                    sleep 5
                    if grep -q '^SQL' "$tmplog" 2>/dev/null; then
                        log 1 "Failed to initiate reorg on $tabschema.$tabname: $(grep '^SQL' "$tmplog")"
                        exec_rc=1
                    else
                        if grep -q 'DB20000I' "$tmplog" 2>/dev/null; then
                            if_stats_bypass_sleep=1
                        fi
                        exec_rc=0
                    fi
                    rm -f "$tmplog"
                fi

                if [[ $exec_rc -eq 0 ]]; then
                    obj_status="KICKED_OFF"
                    addTABLE_TABLE_IN_USE_ARRAY "$tabschema.$tabname"
                    ((num_reorgs_kicked_off++))
                    ((num_reorgs_in_progress++))
                else
                    obj_status="ABORTED"
                    ((num_reorgs_aborted++))
                fi

                OBJECT_ARRAY[ii]="$tabschema#$tabname#$indschema#$indname#$iid#$obj_status#$obj_start#$obj_end#$tableid#$tbspaceid#$lock_count#$obj_table_type"
                continue
            fi

            # Log current running status
            local status_summary="${num_reorgs_in_progress}:${num_reorgs_kicked_off}:${num_reorgs_aborted}:${num_reorgs_stopped}:${num_reorgs_completed}:${NUM_REORG_OBJECTS}"
            if [[ $TB_STATS -eq 1 || $IX_STATS -eq 2 ]]; then
                printf "%-15s %-45s %-15s COMPLETION: %d%%\n" "$status_summary" "$tabschema.$tabname" "$obj_status" "$percent_complete" | tee -a "$REORG_TABLE_INDEX_DEBUG"
            elif [[ $IF_STATS -eq 3 ]]; then
                printf "%-15s %-45s %-25s\n" "$status_summary" "$tabschema.$tabname" "$live_index_status" | tee -a "$REORG_TABLE_INDEX_DEBUG"
            fi

            # Handle timeout stop for running reorgs
            if [[ $TB_STATS -eq 1 || $IX_STATS -eq 2 ]]; then
                if [[ "$obj_status" == "STARTED" && $reorg_timeout_window_completed -eq 1 && $REORG_TIMEOUT_WINDOW_ACTION -eq 2 && $reorg_timeout_window_completed_counter -eq 1 ]]; then
                    if [[ $is_table -eq 1 ]]; then
                        db2 -v "reorg table $tabschema.$tabname inplace stop" >/dev/null 2>&1 || true
                    elif [[ $is_index -eq 1 ]]; then
                        db2 -v "reorg table $tabschema.$tabname index $indschema.$indname inplace stop" >/dev/null 2>&1 || true
                    fi
                fi
            fi

        done # end for OBJECT_ARRAY

        # Check termination condition
        if [[ $(( num_reorgs_completed + num_reorgs_stopped + num_reorgs_aborted )) -ge $NUM_REORG_OBJECTS ]]; then
            log 3 "Reorg Summary -> Completed: $num_reorgs_completed | Stopped: $num_reorgs_stopped | Aborted: $num_reorgs_aborted | Total: $NUM_REORG_OBJECTS"
            break
        fi

        # Sleep interval between polls
        if [[ $REORG_TABLE_TYPE -eq 3 && $if_stats_bypass_sleep -eq 1 ]]; then
            sleep 1
            if_stats_bypass_sleep=0
        else
            sleep "$SLEEP_INTERVAL_TIME"
        fi

    done
}

# ------------------------------------------------------------------------------
# Script Pre-checks
# ------------------------------------------------------------------------------

# Root execution prevention
if [[ "$WHOAMI_VAL" == "root" ]]; then
    echo "Error: This script must be run as the DB2 instance owner, not root." >&2
    exit 1
fi

# Concurrency lock check
running_instances=$(pgrep -f "${SCRIPT_NAME}" | grep -v "$$" | wc -l)
if [[ $running_instances -gt 1 ]]; then
    echo "Warning: Another instance of ${SCRIPT_NAME} is already running." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|-H|-help|--help)
            UsageHelp
            exit 0
            ;;
        -db|-d)
            shift
            [[ -n "${1:-}" ]] && DBNAME="$(echo "$1" | tr '[:lower:]' '[:upper:]')" || { echo "Error: -db requires an argument"; UsageHelp; exit 1; }
            ;;
        -s)
            shift
            [[ -n "${1:-}" ]] && SCHEMANAME_IN="$(echo "$1" | tr '[:lower:]' '[:upper:]')" || { echo "Error: -s requires an argument"; UsageHelp; exit 1; }
            ;;
        -t)
            shift
            [[ -n "${1:-}" ]] && TABLE_IN="$(echo "$1" | tr '[:lower:]' '[:upper:]')" || { echo "Error: -t requires an argument"; UsageHelp; exit 1; }
            ;;
        -tb_stats)
            REORGCHK_TB_IF_STATS_OPTION+="$REORGCHK_TB_STATS_FLAG"
            TB_STATS=1
            ;;
        -ti)
            shift
            [[ -n "${1:-}" ]] && INDEX_IN="$(echo "$1" | tr '[:lower:]' '[:upper:]')" || { echo "Error: -ti requires an argument"; UsageHelp; exit 1; }
            ;;
        -ix_stats)
            IX_STATS=2
            ;;
        -if_stats)
            REORGCHK_TB_IF_STATS_OPTION+="$REORGCHK_IF_STATS_FLAG"
            IF_STATS=3
            ;;
        -ittx)
            shift
            if isNumeric "${1:-}"; then
                IGNORE_TABLE_SIZE_THRESHOLD_MAX="$1"
            else
                echo "Error: -ittx requires a numeric argument"; UsageHelp; exit 1
            fi
            ;;
        -ittn)
            shift
            if isNumeric "${1:-}"; then
                IGNORE_TABLE_SIZE_THRESHOLD_MIN="$1"
            else
                echo "Error: -ittn requires a numeric argument"; UsageHelp; exit 1
            fi
            ;;
        -l)
            LIST_ONLY=1
            ;;
        -lf)
            LIST_FRAGMENTED_INDEXES=1
            ;;
        -ls)
            LIST_VALID_TABLE_SIZES=1
            ;;
        -lt)
            LIST_REORGCHK_TB_STATS_TABLES=1
            ;;
        -li)
            LIST_REORGCHK_IX_STATS_TABLES=1
            ;;
        -window)
            shift
            if isNumeric "${1:-}"; then
                MAINTENANCE_TIMEOUT_WINDOW_MINUTES="$1"
            else
                echo "Error: -window requires a numeric argument"; UsageHelp; exit 1
            fi
            ;;
        -twa)
            shift
            if isNumeric "${1:-}"; then
                REORG_TIMEOUT_WINDOW_ACTION="$1"
            else
                echo "Error: -twa requires a numeric argument"; UsageHelp; exit 1
            fi
            ;;
        -mar)
            shift
            if isNumeric "${1:-}"; then
                MAX_ASYNC_REORGS_ALLOWED="$1"
            else
                echo "Error: -mar requires a numeric argument"; UsageHelp; exit 1
            fi
            ;;
        -log)
            shift
            if isNumeric "${1:-}"; then
                TRANSACTION_LOG_THRESHOLD_PCT="$1"
            else
                echo "Error: -log requires a numeric argument"; UsageHelp; exit 1
            fi
            ;;
        -tr)
            EXECUTE_TABLE_REORG=1
            ;;
        -trsi)
            TRSI=1
            ;;
        -reorg)
            shift
            [[ -n "${1:-}" ]] && REORG="$1" || { echo "Error: -reorg requires an argument"; UsageHelp; exit 1; }
            ;;
        -ignore)
            shift
            [[ -n "${1:-}" ]] && IGNORE_TABLES="$1" || { echo "Error: -ignore requires an argument"; UsageHelp; exit 1; }
            ;;
        -sleep)
            shift
            if isNumeric "${1:-}"; then
                SLEEP_INTERVAL_TIME="$1"
            else
                echo "Error: -sleep requires a numeric argument"; UsageHelp; exit 1
            fi
            ;;
        -*)
            echo "Error: Unrecognized option '$1'" >&2
            UsageHelp
            exit 1
            ;;
        *)
            break
            ;;
    esac
    shift
done

# ------------------------------------------------------------------------------
# Input Validations
# ------------------------------------------------------------------------------
if [[ -z "$DBNAME" ]]; then
    log 0 "Database name (-db) is required."
    exit 1
fi

if [[ $TRSI -eq 0 && -z "$SCHEMANAME_IN" ]]; then
    log 0 "Schema name (-s) is required."
    exit 1
fi

if [[ $TB_STATS -eq 1 && -n "$INDEX_IN" ]]; then
    log 0 "Cannot define -ti with -tb_stats."
    exit 1
fi

if [[ $IX_STATS -eq 2 && -n "$TABLE_IN" ]]; then
    log 0 "Cannot define -t with -ix_stats."
    exit 1
fi

if [[ $IF_STATS -eq 3 && -n "$INDEX_IN" ]]; then
    log 0 "Cannot define -ti with -if_stats."
    exit 1
fi

if [[ $TRANSACTION_LOG_THRESHOLD_PCT -ge 100 ]]; then
    log 0 "Option -log must be less than 100% (currently: $TRANSACTION_LOG_THRESHOLD_PCT)."
    exit 1
fi

if [[ $IGNORE_TABLE_SIZE_THRESHOLD_MIN -ge $IGNORE_TABLE_SIZE_THRESHOLD_MAX ]]; then
    log 0 "Option -ittx ($IGNORE_TABLE_SIZE_THRESHOLD_MAX MB) must be greater than -ittn ($IGNORE_TABLE_SIZE_THRESHOLD_MIN MB)."
    exit 1
fi

# Format REORG filter string for regex
REORG_REGEX=$(echo "$REORG" | sed 's/*/\\*/g; s/-/\\-/g')

# Calculate maintenance time windows
MAINTENANCE_TIMEOUT_WINDOW_SECONDS=$(( 60 * MAINTENANCE_TIMEOUT_WINDOW_MINUTES ))
REORG_TIMEOUT_WINDOW_SECONDS=$(( MAINTENANCE_TIMEOUT_WINDOW_SECONDS * 3 / 4 ))
RUNSTATS_TIMEOUT_WINDOW_SECONDS=$(( MAINTENANCE_TIMEOUT_WINDOW_SECONDS * 1 / 4 ))
REORG_TIMEOUT_OVERFLOW_VALVE=300

# ------------------------------------------------------------------------------
# Main Process
# ------------------------------------------------------------------------------
log 3 "Starting ${SCRIPT_NAME} at $(date) on ${HOSTNAME_VAL}"

# Check HADR Role
ROLE=$(db2 -x "get db cfg for $DBNAME" 2>/dev/null | grep 'HADR database role' | cut -d '=' -f2 | tr -d ' ' || true)
if [[ -n "$ROLE" && "$ROLE" == "STANDBY" ]]; then
    log 0 "Database $DBNAME has HADR role '$ROLE'. Cannot execute reorganizations on a STANDBY node."
    exit 1
fi

log 3 "Target Database :: $DBNAME"
db2 connect to "$DBNAME" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    log 0 "Failed to connect to database $DBNAME"
    exit 1
fi

# Handle TRSI snapshot request
if [[ $TRSI -eq 1 ]]; then
    TRSI
    exit 0
fi

# Handle List Options
if [[ $LIST_VALID_TABLE_SIZES -eq 1 ]]; then
    getValidTableSizes "$SCHEMANAME_IN" ""
    log 3 "Found $NUM_VALID_TABLES valid tables in range [${IGNORE_TABLE_SIZE_THRESHOLD_MIN} MB - ${IGNORE_TABLE_SIZE_THRESHOLD_MAX} MB]:\n$VALID_TABLE_SIZES_RAW_DATA"
    exit 0
fi

if [[ $LIST_FRAGMENTED_INDEXES -eq 1 ]]; then
    getValidFragmentedIndexes
    header="TABSCHEMA TABNAME INDSCHEMA INDNAME INDCARD STATS_TIME LAST_USED NLEAF SEQUENTIAL_PAGES"
    log 3 "Found $NUM_VALID_FRAGMENTED_INDEXES fragmented index entries:\n$header\n$VALID_FRAGMENTED_INDEXES_RAW_DATA"
    exit 0
fi

if [[ $LIST_REORGCHK_TB_STATS_TABLES -eq 1 ]]; then
    getValidTablesToReorg
    header="TABLE_SCHEMA TABLE_NAME CARD OVERFLOW NPAGES FPAGES ACTIVE_BLOCKS TSIZE F1 F2 F3 REORG"
    log 3 "Found $NUM_VALID_TABLES_TO_REORG tables needing reorg via REORGCHK_TB_STATS:\n$header\n$VALID_TABLES_TO_REORG_RAW_DATA"
    exit 0
fi

if [[ $LIST_REORGCHK_IX_STATS_TABLES -eq 1 ]]; then
    getValidIndexesToReorg
    header="TABLE_SCHEMA TABLE_NAME INDEX_SCHEMA INDEX_NAME INDCARD NLEAF NUM_EMPTY_LEAFS NLEVELS NUMRIDS_DELETED FULLKEYCARD LEAF_RECSIZE NONLEAF_RECSIZE LEAF_PAGE_OVERHEAD NONLEAF_PAGE_OVERHEAD PCT_PAGES_SAVED F4 F5 F6 F7 F8 REORG"
    log 3 "Found $NUM_VALID_INDEXES_TO_REORG indexes needing reorg via REORGCHK_IX_STATS:\n$header\n$VALID_INDEXES_TO_REORG_RAW_DATA"
    exit 0
fi

log 3 "Target Schema   :: $SCHEMANAME_IN"
[[ -n "$TABLE_IN" ]] && log 3 "Target Tables   :: $TABLE_IN"
[[ -n "$INDEX_IN" ]] && log 3 "Target Indexes  :: $INDEX_IN"
log 3 "Validating tables/indexes needed for reorgs . . . "

# ------------------------------------------------------------------------------
# Build Object Queue
# ------------------------------------------------------------------------------

if [[ -n "$TABLE_IN" ]]; then
    for tbl in $TABLE_IN; do
        chk=$(db2 -x "select tabname from syscat.tables where tabname = '$tbl' and tabschema = '$SCHEMANAME_IN' and type = 'T'" 2>/dev/null | grep -v '^[[:space:]]*$' || true)
        if [[ -z "$chk" ]]; then
            log 0 "Specified table '$tbl' does not exist in schema '$SCHEMANAME_IN'."
            exit 1
        fi
        if ! isTableWithinSizeLimit "$SCHEMANAME_IN" "$tbl"; then
            log 0 "Table '$tbl' is outside size boundaries (${IGNORE_TABLE_SIZE_THRESHOLD_MIN} MB - ${IGNORE_TABLE_SIZE_THRESHOLD_MAX} MB)."
            exit 1
        fi
    done

    if [[ $IF_STATS -eq 3 ]]; then
        createTableOBJECT_ARRAY "$TABLE_IN" "$IF_STATS"
    else
        # Default to online inplace reorg (TB_STATS=1) when -t is given without a reorg-type flag
        [[ $TB_STATS -ne 1 ]] && TB_STATS=1
        createTableOBJECT_ARRAY "$TABLE_IN" "$TB_STATS"
    fi

elif [[ ${#REORGCHK_TB_IF_STATS_OPTION} -eq 2 ]]; then
    for ((idx=0; idx<2; idx++)); do
        opt_char="${REORGCHK_TB_IF_STATS_OPTION:idx:1}"
        if [[ "$opt_char" == "1" ]]; then
            getValidTablesToReorg
            createTableOBJECT_ARRAY "$VALID_TABLES_TO_REORG" "$TB_STATS"
        elif [[ "$opt_char" == "3" ]]; then
            getValidFragmentedIndexes
            createTableOBJECT_ARRAY "$VALID_FRAGMENTED_INDEXES" "$IF_STATS"
        fi
    done

elif [[ $TB_STATS -eq 1 ]]; then
    getValidTablesToReorg
    createTableOBJECT_ARRAY "$VALID_TABLES_TO_REORG" "$TB_STATS"

elif [[ $IF_STATS -eq 3 ]]; then
    getValidFragmentedIndexes
    createTableOBJECT_ARRAY "$VALID_FRAGMENTED_INDEXES" "$IF_STATS"
fi

if [[ -n "$INDEX_IN" ]]; then
    for ind in $INDEX_IN; do
        tschema=$(echo "$ind" | cut -d. -f1)
        tname=$(echo "$ind" | cut -d. -f2)
        ischema=$(echo "$ind" | cut -d. -f3)
        iname=$(echo "$ind" | cut -d. -f4)

        chk=$(db2 -x "select indname from syscat.indexes where tabschema = '$tschema' and tabname = '$tname' and indschema = '$ischema' and indname = '$iname'" 2>/dev/null | grep -v '^[[:space:]]*$' || true)
        if [[ -z "$chk" ]]; then
            log 0 "Specified index '$ind' does not exist."
            exit 1
        fi
        if ! isTableWithinSizeLimit "$tschema" "$tname"; then
            log 0 "Base table for index '$ind' is outside size boundaries."
            exit 1
        fi
    done
    createIndexOBJECT_ARRAY "$INDEX_IN" "$IX_STATS"

elif [[ $IX_STATS -eq 2 ]]; then
    getValidIndexesToReorg
    createIndexOBJECT_ARRAY "$VALID_INDEXES_TO_REORG" "$IX_STATS"
fi

# Count objects by category
getNUM_OBJECT_REORG_TABLE_TYPE_OBJECT_ARRAY "$TB_STATS"; OBJECT_NUM_TB_STATS=$?
getNUM_OBJECT_REORG_TABLE_TYPE_OBJECT_ARRAY "$IX_STATS"; OBJECT_NUM_IX_STATS=$?
getNUM_OBJECT_REORG_TABLE_TYPE_OBJECT_ARRAY "$IF_STATS"; OBJECT_NUM_IF_STATS=$?

if [[ $LIST_ONLY -eq 1 ]]; then
    listOBJECT_ARRAY
    exit 0
fi

# ------------------------------------------------------------------------------
# Execution Stage
# ------------------------------------------------------------------------------
if [[ $EXECUTE_TABLE_REORG -eq 1 ]]; then
    listOBJECT_ARRAY

    REORG_TIMEOUT_WINDOW_START_TIME_SECONDS=$(date '+%s')
    WINDOW_START_TIME_DB2=$(date '+%Y-%m-%d-%H.%M.%S')
    IF_STATS_WINDOW_START_TIME_DB2=$(date '+%s')
    initTABLE_IN_USE_ARRAY "$MAX_ASYNC_REORGS_ALLOWED"

    MAX_ASYNC_REORGS_ALLOWED_ORIG="$MAX_ASYNC_REORGS_ALLOWED"
    REORG_TIMEOUT_WINDOW_ACTION_ORIG="$REORG_TIMEOUT_WINDOW_ACTION"
    SLEEP_INTERVAL_TIME_ORIG="$SLEEP_INTERVAL_TIME"

    log 3 "Starting reorganizations..."
    #set -x

    if [[ ${#REORGCHK_TB_IF_STATS_OPTION} -eq 2 ]]; then
        for ((idx=0; idx<2; idx++)); do
            opt_char="${REORGCHK_TB_IF_STATS_OPTION:idx:1}"
            if [[ "$opt_char" == "1" ]]; then
                TB_STATS=1
                IF_STATS=0
                NUM_REORG_OBJECTS="$OBJECT_NUM_TB_STATS"
                REORG_TABLE_TYPE="$TB_STATS"
                MAX_ASYNC_REORGS_ALLOWED="$MAX_ASYNC_REORGS_ALLOWED_ORIG"
                REORG_TIMEOUT_WINDOW_ACTION="$REORG_TIMEOUT_WINDOW_ACTION_ORIG"
                SLEEP_INTERVAL_TIME="$SLEEP_INTERVAL_TIME_ORIG"
            elif [[ "$opt_char" == "3" ]]; then
                TB_STATS=0
                IF_STATS=3
                NUM_REORG_OBJECTS="$OBJECT_NUM_IF_STATS"
                REORG_TABLE_TYPE="$IF_STATS"
                MAX_ASYNC_REORGS_ALLOWED=1
                REORG_TIMEOUT_WINDOW_ACTION=1
                SLEEP_INTERVAL_TIME=$(( SLEEP_INTERVAL_TIME_ORIG / 3 ))
                [[ $SLEEP_INTERVAL_TIME -lt 5 ]] && SLEEP_INTERVAL_TIME=5
            fi
            reorgTables
        done
    else
        if [[ $TB_STATS -eq 1 ]]; then
            REORG_TABLE_TYPE="$TB_STATS"
            NUM_REORG_OBJECTS="$OBJECT_NUM_TB_STATS"
        elif [[ $IX_STATS -eq 2 ]]; then
            REORG_TABLE_TYPE="$IX_STATS"
            NUM_REORG_OBJECTS="$OBJECT_NUM_IX_STATS"
        elif [[ $IF_STATS -eq 3 ]]; then
            REORG_TABLE_TYPE="$IF_STATS"
            NUM_REORG_OBJECTS="$OBJECT_NUM_IF_STATS"
        fi
        reorgTables
    fi

    listOBJECT_ARRAY

    # --------------------------------------------------------------------------
    # Post-Reorg RUNSTATS Stage
    # --------------------------------------------------------------------------
    log 3 "Starting post-reorganization RUNSTATS..."
    for entry in "${OBJECT_ARRAY[@]}"; do
        now_sec=$(date '+%s')
        diff_sec=$(( now_sec - REORG_TIMEOUT_WINDOW_START_TIME_SECONDS ))
        if [[ $diff_sec -ge $(( REORG_TIMEOUT_WINDOW_SECONDS + RUNSTATS_TIMEOUT_WINDOW_SECONDS )) ]]; then
            log 3 "Maintenance window expired. Halting RUNSTATS."
            break
        fi

        IFS="#" read -r t_schema t_name i_schema i_name iid r_status r_start r_end tbl_id tbsp_id l_count o_type <<< "$entry"

        if [[ "$r_status" == "COMPLETED" ]]; then
            stats_chk=$(db2 -x "select stats_time from syscat.tables where tabschema='$t_schema' and tabname='$t_name' and stats_time < TIMESTAMP('$WINDOW_START_TIME_DB2')" 2>/dev/null | grep -v '^[[:space:]]*$' || true)
            if [[ -n "$stats_chk" ]]; then
                log 3 "Executing RUNSTATS on ${t_schema}.${t_name}..."
                db2 -v "runstats on table ${t_schema}.${t_name} ON ALL COLUMNS WITH DISTRIBUTION ON ALL COLUMNS AND DETAILED INDEXES ALL ALLOW WRITE ACCESS" >/dev/null 2>&1
                log 3 "Completed RUNSTATS on ${t_schema}.${t_name}"
            fi
        fi
    done
fi

log 3 "Completed ${SCRIPT_NAME} at $(date)"
exit 0


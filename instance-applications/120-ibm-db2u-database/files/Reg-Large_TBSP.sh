#!/bin/bash
set -x
db2set db2comm=

db2stop force ; ipclean ; db2start
sleep 60
db2 connect to bludb
db2 alter tablespace MAXDATA convert to large
db2 alter tablespace MAXINDEX convert to large


db2 "select 'REORG TABLE '|| RTRIM(TABSCHEMA) || '.\"' || RTRIM(tabname)||'\" ;' from syscat.tables where tabschema = 'MAXIMO' and type ='T'" | grep REORG > ALL_TB_REORG.sql
db2 "select 'REORG INDEXES ALL FOR TABLE '|| RTRIM(TABSCHEMA) || '.\"' || RTRIM(tabname)||'\" ;' from syscat.tables where tabschema = 'MAXIMO' and type ='T'" | grep REORG > ALL_IX_REORG.sql
db2 "select 'RUNSTATS ON TABLE '|| RTRIM(TABSCHEMA) || '.\"' || RTRIM(tabname)||'\" ON ALL COLUMNS WITH DISTRIBUTION ON ALL COLUMNS AND DETAILED INDEXES ALL;' from syscat.tables where tabschema = 'MAXIMO' and type ='T'" | grep RUNSTATS > ALL_TB_RUNSTATS.sql

db2 -tvf ALL_TB_REORG.sql | tee  | tee ALL_TB_REORG.OUT
db2 -tvf ALL_IX_REORG.sql  | tee ALL_IX_REORG.OUT
db2 -tvf ALL_TB_RUNSTATS.sql | tee ALL_TB_RUNSTATS.OUT

db2 alter tablespace MAXDATA  reduce max
db2 alter tablespace MAXINDEX reduce max

db2set db2comm=TCPIP,SSL
db2stop force ; ipclean ; db2start

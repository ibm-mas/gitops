-- #DBNAME=`db2 list db directory | grep alias | awk '{ print $4 }' | paste -s -d ' '`
-- DBNAME=BLUDB;
connect to BLUDB;
call SYSPROC.SYSINSTALLOBJECTS('EXPLAIN', 'D', CAST (NULL AS VARCHAR(128)),'SYSTOOLS' );
call SYSPROC.SYSINSTALLOBJECTS('EXPLAIN', 'C', CAST (NULL AS VARCHAR(128)),'SYSTOOLS' );
create role EXPLAIN;
grant all on SYSTOOLS.EXPLAIN_ARGUMENT to role EXPLAIN;
grant all on SYSTOOLS.EXPLAIN_DIAGNOSTIC to role EXPLAIN;
grant all on SYSTOOLS.EXPLAIN_DIAGNOSTIC_DATA to role EXPLAIN;
grant all on SYSTOOLS.EXPLAIN_INSTANCE to role EXPLAIN;
grant all on SYSTOOLS.EXPLAIN_OBJECT to role EXPLAIN;
grant all on SYSTOOLS.EXPLAIN_OPERATOR to role EXPLAIN;
grant all on SYSTOOLS.EXPLAIN_PREDICATE to role EXPLAIN;
grant all on SYSTOOLS.EXPLAIN_STATEMENT to role EXPLAIN;
grant all on SYSTOOLS.EXPLAIN_STREAM to role EXPLAIN;
connect reset;
terminate;

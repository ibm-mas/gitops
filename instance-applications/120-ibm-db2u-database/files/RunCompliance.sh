#!/bin/sh
# set -x
######################################################################
#
# 
# 
#
# 
#
######################################################################




EMAILPEOPLE="glance@ca.ibm.com"

RUNDIR=${HOME}/bin/ITCS104
FILES2SEND="info out txt"

 ${RUNDIR}/db2shc >>.Compliance.OUT


VIOLATIONS=`grep VIOL NOTSET*.out | cut -d"|" -f4,5 | sed 's/|//' | grep "TOTAL VIOLATIONS" | sed 's/           /=/' | cut -d= -f2`
FROM=`ls -1 | grep cout | head -1 | cut -d"-" -f3 |  cut -d. -f1`

EMAILLIST=`echo $VIOLATIONS | tr ' ' '\012' | grep -v TOTAL`
for x in `ls -1 | grep "\.out"` ; 
  do  
  ERRORCOUNT=`grep VIOL $x | grep TOTAL | cut -d"|" -f4,5 | sed 's/|//' `
  FILENAME=$x  
  done
		for x in `ls -1 | grep "\.out"` ;
  			do
  			ERRORCOUNT=`grep VIOL $x | grep TOTAL | cut -d"|" -f4,5 | sed 's/|//' `
  			FILENAME=$x 							      
			echo ${ERRORCOUNT}	> ${RUNDIR}/ITCS104.rpt
  		done



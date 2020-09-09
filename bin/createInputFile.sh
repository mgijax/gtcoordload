#!/bin/sh 
#
#  createInputFile.sh
###########################################################################
#
#  Purpose:  This script controls execution of createInputFile.sh
#
   Usage="createInputFile.sh"
#
#  Env Vars:
#
#      See the configuration file
#
#  Inputs:
#
#      - Common configuration file  - 
#		/usr/local/mgi/live/mgiconfig/master.config.sh
#      - Gene Trap Coordinate load configuration file
#      - gff format file used to create gtcoordload input file
#
#  Outputs:
#
#      - An archive file
#      - Log files defined by the environment variables ${LOG_PROC},
#        ${LOG_DIAG}, ${LOG_CUR} and ${LOG_VAL}
#      - file in coordload file format
#      - Exceptions written to standard error
#      - Configuration and initialization errors are written to a log file
#        for the shell script
#
#  Exit Codes:
#
#      0:  Successful completion
#      1:  Fatal error occurred
#      2:  Non-fatal error occurred
#
#  Assumes:  Nothing
#
#  Implementation:  
#
#  Notes:  None
#
###########################################################################
cd `dirname $0`/..
#
#  Establish the load configuration file name.
#
CONFIG_LOAD=`pwd`/gtcoordload.config

#
#  Make sure the configuration file is readable.
#
if [ ! -r ${CONFIG_LOAD} ]
then
    echo "Cannot read configuration file: ${CONFIG_LOAD}" 
    exit 1
fi

#
# Source the load configuration file
#
. ${CONFIG_LOAD}
#
#  Make sure the master configuration file is readable
#

if [ ! -r ${CONFIG_MASTER} ]
then
    echo "Cannot read configuration file: ${CONFIG_MASTER}"
    exit 1
fi

#
#  Source the DLA library functions.
#
if [ "${DLAJOBSTREAMFUNC}" != "" ]
then
    if [ -r ${DLAJOBSTREAMFUNC} ]
    then
        . ${DLAJOBSTREAMFUNC}
    else
        echo "Cannot source DLA functions script: ${DLAJOBSTREAMFUNC}"
        exit 1
    fi
else
    echo "Environment variable DLAJOBSTREAMFUNC has not been defined."
fi

${GTCOORDLOAD}/bin/createInputFile.py 

STAT=$?
checkStatus ${STAT} "${GTCOORDLOAD}/bin/createInputFile.py"
    
exit 0

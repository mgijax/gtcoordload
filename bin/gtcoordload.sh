#!/bin/sh
#
#  gtcoordload.sh
###########################################################################
#
#  Purpose:  This script controls the execution of the Gene Trap 
#            Coordinate Load
#
Usage="Usage: $0"
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
#      - gtcoordload input file 
#
#  Outputs:
#
#      - An archive file
#      - Log files defined by the environment variables ${LOG_PROC},
#        ${LOG_DIAG}, ${LOG_CUR} and ${LOG_VAL}
#      - gtcoordload input file (created its own from a gff file, see inputs)
#      - BCP files for for inserts to each database table to be loaded
#      - Records written to the database tables
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

#
#  Set up a log file for the shell script in case there is an error
#  during configuration and initialization.
#
cd `dirname $0`/..
LOG=`pwd`/gtcoordload.log
rm -f ${LOG}

#
#  Verify the argument(s) to the shell script.
#
if [ $# -ne 0 ]
then
    echo ${Usage} | tee -a ${LOG}
    exit 1
else
    CONFIG_LOAD=`pwd`/gtcoordload.config
fi

#
#  Make sure the configuration file is readable.
#
if [ ! -r ${CONFIG_LOAD} ]
then
    echo "Cannot read configuration file: ${CONFIG_LOAD}" | tee -a ${LOG}
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

#
# check that INFILE_NAME has been set
#
if [ "${INFILE_NAME}" = "" ]
then
    # set STAT for endJobStream.py 
    STAT=1
    checkStatus ${STAT} "INFILE_NAME not defined"
fi

#
# we normally check if INFILE_NAME is readable here, but we can't because we 
# need to create it first - we'll check it later
#

#
# Function that creates coordinate load input file
#
createInputFile ()
{
    echo "Creating coordload format input file from GFF file" | \
	tee -a ${LOG_DIAG} ${LOG_PROC}

    # log time and input files to process
    echo "" >> ${LOG_DIAG} 
    echo "`date`" >> ${LOG_DIAG} 

    ${APP_CAT_METHOD} ${WORK_GFF_FILE} | ${GTCOORDLOAD}/bin/createInputFile.sh >> ${LOG_DIAG} ${LOG_PROC} 2>&1

    STAT=$?
    checkStatus ${STAT} "${GTCOORDLOAD}/bin/createInputFile.py"
    
}

#
# Function that checks the readability of the input file
#
checkInputFile ()
{
    if [ ! -r ${INFILE_NAME} ]
    then
	# set STAT for endJobStream.py
	STAT=1
	checkStatus ${STAT} "Cannot read from input file: ${INFILE_NAME}"
    fi
}
#
# Function that runs to java load
#

run ()
{
    echo "Running gtcoordload" | tee -a ${LOG_DIAG} ${LOG_PROC}

    # log time and input files to process
    echo "" >> ${LOG_DIAG} ${LOG_PROC}
    echo "`date`" >> ${LOG_DIAG} ${LOG_PROC}

    echo "Processing input file ${INFILE_NAME}" >> ${LOG_DIAG}
    ${JAVA} ${JAVARUNTIMEOPTS} -classpath ${CLASSPATH} \
	-DCONFIG=${CONFIG_MASTER},${CONFIG_LOAD} \
	-DJOBKEY=${JOBKEY} ${DLA_START}

    STAT=$?
    checkStatus ${STAT} "${GTCOORDLOAD} java load"
}

##################################################################
# main
##################################################################

#
# createArchive including OUTPUTDIR, startLog, getConfigEnv, get job key
#
preload ${OUTPUTDIR}

#
# rm all files/dirs from OUTPUTDIR 
#
cleanDir ${OUTPUTDIR} 

#
# select the GFF files that are ready to be processed
#
if [ ${APP_RADAR_INPUT} = true ]
then
     echo "Getting GFF format input files" | tee -a ${LOG_PROC} ${LOG_DIAG}
     APP_INFILES=`${RADAR_DBUTILS}/bin/getFilesToProcess.csh \
        ${RADAR_DBSCHEMADIR} ${JOBSTREAM} ${FILETYPE} 0`
     STAT=$?
     checkStatus ${STAT} "getFilesToProcess.csh"
fi

echo "GFF input files: ${APP_INFILES}" | tee -a ${LOG_PROC} ${LOG_DIAG}
#
#  Make sure there is at least one GFF file to process
#
if [ "${APP_INFILES}" = "" ]
then
    echo "There are no GFF input files to process" | \
        tee -a ${LOG_PROC} ${LOG_DIAG}
    shutDown
    exit 0
fi

#
# Create one file from the set of input files
#
${APP_CAT_METHOD} ${APP_INFILES} > ${WORK_GFF_FILE}
STAT=$?
checkStatus ${STAT} "Create single GFF input file"

#
# create gene trap coordinate load input file
#
createInputFile

#
# make sure coordload input file is readable
#
checkInputFile

#
# Run the gene trap coordinate load
#
run

#
# log the processed files
#
if [ ${APP_RADAR_INPUT} = true ]
then
    echo "Logging processed files"
    for file in ${APP_INFILES}
    do
        echo ${file} ${FILETYPE}
        ${RADAR_DBUTILS}/bin/logProcessedFile.csh ${RADAR_DBSCHEMADIR} \
            ${JOBKEY} ${file} ${FILETYPE}
        STAT=$?
        checkStatus ${STAT} "logProcessedFile.csh ${file}"
    done
fi

#
# run postload cleanup and email logs
#
shutDown

exit 0

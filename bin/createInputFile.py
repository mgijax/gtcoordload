
#
# Program: createInputFile.py
#
# Original Author: sc
#
# Purpose:
#
# This script reads GFF format records from stdin and writes them to a file
#  in coordinate load format
#
# Usage: cat inputFile(s) | createInputFile.py 
#
# Envvars:
#	See configuration file
#
# Inputs:
# stdin - GFF format records are read from stdin
#
# Outputs:
#
# 	file in coordload format
#
# Exit Codes:
#
# Assumes:
#
# Bugs:
#
# Implementation:
#
#    Modules:
#
# Modification History:
#
# 01/02/2008 - sc created
#	- TR7493
#

import sys
import os
import re
import db
import string
import mgi_utils
import loadlib

TAB = '\t'
CRT = '\n'
SPC =  ' '
outFileName = os.environ['OUTFILE_NAME_CREATE']
outFile = ''

# List of TIGEM and EUCOMM (upstream) sequence tags which are not
# reverse complemented. Used in order to toggle the  blat strand in order
# to store the trapped strand
seqsToToggleList = []

# set up connection to the snp database
server = os.environ['MGD_DBSERVER']
database = os.environ['MGD_DBNAME']
user = os.environ['MGD_DBUSER']
password = str.strip(open(os.environ['MGD_DBPASSWORDFILE'], 'r').readline())

def loadLookup():
    global seqsToToggleList
    
    db.set_sqlLogin(user, password, server, database)
    db.useOneConnection(1)
    cmds = []

    # get eucomm mutant cell lines (MCLs)
    cmds.append('''select c._CellLine_key
        into temporary table eucommCL
        from  ALL_CellLine c, ALL_CellLine_Derivation d
        where d._Creator_key = 4856374
        and d._Derivation_key = c._Derivation_key''')

    cmds.append('create index idx_1 on eucommCL(_CellLine_key)') 

    # get sequences associated with  eucomm MCLs (via the allele)
    cmds.append('''select t._CellLine_key, saa._Sequence_key
    into temporary table eucommSeq
    from eucommCL t, ALL_Allele_CellLine aac, SEQ_Allele_Assoc saa
    where t._CellLine_key = aac._MutantCellLine_key
    and aac._Allele_key = saa._Allele_key''')

    cmds.append('create index idx_1 on eucommSeq(_Sequence_key)')

    # filter for just the upstream vector end and get the seqID
    cmds.append('''select t.*, a.accID
    into temporary table eucommUpstSeq
    from eucommSeq t, SEQ_GeneTrap sgt, ACC_Accession a
    where t._Sequence_key = sgt._Sequence_key
    and sgt._VectorEnd_key = 3983010
    and sgt._Sequence_key = a._Object_key
    and a._MGIType_key = 19
    and a._LogicalDB_key = 9
    and a.preferred = 1''')

    # get tigem MCLs 
    cmds.append('''select c._CellLine_key
    into temporary table tigemCL
    from  ALL_CellLine c, ALL_CellLine_Derivation d
    where d._Creator_key = 3982963
    and d._Derivation_key = c._Derivation_key''')

    cmds.append('create index idx_1 on tigemCL(_CellLine_key)')

    # get sequences associated with tigem MCLs (via allele)
    cmds.append('''select t._CellLine_key, saa._Sequence_key
    into temporary table tigemSeq
    from tigemCL t, ALL_Allele_CellLine aac, SEQ_Allele_Assoc saa
    where t._CellLine_key = aac._MutantCellLine_key
    and aac._Allele_key = saa._Allele_key''')

    cmds.append('create index idx_1 on tigemSeq(_Sequence_key)')
    
    # get the seqID
    cmds.append('''select t.*, a.accID
    into temporary table tigemAccid
    from tigemSeq t, ACC_Accession a
    where t._Sequence_key  = a._Object_key
    and a._MGIType_key = 19
    and a._LogicalDB_key = 9
    and a.preferred = 1''')

    # union the eucomm and tigem sets
    cmds.append('''select t.accID
    into temporary table all
    from eucommUpstSeq t
    union
    select te.accID
    from tigemAccid te''')

    # load the lookup list
    cmds.append('select distinct * from all')
    results = db.sql(cmds, 'auto')
    for r in results[11]:
        seqID = r['accID']
        seqsToToggleList.append(seqID)

def init():
        #
        # requires: 
        #
        # effects: 
        # 1. Initializes global file descriptors/file names
        #
        # returns:
        #
 
    global outFile, outFileName
 
    try:
        outFile = open(outFileName, 'w')
    except:
        exit(1, 'Could not open file %s\n' % outFileName)
    loadLookup()

def run():
    line = sys.stdin.readline()
    while line != "":
        tokenList =  str.splitfields(line, TAB)
        if tokenList[0].find('scaf') != -1:
            line = sys.stdin.readline()
            continue
        if tokenList[2] != 'gene':
            line = sys.stdin.readline()
            continue
        chr = str.strip(tokenList[0])
        # strip off the leading 'chr'
        chr = chr[3:]
        start = str.strip(tokenList[3])
        end = str.strip(tokenList[4])
        strand = str.strip(tokenList[6])
        # strip of leading "Gene "
        id = str.strip(tokenList[8][4:])
        if id in seqsToToggleList:
            if strand == '+':
                strand = '-'
            else:
                strand = '+'
        outFile.write("%s%s%s%s%s%s%s%s%s%s" % \
            (id, TAB, chr, TAB, start, TAB, end, TAB, strand, CRT))
        line = sys.stdin.readline()


#
# main Routine
#

init()

run()

outFile.close()
db.useOneConnection(0)

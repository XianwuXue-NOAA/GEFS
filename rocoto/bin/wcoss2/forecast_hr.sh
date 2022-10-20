#!/bin/ksh -l

set -x
ulimit -s unlimited
ulimit -a

# module_ver.h
#. $SOURCEDIR/versions/run.ver

# Load modules
source "$HOMEgfs/ush/preamble.sh"

###############################################################
# Source FV3GFS workflow modules
. $HOMEgfs/ush/load_fv3gfs_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status
module list
###############################################################
# Execute the JJOB
$HOMEgfs/jobs/JGLOBAL_FORECAST
status=$?

exit $status

# For Development
#. $GEFS_ROCOTO/bin/wcoss2/common.sh



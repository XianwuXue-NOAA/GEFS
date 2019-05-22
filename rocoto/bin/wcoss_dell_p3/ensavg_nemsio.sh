#!/bin/ksh
#

# EXPORT list here
set -x
export NODES=7

ulimit -s unlimited
ulimit -a

export KMP_AFFINITY=disabled

export total_tasks=6
export OMP_NUM_THREADS=7
export taskspernode=4

# export for development runs only begin
export envir=${envir:-dev}
export RUN_ENVIR=${RUN_ENVIR:-dev}

export gefsmpexec_mpmd="  mpirun -n $total_tasks cfp mpmd_cmdfile"
export gefsmpexec=mpirun 

# CALL executable job script here
$SOURCEDIR/jobs/JGEFS_ENSAVG_NEMSIO

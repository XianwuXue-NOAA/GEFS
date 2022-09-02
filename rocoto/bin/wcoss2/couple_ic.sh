#!/bin/ksh -l

set -x
ulimit -s unlimited
ulimit -a

# module_ver.h
. $SOURCEDIR/versions/run.ver

# Load modules
module purge
module load envvar/$envvar_ver
module load intel/$intel_ver
#module load ips/$ips_ver
#module load impi/$impi_ver
#module load prod_util/$prod_util_ver
#module load prod_envir/$prod_envir_ver
module load prod_util/$prod_util_ver
module load prod_envir/$prod_envir_ver

#module load lsf/$lsf_ver
module load python/$python_ver

module list

# For Development
. $GEFS_ROCOTO/bin/wcoss2/common.sh

# Export List
#export NTHREADS_SIGCHGRS=${GEFS_TPP:-6}
export OMP_NUM_THREADS=1
export envir=prod

#
if [[ "$machine" == "HERA" ]]; then
    export BASE_CPLIC="/scratch1/NCEPDEV/climate/role.ufscpara/IC"
elif [[ "$machine" == "ORION" ]]; then
    export BASE_CPLIC="/work/noaa/global/wkolczyn/noscrub/global-workflow/IC"
elif [[ "$machine" == "WCOSS2" ]]; then
    export BASE_CPLIC="/lfs/h2/emc/ens/noscrub/xianwu.xue/GEFS_v13/IC_from_Hera"
fi

export CPL_ATMIC=GEFS-NoahMP-aerosols-p8c
export CPL_ICEIC=CPC
export CPL_OCNIC=CPC3Dvar
export CPL_WAVIC=GEFSwave20210528v2
export CPL_DATM=CDEPS_DATM


# -job
ver=${ver:-$(echo ${gefs_ver}|cut -c1-5)}
export COMPONENT="atmos"
export COMOUT=${COMOUT:-$(compath.py -o $NET/${ver})/${RUN}.${PDY}/$cyc/$COMPONENT}

# CALL executable job script here
#$GEFS_ROCOTO/bin/py/keep_data_atm.py
echo "Done -- xxw"

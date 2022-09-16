#!/bin/ksh
#

# EXPORT list here
set -x
ulimit -s unlimited
ulimit -a

# module_ver.h
. $GEFS_ROCOTO/dev/versions/run_hera.ver

# Load modules
. /apps/lmod/lmod/init/ksh
module list
module purge

module use -a /scratch2/NCEPDEV/nwprod/hpc-stack/libs/hpc-stack/modulefiles/stack
module load hpc/$hpc_ver

module load hpc-intel/$intel_ver
module load grib_util/$grib_util_ver
module load prod_util/$prod_util_ver

module load netcdf/$netcdf_ver
module load wgrib2/$wgrib2_ver

module list

# For Development
. $GEFS_ROCOTO/bin/hera/common.sh

#export OMP_NUM_THREADS=6

# export for development runs only begin
ver=${ver:-$(echo ${gefs_ver}|cut -c1-5)}
export COMOUT=${COMOUT:-${COMROOT}/gefs/$ver/${RUN}.${PDY}/$cyc/atmos}

# CALL executable job script here
$SOURCEDIR/jobs/JGEFS_ATMOS_GETCFSSST


#! /usr/bin/env bash

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
export CASE=${CASE:-"C384"}

export RUNMEM=${RUNMEM:-"gec00"}
export mem=$(echo $RUNMEM|cut -c3-5)

export CDATE=${CDATE:-${PDY}${cyc}}
export DO_WAVE="YES"
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

# wave
#
#export waveGRD=${waveGRD:-'gnh_10m aoc_9km gsh_15m'}
# for s2sw
export waveGRD='gwes_30m'

case "$CASE" in
    "C48") export OCNRES=400;;
    "C96") export OCNRES=100;;
    "C192") export OCNRES=050;;
    "C384") export OCNRES=025;;
    "C768") export OCNRES=025;;
    *) export OCNRES=025;;
esac
export ICERES=$OCNRES

# -job
ver=${ver:-$(echo ${gefs_ver}|cut -c1-5)}
#export COMPONENT="atmos"
export COMOUT=${COMOUT:-$(compath.py -o $NET/${ver})/${RUN}.${PDY}/$cyc/${mem}}
ICSDIR=$COMOUT

[[ ! -d $ICSDIR ]] && mkdir -p $ICSDIR
[[ ! -d $ICSDIR/atmos ]] && mkdir -p $ICSDIR/atmos
[[ ! -d $ICSDIR/ocean ]] && mkdir -p $ICSDIR/ocean/INPUT
[[ ! -d $ICSDIR/ice ]] && mkdir -p $ICSDIR/ice/INPUT

if [ $ICERES = '025' ]; then
    ICERESdec="0.25"
fi
if [ $ICERES = '050' ]; then
    ICERESdec="0.50"
fi

# CALL executable job script here
err=0
# Setup ATM initial condition files
cp -r $BASE_CPLIC/$CPL_ATMIC/$CDATE/gfs/$CASE/INPUT $ICSDIR/atmos/
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $BASE_CPLIC/$CPL_ATMIC/$CDATE/$CDUMP/* to $ICSDIR/$CDATE/atmos/ (Error code $rc)"
fi
err=$((err + rc))

# Setup Ocean IC files
cp -r $BASE_CPLIC/$CPL_OCNIC/$CDATE/ocn/$OCNRES/MOM*.nc  $ICSDIR/ocean/INPUT/
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $BASE_CPLIC/$CPL_OCNIC/$CDATE/ocn/$OCNRES/MOM*.nc to $ICSDIR/$CDATE/ocn/ (Error code $rc)"
fi
err=$((err + rc))

#Setup Ice IC files
cp $BASE_CPLIC/$CPL_ICEIC/$CDATE/ice/$ICERES/cice5_model_${ICERESdec}.res_$CDATE.nc $ICSDIR/ice/INPUT/cice_model_${ICERESdec}.res_$CDATE.nc
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $BASE_CPLIC/$CPL_ICEIC/$CDATE/ice/$ICERES/cice5_model_${ICERESdec}.res_$CDATE.nc to $ICSDIR/$CDATE/ice/cice_model_${ICERESdec}.res_$CDATE.nc (Error code $rc)"
fi
err=$((err + rc))

if [ $DO_WAVE = "YES" ]; then
    [[ ! -d $ICSDIR/wave/restart ]] && mkdir -p $ICSDIR/wave/restart/
    for grdID in $waveGRD
    do
        cp $BASE_CPLIC/$CPL_WAVIC/$CDATE/wav/$grdID/*restart.$grdID $ICSDIR/wave/restart/
        rc=$?
        if [[ $rc -ne 0 ]] ; then
            echo "FATAL: Unable to copy $BASE_CPLIC/$CPL_WAVIC/$CDATE/wav/$grdID/*restart.$grdID to $ICSDIR/$CDATE/wav/ (Error code $rc)"
        fi
        err=$((err + rc))
    done
fi

exit $err

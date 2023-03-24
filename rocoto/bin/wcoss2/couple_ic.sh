#! /usr/bin/env bash

###############################################################
## Abstract:
## Copy initial conditions from BASE_CPLIC to COM for coupled modelling
## HOMEgefs   : /full/path/to/workflow
## PDY    : current date (YYYYMMDD)
## cyc    : current cycle (HH)
###############################################################

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
export envir=prod

export RUNMEM=${RUNMEM:-"gec00"}
export mem=$(echo ${RUNMEM}|cut -c3-5)

export CDATE=${CDATE:-${PDY}${cyc}}

configs="gefs"
config_path=${PARMgefs:-${HOMEgefs}/parm}
for config in $configs; do
  . ${config_path}/${config}.parm
  export err=$?
  if [[ ${err} != 0 ]]; then
    echo "FATAL ERROR in ${BASH_SOURCE}: Error while loading parm file ${config_path}/${config}.parm"
    exit ${err}
  fi
done
#
# config.coupled_ic --\/\/
if [[ "${machine}" == "WCOSS2" ]]; then
  #export BASE_CPLIC="/lfs/h2/emc/couple/noscrub/Jiande.Wang/IC"
  export BASE_CPLIC="/lfs/h2/emc/ens/noscrub/xianwu.xue/GEFS_v13/z_ICS_CPL"
elif [[ "${machine}" == "HERA" ]]; then
  export BASE_CPLIC="/scratch1/NCEPDEV/climate/role.ufscpara/IC"
elif [[ "${machine}" == "ORION" ]]; then
  export BASE_CPLIC="/work/noaa/global/glopara/data/ICSDIR/prototype_ICs"
elif [[ "${machine}" == "S4" ]]; then
  export BASE_CPLIC="/data/prod/glopara/coupled_ICs"
fi


case "${CASE}" in
  "C384")
    #C384 and P8 ICs
    export CPL_ATMIC=GEFS-NoahMP-aerosols-p8c
    export CPL_ICEIC=CPC
    export CPL_OCNIC=CPC3Dvar
    export CPL_WAVIC=GEFSwave20210528v2
    ;;
  "C768")
    export CPL_ATMIC=HR1
    export CPL_ICEIC=HR1
    export CPL_OCNIC=HR1
    export CPL_WAVIC=HR1
    ;;
  *)
    echo "Unrecognized case: ${1}"
    exit 1
    ;;
esac
# config.coupled_ic --/\/\

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
export COMOUT=${COMOUT:-$(compath.py -o $NET/${ver})/${RUN}.${PDY}/${cyc}/${mem}}
export ROTDIR=${ROTDIR:-$(compath.py ${envir}/com/$NET/${ver})}

###############################################################
# Locally scoped variables and functions
GDATE=$(date -d "${PDY} ${cyc} - ${assim_freq:-${gefs_cych:-6}} hours" +%Y%m%d%H)
gPDY="${GDATE:0:8}"
gcyc="${GDATE:8:2}"

error_message(){
    echo "FATAL ERROR: Unable to copy ${1} to ${2} (Error code ${3})"
}

###############################################################
# Start staging

# Stage the FV3 initial conditions to ROTDIR (cold start)
ATMdir="${COMOUT}/atmos/INPUT"
[[ ! -d "${ATMdir}" ]] && mkdir -p "${ATMdir}"
source="${BASE_CPLIC}/${CPL_ATMIC}/${PDY}${cyc}/gfs/${CASE}/INPUT/gfs_ctrl.nc"
target="${ATMdir}/gfs_ctrl.nc"
${NCP} "${source}" "${target}"
rc=$?
[[ ${rc} -ne 0 ]] && error_message "${source}" "${target}" "${rc}"
err=$((err + rc))
for ftype in gfs_data sfc_data; do
  for tt in $(seq 1 6); do
    source="${BASE_CPLIC}/${CPL_ATMIC}/${PDY}${cyc}/gfs/${CASE}/INPUT/${ftype}.tile${tt}.nc"
    target="${ATMdir}/${ftype}.tile${tt}.nc"
    ${NCP} "${source}" "${target}"
    rc=$?
    [[ ${rc} -ne 0 ]] && error_message "${source}" "${target}" "${rc}"
    err=$((err + rc))
  done
done

# Stage ocean initial conditions to ROTDIR (warm start)
OCNdir="${ROTDIR}/${RUN}.${gPDY}/${gcyc}/${mem}/ocean/RESTART"
[[ ! -d "${OCNdir}" ]] && mkdir -p "${OCNdir}"
source="${BASE_CPLIC}/${CPL_OCNIC}/${PDY}${cyc}/ocn/${OCNRES}/MOM.res.nc"
target="${OCNdir}/${PDY}.${cyc}0000.MOM.res.nc"
${NCP} "${source}" "${target}"
rc=$?
[[ ${rc} -ne 0 ]] && error_message "${source}" "${target}" "${rc}"
err=$((err + rc))
case $OCNRES in
  "025")
    for nn in $(seq 1 4); do
      source="${BASE_CPLIC}/${CPL_OCNIC}/${PDY}${cyc}/ocn/${OCNRES}/MOM.res_${nn}.nc"
      if [[ -f "${source}" ]]; then
        target="${OCNdir}/${PDY}.${cyc}0000.MOM.res_${nn}.nc"
        ${NCP} "${source}" "${target}"
        rc=$?
        [[ ${rc} -ne 0 ]] && error_message "${source}" "${target}" "${rc}"
        err=$((err + rc))
      fi
    done
  ;;
  *)
    echo "FATAL ERROR: Unsupported ocean resolution ${OCNRES}"
    rc=1
    err=$((err + rc))
  ;;
esac

# Stage ice initial conditions to ROTDIR (cold start as these are SIS2 generated)
ICEdir="${COMOUT}/ice/RESTART"
[[ ! -d "${ICEdir}" ]] && mkdir -p "${ICEdir}"
ICERESdec=$(echo "${ICERES}" | awk '{printf "%0.2f", $1/100}')
source="${BASE_CPLIC}/${CPL_ICEIC}/${PDY}${cyc}/ice/${ICERES}/cice5_model_${ICERESdec}.res_${PDY}${cyc}.nc"
target="${ICEdir}/${PDY}.${cyc}0000.cice_model.res.nc"
${NCP} "${source}" "${target}"
rc=$?
[[ ${rc} -ne 0 ]] && error_message "${source}" "${target}" "${rc}"
err=$((err + rc))

# Stage the WW3 initial conditions to ROTDIR (warm start; TODO: these should be placed in $RUN.$gPDY/$gcyc)
if [[ "${DO_WAVE}" = "YES" ]]; then
  WAVdir="${COMOUT}/wave/restart"
  [[ ! -d "${WAVdir}" ]] && mkdir -p "${WAVdir}"
  for grdID in ${waveGRD}; do  # TODO: check if this is a bash array; if so adjust
    source="${BASE_CPLIC}/${CPL_WAVIC}/${PDY}${cyc}/wav/${grdID}/${PDY}.${cyc}0000.restart.${grdID}"
    target="${WAVdir}/${PDY}.${cyc}0000.restart.${grdID}"
    ${NCP} "${source}" "${target}"
    rc=$?
    [[ ${rc} -ne 0 ]] && error_message "${source}" "${target}" "${rc}"
    err=$((err + rc))
  done
fi

###############################################################
# Check for errors and exit if any of the above failed
if  [[ "${err}" -ne 0 ]] ; then
  echo "FATAL ERROR: Unable to copy ICs from ${BASE_CPLIC} to ${ROTDIR}; ABORT!"
  exit "${err}"
fi

##############################################################
# Exit cleanly
exit 0

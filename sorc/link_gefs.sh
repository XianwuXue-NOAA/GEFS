#!/bin/bash
set -ex

#--make symbolic links for EMC installation and hardcopies for NCO delivery

while getopts e:m: option
do
  case "${option}"
  in
    e) RUN_ENVIR=${OPTARG};;
    m) machine=${OPTARG};;
  esac
done

RUN_ENVIR=${RUN_ENVIR:-nco}
machine=${machine:-wcoss2}

echo $RUN_ENVIR
echo $machine

LINK="ln -fs"
[[ $RUN_ENVIR = nco ]] && LINK="cp -rp"

pwd=$(pwd -P)

#------------------------------
#--model fix fields
#------------------------------
case "${machine}" in
  "wcoss2")
    FIX_DIR="/lfs/h2/emc/ens/save/emc.ens/FIX/gefs/fix_nco_gefsv12.3"
    FIX_DIR_FV3="/lfs/h2/emc/global/noscrub/emc.global/FIX/fix"
    ;;
  "hera")
    FIX_DIR="/scratch2/NCEPDEV/ensemble/noscrub/common/FIX/gefs/fix_nco_gefsv12.3"
    FIX_DIR_FV3="/scratch1/NCEPDEV/global/glopara/fix"
    ;;
  *)
    echo "FATAL: Unknown target machine ${machine}, couldn't set FIX_DIR"
    exit 1
    ;;
esac

# Delete Fix folder and relink/recopy it
cd ${pwd}/../fix
for dir in fix_gefs fix_wave fix_emission; do
  if [[ -d $dir ]]; then
    echo "Fix folder exists, deleting it..."
    rm -rf $dir
  fi
  $LINK $FIX_DIR/$dir $dir
done
cd ${pwd}

if [[ -d global-workflow.fd ]] ; then

  # Source fix version file
  source "${pwd}/../versions/fix.ver"

  cd ${pwd}/../fix

  for gw_dir in am aer lut orog chem; do
    if [[ -d $gw_dir ]]; then
      rm -rf $gw_dir
    fi
    #mkdir -p $(dirname $gw_dir)
    fix_ver="${gw_dir}_ver"
    ${LINK} "${FIX_DIR_FV3}/${gw_dir}/${!fix_ver}" "${gw_dir}"
  done

  # product
  sFolder=product
  if [[ -d $sFolder ]]; then
    rm -rf $sFolder
  fi
  $LINK ${pwd}/../sorc/global-workflow.fd/fix/${sFolder} ${sFolder}

  cd ${pwd}
fi

# copy/link exec files
cd $pwd
if [[ -d global-workflow.fd ]] ; then

  sPath=../sorc/global-workflow.fd/exec
  for sFile in ${sPath}/ww3_*
  do
    echo $sFile
  done
  $LINK ${sPath}/ww3_* ../exec/

  sPath=../sorc/global-workflow.fd/sorc/ufs_model.fd/tests
  $LINK ${sPath}/ufs_model.x ../exec/

  sPath=../sorc/global-workflow.fd/sorc/ufs_model.fd/FV3/upp/exec
  $LINK ${sPath}/upp.x ../exec/

  sPath=../sorc/global-workflow.fd/sorc/gsi_utils.fd/install/bin
  $LINK ${sPath}/getsigensmeanp_smooth.x ../exec/
  $LINK ${sPath}/getsfcensmeanp.x ../exec/

  sPath=../sorc/global-workflow.fd/sorc/gfs_utils.fd/install/bin
  $LINK ${sPath}/gfs_bufr.x ../exec/
  $LINK ${sPath}/tocsbufr.x ../exec/

  # chem_prep_emissions
  #sPath=../sorc/global-workflow.fd/sorc/gsd_prep_chem.fd/workflow/emc-global/exec
  #$LINK ${sPath}/prep_chem_sources_RADM_FV3_SIMPLE.exe ../exec/

fi

# Copy/Link parm files
cd $pwd
if [[ -d global-workflow.fd ]] ; then
  if [[ -d ../parm/parm_fv3diag ]]; then
    rm -rf ../parm/parm_fv3diag
  fi
  $LINK ../sorc/global-workflow.fd/parm/parm_fv3diag ../parm/

  if [[ -d ../parm/post ]]; then
    rm -rf ../parm/post
  fi
  $LINK ../sorc/global-workflow.fd/sorc/ufs_model.fd/FV3/upp/parm ../parm/post

  if [[ -d ../parm/product ]]; then
    rm -rf ../parm/product
  fi
  $LINK ../sorc/global-workflow.fd/parm/product ../parm/
fi


# Copy/Link ush files
cd $pwd
if [[ -d global-workflow.fd ]] ; then
  $LINK ../sorc/global-workflow.fd/sorc/ufs_utils.fd/ush/chgres_cube.sh ../ush/
  #$LINK ../sorc/global-workflow.fd/sorc/gfs_post.fd/ush/gfs_nceppost.sh ../ush/
fi

# For Forecast
cd $pwd
if [[ -d global-workflow.fd ]] ; then
  for sFile in scripts/exglobal_forecast.sh \
                ush/cplvalidate.sh \
                ush/forecast_predet.sh \
                ush/forecast_det.sh \
                ush/forecast_postdet.sh \
                ush/nems_configure.sh \
                ush/parsing_model_configure_FV3.sh \
                ush/parsing_model_configure_DATM.sh
  do
    if [[ -e ../$sFile ]]; then
      if [[ -L ../$sFile ]]; then
        rm ../$sFile
        $LINK ../sorc/global-workflow.fd/$sFile ../$sFile
      fi
    else
      $LINK ../sorc/global-workflow.fd/$sFile ../$sFile
    fi
  done
fi

# For wave
if [[ 1 == 0 ]]; then
echo $pwd
cd $pwd
if [[ -d global-workflow.fd ]]; then
  lScripts="exwave_init.sh exwave_nawips.sh exwave_post_sbs.sh exwave_prep.sh exwave_stat.sh"
  for sFile in $lScripts; do
    $LINK ../sorc/global-workflow.fd/scripts/$sFile ../scripts/
  done

  lUsh="wave_ens_bull.sh wave_ens_stat.sh wave_grib2_sbs.sh wave_grid_interp_sbs.sh wave_grid_moddef.sh wave_outp_spec.sh wave_prnc_cur.sh wave_prnc_ice.sh wave_tar.sh"
  for sFile in $lUsh; do
    $LINK ../sorc/global-workflow.fd/ush/$sFile ../ush/
  done

  if [[ -e ../env ]]; then
    if [[ -L ../env ]]; then
      rm ../env
      $LINK ${pwd}/global-workflow.fd/env ../
    fi
  else
    $LINK ${pwd}/global-workflow.fd/env ../
  fi
fi
fi

# for CHEM
if [[ -d global-workflow.fd ]]; then
  # for chem_prep_emissions
  #$LINK ../sorc/global-workflow.fd/sorc/gsd_prep_chem.fd/workflow/emc-global/scripts/exglobal_prep_chem.sh ../scripts/
  #$LINK ../sorc/global-workflow.fd/sorc/gsd_prep_chem.fd/workflow/emc-global/parm/prep_chem_sources.inp.IN ../parm/

  # for init_aerosol
  $LINK ../sorc/global-workflow.fd/ush/merge_fv3_aerosol_tile.py ../ush/
fi

# for atmos_prep for GFSv17
if [[ -d global-workflow.fd ]]; then
  $LINK ../sorc/global-workflow.fd/sorc/ufs_utils.fd/exec/chgres_cube ../exec/

  #$LINK ../sorc/global-workflow.fd/exec/chgres_recenter_ncio.exe ../exec/
  #$LINK ../sorc/global-workflow.fd/sorc/gsi.fd/exec/calc_increment_ens_ncio.x ../exec/
fi

exit 0

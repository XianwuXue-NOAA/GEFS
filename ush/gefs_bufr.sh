#! /usr/bin/env bash
#
#  UTILITY SCRIPT NAME :  gefsbufr.sh from gfs_bufr.sh
#               AUTHOR :  Hua-Lu Pan
#         DATE WRITTEN :  02/03/97
#
#  Abstract:  This utility script produces BUFR file of
#             station forecasts from the GEFS suite.
#
#     Input:  none
# Script History Log:
# 2016-10-30  H Chuang: Tranistion to read nems output.
#             Change to read flux file fields in gfs_bufr
#             so remove excution of gfs_flux
# 2018-03-22 Guang Ping Lou: Making it works for either 1 hourly or 3 hourly output
# 2018-05-22 Guang Ping Lou: Making it work for both GFS and FV3GFS 
# 2018-05-30  Guang Ping Lou: Make sure all files are available.
# 2023-02-06  Xianwu Xue: Read in NetCDF files and Change ksh to bash

echo "$(date -u) begin ${BASH_SOURCE}"

set -xa
if [[ ${STRICT:-NO} == "YES" ]]; then
  # Turn on strict bash error checking
  set -eu
fi

if [ "$F00FLAG" = "YES" ]; then
  f00flag=".true."
else
  f00flag=".false."
fi

export pgm=gfs_bufr.x
#. prep_step

if [ "$MAKEBUFR" = "YES" ]; then
  bufrflag=".true."
else
  bufrflag=".false."
fi

CLASS="class1fv3"

if [[ $SENDCOM == "YES" ]]; then
  if [[ ${NewCOM:-"YES"} == "YES" ]]; then
    dird="$COMOUT/$COMPONENT/products/bufr/bufr"
  else
    dird="$COMOUT/$COMPONENT/bufr/$mem/bufr"
  fi
else
  dird="$DATA/$mem/bufr"
fi

cat <<- EOF > gfsparm
	&NAMMET
		levs=$LEVS,makebufr=$bufrflag,
		dird="$dird",
		nstart=$FSTART,nend=$FEND,nint=$FINT,
		nend1=$NEND1,nint1=$NINT1,nint3=$NINT3,
		nsfc=80,f00=$f00flag,fformat=${fformat},np1=0
	/
	EOF

SLEEP_LOOP_MAX=$(($SLEEP_TIME / $SLEEP_INT))

if [[ ${NewCOM:-"YES"} == "YES" ]]; then
  CDUMP=gefs
else
  CDUMP=${RUNMEM}
fi

for (( hr = 10#${FSTART}; hr <= 10#${FEND}; hr = hr + 10#${FINT} )); do
  hh2=$(printf %02i "${hr}")
  hh3=$(printf %03i $hr)

  #---------------------------------------------------------
  # Make sure all files are available:
  ic=0
  while [ $ic -lt $SLEEP_LOOP_MAX ]; do
    if [[ ${NewCOM:-"YES"} == "YES" ]]; then
      fcstchk=$COMIN/$COMPONENT/${CDUMP}.${cycle}.logf${hh3}.${logfm}
    else
      fcstchk=$COMIN/$COMPONENT/sfcsig/${CDUMP}.${cycle}.logf${hh3}.${logfm}
    fi
    if [ ! -f $fcstchk ]; then
      sleep $SLEEP_INT
      ic=$(($ic + 1))
    else
      break
    fi

    if [ ${ic} -ge ${SLEEP_LOOP_MAX} ]; then
      echo <<- EOF
				FATAL ERROR in ${BASH_SOURCE}: Unable to find forecast output $fcstchk at $(date -u) after waiting ${SLEEP_TIME}s!
				EOF
			export err=6
      err_chk
      exit $err
    fi
  done
  #------------------------------------------------------------------
  if [[ ${NewCOM:-"YES"} == "YES" ]]; then
    ln -sf $COMIN/$COMPONENT/${CDUMP}.${cycle}.atmf${hh3}.nc sigf${hh2}
    ln -sf $COMIN/$COMPONENT/${CDUMP}.${cycle}.sfcf${hh3}.nc flxf${hh2}
  else
    ln -sf $COMIN/$COMPONENT/sfcsig/${CDUMP}.${cycle}.atmf${hh3}.nc sigf${hh2}
    ln -sf $COMIN/$COMPONENT/sfcsig/${CDUMP}.${cycle}.sfcf${hh3}.nc flxf${hh2}
  fi
done

#  define input BUFR table file.
# prep_step
ln -sf $PARMbufrsnd/bufr_gfs_${CLASS}.tbl fort.1
ln -sf ${STNLIST:-$PARMbufrsnd/bufr_stalist.meteo.gfs} fort.8
ln -sf "${PARMbufrsnd}/bufr_ij13km.txt" fort.7

$APRUN ${EXECbufrsnd}/gfs_bufr.x < gfsparm > out_gfs_bufr_${FEND}
export err=$?

if [[ $err != 0 ]]; then
  echo "FATAL ERROR in ${BASH_SOURCE}: gfs_bufr failed!"
  err_chk
  exit $err
fi

exit $err


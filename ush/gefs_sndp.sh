#! /usr/bin/env bash
################################################################
# Script Name:          gefs_sndp.sh
# Script Description:   Format GEFS BUFR sounding files for AWIPS
# Script History Log:
#   1) 2004-09-10       Steve Gilbert       First Implementation
################################################################

echo "$(date -u) begin ${BASH_SOURCE}"

set -xa
if [[ ${STRICT:-NO} == "YES" ]]; then
  # Turn on strict bash error checking
  set -eu
fi

#  Create "collectives" consisting of groupings of the soundings
#  into files designated by geographical region.   Each input
#  file gfs_collective*.list (1-9) contains the list of stations to
#  put in a particular collective output file. 
export m=$1
mkdir $DATA/$m
cd $DATA/$m
cp $FIXbufrsnd/gfs_collective${m}.list $DATA/$m/. 
CCCC=KWBC
file_list=gfs_collective${m}.list

if [ $m -le 2 ]; then 
  WMOHEAD=JUSA4$m
elif [ $m -le 6 ]; then 
  WMOHEAD=JUSB4$m
else
  WMOHEAD=JUSX4$m
fi

for stn in $(cat $file_list); do
  if [[ ${NewCOM:-"YES"} == "YES" ]]; then
    cp ${COMIN}/$COMPONENT/products/bufr/bufr.$stn.$PDY$cyc ${DATA}/${m}/bufrin
  else
    cp ${COMIN}/$COMPONENT/bufr/$mem/bufr.$stn.$PDY$cyc ${DATA}/${m}/bufrin
  fi
  export pgm=tocsbufr.x
  #. prep_step
  export FORT11=$DATA/${m}/bufrin
  export FORT51=./bufrout

  $EXECbufrsnd/${pgm} <<- EOF
		&INPUT
			BULHED="$WMOHEAD",KWBX="$CCCC",
			NCEP2STD=.TRUE.,
			SEPARATE=.TRUE.,
			MAXFILESIZE=600000
		/
	EOF

  export err=$?
  if [ $err -ne 0 ]; then
    echo <<- EOF
				FATAL ERROR in ${BASH_SOURCE}: $EXECbufrsnd/tocsbufr failed using the following namelist:
					&INPUT
						BULHED="$WMOHEAD",KWBX="$CCCC",
						NCEP2STD=.TRUE.,
						SEPARATE=.TRUE.,
						MAXFILESIZE=600000
					/
		EOF

    err_chk
    exit $err
  fi

  if [[ ${NewCOM:-"YES"} == "YES" ]]; then
    cat $DATA/${m}/bufrout >> $DATA/${m}/gefs_collective$m.fil 
  else
    cat $DATA/${m}/bufrout >> $DATA/${m}/${RUNMEM}_collective$m.fil
  fi
  rm $DATA/${m}/bufrin
  rm $DATA/${m}/bufrout
done

if [ $SENDCOM = 'YES' ]; then 
  if [[ ${NewCOM:-"YES"} == "YES" ]]; then
    cp $DATA/${m}/gefs_collective$m.fil ${COMOUT}/$COMPONENT/products/bufr/
  else
    cp $DATA/${m}/${RUNMEM}_collective$m.fil ${COMOUT}/$COMPONENT/bufr/$mem/.
  fi
  if [ $SENDDBN = 'YES' ] ; then
    MODCOM=$(echo ${NET}_${COMPONENT} | tr '[a-z]' '[A-Z]')
    DBNTYP=${MODCOM}_BUFRTAR_COL
    if [[ ${NewCOM:-"YES"} == "YES" ]]; then
      $DBNROOT/bin/dbn_alert MODEL ${DBNTYP} $job \
        ${COMOUT}/$COMPONENT/products/bufr/gefs_collective$m.fil
    else
      $DBNROOT/bin/dbn_alert MODEL ${DBNTYP} $job \
        ${COMOUT}/$COMPONENT/bufr/$mem/${RUNMEM}_collective$m.fil
    fi
  fi
# No approval for adding header to SBN yet
#	if [ $SENDDBN_NTC = 'YES' ] ; then
#		cp $DATA/${m}/${RUNMEM}_collective$m.fil $COMOUTwmo/${RUNMEM}_collective$m.postsnd_$cyc
#		$DBNROOT/bin/dbn_alert NTC_LOW BUFR $job $COMOUTwmo/${RUNMEM}_collective$m.postsnd_$cyc
#	fi
fi

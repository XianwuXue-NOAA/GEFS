#!/bin/bash

echo "$(date -u) begin $(basename $BASH_SOURCE)"
export PS4="${PS4}${1}: "

set -xa
if [[ ${STRICT:-NO} == "YES" ]]; then
	# Turn on strict bash error checking
	set -eu
fi

export mem=$1
export nmem=$(echo $mem|cut -c 2-)
nmem=${nmem#0}

export INPUT_TYPE="gaussian_netcdf"

export FIXgfs=${FIXgfs:-$HOMEgfs/fix}

export CRES=$(echo $CASE |cut -c2-5)
CRES_H=$((CRES+CRES))
export FIXfv3=$FIXgfs/orog/C$CRES
export FIXfv3_H=$FIXgfs/orog/C$CRES_H
export FIXsfc=$FIXfv3/fix_sfc
export FIXam=${FIXam:-$FIXgfs/am}
export VCOORD_FILE=${VCOORD_FILE:-$FIXam/global_hyblev.l${LEVS}.txt}

if [[ $USE_EARLY_ENKF == YES ]]; then

	if [[ $mem = c00 ]]; then
		echo "Working on c00"
		gmemdir=${COMINgdas}
		memdir=${COMINgfs}
	else
		echo "Working on ${mem}"

		(( cmem = nmem + memshift ))
		if (( cmem > 80 )); then
			(( cmem = cmem - 80 ))
		fi
		memchar="mem"$(printf %03i $cmem)

		gmemdir=${COMINenkf}/${memchar}
		memdir=${COMINenkfgfs}/${memchar}
	fi

	export INIDIR=$DATA
	cd $INIDIR

	mkdir -p $INIDIR/RESTART
	if [[ -e $COMOUT ]]; then
		rm -rf $COMOUT
	fi
	mkdir -p $COMOUT

	CDATE=${PDY}${cyc}
	sCDATE=$($NDATE -3 $CDATE)
	sPDY=$(echo $sCDATE | cut -c1-8)
	scyc=$(echo $sCDATE | cut -c9-10)

	gPDY=${pdyp}
	gcyc=${cycp}

	# Link all (except sfc_data) restart files from $gmemdir
	for file in $(ls $gmemdir/RESTART/${sPDY}.${scyc}0000.*.nc); do
		file2=$(echo $(basename $file))
		file2=$(echo $file2 | cut -d. -f3-) # remove the date from file
		fsuf=$(echo $file2 | cut -d. -f1)
		if [ $fsuf != "sfc_data" ]; then
			$NLN $file $INIDIR/RESTART/
		fi
	done

	# Link sfcanl_data restart files from $memdir
	for file in $(ls $memdir/RESTART/${sPDY}.${scyc}0000.*.nc); do
		file2=$(echo $(basename $file))
		file2=$(echo $file2 | cut -d. -f3-) # remove the date from file
		fsufanl=$(echo $file2 | cut -d. -f1)
		if [ $fsufanl = "sfcanl_data" ]; then
			file2=$(echo $file2 | sed -e "s/sfcanl_data/sfc_data/g")
			$NLN $file $INIDIR/RESTART/
		fi
	done

	# Need a coupler.res when doing IAU
	if [ $DOIAU = "YES" ]; then
		rm -f $INIDIR/RESTART/${sPDY}.${scyc}0000.coupler.res
		cat >> $INIDIR/RESTART/${sPDY}.${scyc}0000.coupler.res <<- EOF
			2        (Calendar: no_calendar=0, thirty_day_months=1, julian=2, gregorian=3, noleap=4)
			${gPDY:0:4}  ${gPDY:4:2}  ${gPDY:6:2}  ${gcyc}     0     0        Model start time:   year, month, day, hour, minute, second
			${sPDY:0:4}  ${sPDY:4:2}  ${sPDY:6:2}  ${scyc}     0     0        Current model time: year, month, day, hour, minute, second
		EOF
	fi

	# Link increments
	if [ $DOIAU = "YES" ]; then
		for i in $(echo $IAUFHRS | sed "s/,/ /g" | rev); do
			incfhr=$(printf %03i $i)
			if [ $incfhr = "006" ]; then
				increment_file=t${cyc}z.${PREFIX_ATMINC}atminc.nc
			else
				increment_file=t${cyc}z.${PREFIX_ATMINC}atmi${incfhr}.nc
			fi
			if [ ! -f $memdir/gfs.$increment_file ]; then
				echo "ERROR: DOIAU = $DOIAU, but missing increment file for fhr $incfhr at $memdir/gfs.$increment_file"
				echo "Abort!"
				exit 1
			fi
			$NLN $memdir/gfs.$increment_file $INIDIR/gefs.$increment_file
		done
	else
		increment_file=t${cyc}z.${PREFIX_ATMINC}atminc.nc
		if [ -f $memdir/gfs.$increment_file ]; then
			$NLN $memdir/gfs.$increment_file $INIDIR/gefs.$increment_file
		fi
	fi

	if [[ $mem = c00 ]]; then
        export CONVERT_NST=".false."
		export INPUT_TYPE='restart'
		export MOSAIC_FILE_INPUT_GRID="${FIXfv3_H}/C${CRES_H}_mosaic.nc"
        export MOSAIC_FILE_TARGET_GRID="${FIXfv3}/C${CRES}_mosaic.nc"
		export OROG_DIR_INPUT_GRID="${FIXfv3_H}"

		OROG_FILES_INPUT_GRID=""
		ATM_CORE_FILES_INPUT=""
		ATM_TRACER_FILES_INPUT=""
		SFC_FILES_INPUT=""
		for tile in {1..6}
		do
			OROG_FILES_INPUT_GRID=${OROG_FILES_INPUT_GRID}"C${CRES_H}_oro_data.tile${tile}.nc"
			ATM_CORE_FILES_INPUT=${ATM_CORE_FILES_INPUT}"${sPDY}.${scyc}0000.fv_core.res.tile${tile}.nc"
			ATM_TRACER_FILES_INPUT=${ATM_TRACER_FILES_INPUT}"${sPDY}.${scyc}0000.fv_tracer.res.tile${tile}.nc"
			SFC_FILES_INPUT=${SFC_FILES_INPUT}"${sPDY}.${scyc}0000.sfcanl_data.tile${tile}.nc"
			if [[ $tile != 6 ]]; then
				OROG_FILES_INPUT_GRID=${OROG_FILES_INPUT_GRID}'","'
				ATM_CORE_FILES_INPUT=${ATM_CORE_FILES_INPUT}'","'
				ATM_TRACER_FILES_INPUT=${ATM_TRACER_FILES_INPUT}'","'
				SFC_FILES_INPUT=${SFC_FILES_INPUT}'","'
			fi
		done

		export OROG_FILES_INPUT_GRID
		ATM_CORE_FILES_INPUT=${ATM_CORE_FILES_INPUT}'","'
		export ATM_CORE_FILES_INPUT=${ATM_CORE_FILES_INPUT}"${sPDY}.${scyc}0000.fv_core.res.nc"
		export ATM_TRACER_FILES_INPUT
		export SFC_FILES_INPUT

		export TRACERS_TARGET='"sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"'
		export TRACERS_INPUT='"sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"'

		export COMIN=$INIDIR/RESTART

		# Execute the script
		$USHgfs/chgres_cube.sh
		export err=$?
		if [[ $err != 0 ]]; then
			echo "FATAL ERROR in $(basename $BASH_SOURCE): chgres_cube failed!"
			exit $err
		fi
	fi

	if [[ $SENDCOM == "YES" ]]; then
		if [[ $mem = c00 ]]; then
			echo "Copying $mem to COM Directory!"
			if [[ -e $COMOUT/INPUT ]]; then
				rm -rf $COMOUT/INPUT
			fi
			mkdir -p $COMOUT/INPUT

			for tile in {1..6}
			do
				mv $INIDIR/out.sfc.tile${tile}.nc $COMOUT/INPUT/sfc_data.tile${tile}.nc
				mv $INIDIR/out.atm.tile${tile}.nc $COMOUT/INPUT/gfs_data.tile${tile}.nc
			done
			mv $INIDIR/gfs_ctrl.nc $COMOUT/INPUT/
		else
			echo "Copying $mem to COM Directory!"
			$NCP $INIDIR/*.nc $COMOUT/
			$NCP $INIDIR/RESTART $COMOUT/
		fi
	fi

	echo "$(date -u) end $(basename $BASH_SOURCE)"
	exit 0
fi

export INIDIR=$DATA
export OUTDIR=$GESOUT/enkf/$mem
INITDIR=$GESOUT/init/$mem
mkdir -p $INIDIR
mkdir -p $OUTDIR
mkdir -p $INITDIR

cd $INIDIR

if [[ $mem = c00 ]] ;then
	# Control intial conditions from current GFS cycle
	ATMFILE=$COMINgfs/gfs.t${cyc}z.atmanl.nc
	if [[ -f $ATMFILE ]]; then
		$NCP $ATMFILE $INIDIR
		export ATM_FILES_INPUT="gfs.t${cyc}z.atmanl.nc"
	else
		msg="FATAL ERROR in $(basename $BASH_SOURCE): GFS atmospheric analysis file $ATMFILE not found!"
		echo "$msg"
		export err=101
		err_chk || exit $err
	fi
	export CONVERT_SFC=".true."

else
	i=0
	success="NO"
	(( cmem = nmem + memshift ))
	while [[ $success == "NO" && $i < $MAX_ENKF_SEARCHES ]]; do
		if (( cmem > 80 )); then
			(( cmem = cmem - 80 ))
		fi

		memchar="mem"$(printf %03i $cmem)
		ATMFILE="$COMINenkf/$memchar/gdas.t${cycp}z.atmf006.nc"

		if [[ -f $ATMFILE ]]; then
			$NCP $ATMFILE $INIDIR
			export ATM_FILES_INPUT="gdas.t${cycp}z.atmf006.nc"
			success="YES"

		else
			(( i = i + 1 ))
			if [[ $i < $MAX_ENKF_SEARCHES ]]; then
				echo "EnKF atmospheric file $ATMFILE not found, trying different member"
				(( cmem = cmem + ENKF_SEARCH_LEAP ))

			else
				msg="FATAL ERROR in $(basename $BASH_SOURCE): Unable to find EnKF atmospheric file after $MAX_ENKF_SEARCHES attempts"
				echo $msg
				export err=102
				err_chk || exit $err
			fi
		fi # [[ -f $ATMFILE ]]
	done # [[ success == "NO" && $i < MAX_ENKF_SEARCHES ]]
	export CONVERT_SFC=".false."
fi

if [[ $CONVERT_SFC == ".true." ]]; then
	export SFC_FILES_INPUT="gfs.t${cyc}z.sfcanl.nc"
	SFCFILE="$COMINgfs/$SFC_FILES_INPUT"
	if [[ -f $SFCFILE ]]; then
		$NCP $SFCFILE $INIDIR
	else
		msg="FATAL ERROR in $(basename $BASH_SOURCE): GFS surfce analysis $SFCFILE not found!"
		echo $msg
		export err=100
		err_chk || exit $err
	fi
fi

export CRES=$(echo $CASE |cut -c2-5)
export COMIN=$INIDIR
export INPUT_TYPE="gaussian_netcdf"
export FIXfv3=$FIXgfs/orog/C$CRES
export FIXsfc=$FIXfv3/fix_sfc
#############################################################
# Execute the script
$USHgfs/chgres_cube.sh
export err=$?
if [[ $err != 0 ]]; then
	echo "FATAL ERROR in $(basename $BASH_SOURCE): chgres_cube failed!"
	exit $err
fi
#############################################################

# Move files to the nwges directory
for tile in tile1 tile2 tile3 tile4 tile5 tile6; do
	mv ${DATA}/out.atm.${tile}.nc $OUTDIR/gfs_data.${tile}.nc
done
mv ${DATA}/gfs_ctrl.nc $OUTDIR/.

touch ${OUTDIR}/chgres_atm.log  # recenter can start now

if [[ $CONVERT_SFC == ".true." ]]; then
	# Copy sfc files to the nwges directory for all members
	for mem2 in $memberlist; do
		INITDIR2=$GESOUT/init/$mem2
		mkdir -p $INITDIR2
		for tile in tile1 tile2 tile3 tile4 tile5 tile6; do
			$NCP ${DATA}/out.sfc.${tile}.nc $INITDIR2/sfc_data.${tile}.nc
		done
	done
fi

# Copy control file to init
$NCP $OUTDIR/gfs_ctrl.nc $INITDIR

if [[ $SENDCOM == "YES" ]]; then
	MODCOM=$(echo ${NET}_${COMPONENT} | tr '[a-z]' '[A-Z]')
	DBNTYP=${MODCOM}_INIT	
	COMDIR=$COMOUT/init/$mem
	mkdir -p $COMDIR
	$NCP $OUTDIR/gfs_ctrl.nc $COMDIR
	if [[ $SENDDBN = YES ]];then
		$DBNROOT/bin/dbn_alert MODEL $DBNTYP $job $COMDIR/gfs_ctrl.nc
	fi
	if [[ $mem == "c00" ]]; then
		$NCP $OUTDIR/gfs_data*.nc $COMDIR
		if [[ $SENDDBN = YES ]];then
			for tile in tile1 tile2 tile3 tile4 tile5 tile6; do
				$DBNROOT/bin/dbn_alert MODEL $DBNTYP $job $COMDIR/gfs_data.${tile}.nc
			done
		fi
	fi
	if [[ $CONVERT_SFC == ".true." ]]; then
		for mem2 in $memberlist; do
			COMDIR2=$COMOUT/init/$mem2
			mkdir -p $COMDIR2
			for tile in tile1 tile2 tile3 tile4 tile5 tile6; do
				$NCP $GESOUT/init/$mem/sfc_data.${tile}.nc $COMDIR2
				if [[ $SENDDBN = YES ]];then
					$DBNROOT/bin/dbn_alert MODEL $DBNTYP $job $COMDIR2/sfc_data.${tile}.nc
				fi
			done
		done
	fi
fi

echo "$(date -u) end $(basename $BASH_SOURCE)"

exit $err


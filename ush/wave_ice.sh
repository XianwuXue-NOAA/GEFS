#!/bin/sh
###############################################################################
#                                                                             #
# This script preprocesses ice fields for the ocean wave models.              #
# It is run as a child scipt by the corresponding preprocessig script.        #
#                                                                             #
# Remarks :                                                                   #
# - This script runs in the work directory designated in the mother script in #
#   which it generates its own sub-directory 'ice'.                           #
# - Because this script is not essential for the running for the wave model   #
#   (as long as it runs every now and then) the error exit codes are set to   #
#   0. The main program script will then not find the file ice.ww3 and send   #
#   a message to the wave.log file.                                           #
# - See section 0.b for variables that need to be set.                        #
#                                                                             #
#  Update record :                                                            #
#                                                                             #
# - Origination:                                               01-Mar-2007    #
#                                                                             #
###############################################################################
#
# --------------------------------------------------------------------------- #
# 0.  Preparations
# 0.a Basic modes of operation

  cd $DATA
  seton='-xa'
  setoff='+xa'
  set $seton

  rm -rf ice
  mkdir ice
  cd ice
  ln -s ../postmsg .

# 0.b Define directories and the search path.
#     The tested variables should be exported by the postprocessor script.

  set $setoff
  echo ' '
  echo '+--------------------------------+'
  echo '!         Make ice fields        |'
  echo '+--------------------------------+'
  echo "   Model ID        : $modID"
  echo "   Ice grid ID     : $iceID"
  echo ' '
  set $seton
  postmsg "$jlogfile" "Making ice fields."

  if [ -z "$YMDH" ] || [ -z "$cycle" ] || \
     [ -z "$COMOUT" ] || [ -z "$FIXwave" ] || [ -z "$EXECcode" ] || \
     [ -z "$modID" ] || [ -z "$iceID" ] || [ -z "$SENDCOM" ] || \
     [ -z "$COMICE" ]
  then
    set $setoff
    echo ' '
    echo '**************************************************'
    echo '*** EXPORTED VARIABLES IN preprocessor NOT SET ***'
    echo '**************************************************'
    echo ' '
    exit 0
    set $seton
    postmsg "$jlogfile" "NON-FATAL ERROR - EXPORTED VARIABLES IN preprocessor NOT SET"
  fi

# 0.c Links to working directory

  ln -s ../mod_def.$iceID mod_def.ww3

# --------------------------------------------------------------------------- #
# 1.  Get the necessary files
# 1.a Copy the ice data file

  if [ "$cycle" = 't00z' ]  || [ "$cycle" = 't06z' ]
  then
    timeID="`$NDATE -24 $YMDH | cut -c3-8`00"
    YMD="`$NDATE -24 $YMDH | cut -c1-8`"
  else
    timeID="`echo $YMDH | cut -c 3-8`00"
    YMD="`echo $YMDH | cut -c 1-8`"
  fi

  file=$COMICE/sice.$YMD/seaice.t00z.5min.grb.grib2

  if [ -f $file ]
  then
    cp $file ice.grib
  fi

  if [ -f ice.grib ]
  then
    set $setoff
    echo "   ice.grib copied ($file)."
    set $seton
  else
    set $setoff
    echo ' '
    echo '************************************** '
    echo "*** ERROR : NO ICE FILE $file ***  "
    echo '************************************** '
    echo ' '
    set $seton
    postmsg "$jlogfile" "NON-FATAL ERROR - NO ICE FILE (GFS GRIB)"
    exit 0
  fi

# --------------------------------------------------------------------------- #
# 2.  Process the GRIB packed ice file
# 2.a Make an index file

  set $setoff
  echo ' '
  echo '   Making GRIB index file ...'
  set $seton

  $WGRIB2 ice.grib > ice.index

# 2.b Check valid time in index file

  set $setoff
  echo "   Time ID of ice field : $timeID"
  set $seton

  if [ -z "`grep $timeID ice.index`" ]
  then
    set $setoff
    echo ' '
    echo '********************************************** '
    echo '*** ERROR : ICE FIELD WITH UNEXPECTED DATE *** '
    echo '********************************************** '
    echo ' '
    set $seton
    postmsg "$jlogfile" "NON-FATAL ERROR - ICE FIELD WITH UNEXPECTED DATE"
    exit 0
  fi

# 2.c Unpack data

  set $setoff
  echo '   Extracting data from ice.grib ...'
  set $seton

  grep $timeID ice.index | \
           $WGRIB2 ice.grib -netcdf icean_5m.nc 2>&1 > wgrib.out
           #$WGRIB ice.grib -i -text -o ice.raw 2>&1 > wgrib.out

  err=$?

  if [ "$err" != '0' ]
  then
    cat wgrib.out
    set $setoff
    echo ' '
    echo '**************************************** '
    echo '*** ERROR IN UNPACKING GRIB ICE FILE *** '
    echo '**************************************** '
    echo ' '
    set $seton
    postmsg "$jlogfile" "NON-FATAL ERROR IN UNPACKING GRIB ICE FILE."
    exit 0
  fi

  rm -f wgrib.out
  rm -f ice.grib 
  rm -f ice.index


# 2.d Run through preprocessor wave_prep

  set $setoff
  echo '   Run through preprocessor ...'
  echo ' '
  set $seton

  #sed "s/YYYYMMDD/$YMD/g" ../ww3_prnc.$iceID.tmpl > ww3_prep.inp
  cp -f ../ww3_prnc.ice.$iceID.inp.tmpl ww3_prnc.inp

#  ln -s ../$iceID.$cycle.ice ice.ww3
  #$EXECcode/ww3_prep > wave_prep.out
  $EXECcode/ww3_prnc #> wave_prnc.out
  err=$?

  if [ "$err" != '0' ]
  then
    cat wave_prep.out
    set $setoff
    echo ' '
    echo '************************* '
    echo '*** ERROR IN waveprep *** '
    echo '************************* '
    echo ' '
    set $seton
    postmsg "$jlogfile" "NON-FATAL ERROR IN waveprep."
    exit 0
  fi

  rm -f wave_prep.out
  rm -f ww3_prep.inp
  rm -f ice.raw
#  rm -f ice.ww3
  rm -f mod_def.ww3

# --------------------------------------------------------------------------- #
# 3.  Save the ice file

  if [ "$SENDCOM" = 'YES' ]
  then
    set $setoff
    echo "   Saving ice.ww3 as $COMOUT/${modID}.${iceID}.$cycle.ice"
    set $seton
    # Check if ice was already copied by other ensemble member process
    if [ ! -f $COMOUT/${modID}.${iceID}.$cycle.ice ]
    then
      cp ice.ww3 $COMOUT/${modID}.${iceID}.$cycle.ice
    fi
  fi 

  rm -f ice.ww3

# --------------------------------------------------------------------------- #
# 4.  Clean up the directory

  set $setoff
  echo "   Removing work directory after success."
  set $seton

  cd ..
  rm -rf ice

  set $setoff
  echo ' '
  echo 'End of waveice.sh at'
  date

# End of waveice.sh --------------------------------------------------------- #
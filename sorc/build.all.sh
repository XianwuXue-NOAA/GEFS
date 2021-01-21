#!/bin/sh
set -ex

echo "`date`   `pwd`   $0 $*   begin"
# 20190917 RLW allow selective build by argument list
dtg=`date +%Y%m%d%H%M%S`
logfile=`basename $0`.log
logfiled=$logfile.$dtg
if [[ -f $logfile ]]; then
  rm $logfile
fi


if [ ! -d "../exec" ]; then
    echo "Creating ../exec folder"
    mkdir ../exec
fi
# Check final exec folder exists in util folder
if [ ! -d "../util/exec" ]; then
  echo "Creating ../util/exec folder"
  mkdir ../util/exec
fi

(
echo "`date`   `pwd`   $0 $*   begin log"
pwd
dirsaved=`pwd`

echo ".....Download fix from HPSS..."
cd ../
if [ -d "../fix" ]; then
  echo "Deleting ../fix folder"
  rm -rf ../fix
fi
fixPath=/gpfs/dell1/nco/ops/nwprod/gefs_legacy.v10.5.1/fix
if [ -d $fixPath ]; then
    cp -rfp $fixPath .
else
    module load HPSS/5.0.2.5 
    htar -xvf /NCEPDEV/emc-ensemble/5year/Xianwu.Xue/ForOperation/GEFS_legacy/fix_20200124.tar
fi
cd $dirsaved

echo ".....Compiling gefs_global_fcst ..."
./build.fcst.log.sh

# For building and installing all GEFS programs
module purge
module use ./
module load Module_gefs_legacy_v10.5.0

echo "`date`   build.sh $*   before"
sh build.sh $*
echo "`date`   build.sh $*   after"

echo ".....Installing..."
./install.sh

echo ".....Compiling ens-tracker..."
cd ${dirsaved}/../sorc.tracker
module use .
module load Module_ens_tracker.v1.1.15_for_Dell
./build.sh
cd ${dirsaved}


echo "`date`   `pwd`   $0 $*   end of log"
) 2>&1 | tee $logfiled
ln $logfiled $logfile
echo "`date`   `pwd`   $0 $*   end"
exit

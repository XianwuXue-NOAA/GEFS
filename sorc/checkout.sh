#!/bin/sh
set -xu

topdir=$(pwd)
echo $topdir

logs_dir=${topdir}/logs
if [ ! -d $logs_dir  ]; then
  echo "Creating logs folder"
  mkdir $logs_dir
fi

echo Global_workflow checkout ...
if [[ ! -d global-workflow.fd ]] ; then
    rm -f ${logs_dir}/checkout-global-workflow.log
    if [[ -d /scratch1/NCEPDEV ]] ; then
        git clone https://github.com/XianwuXue-NOAA/global-workflow.git global-workflow.fd >>  ${logs_dir}/checkout-global-workflow.log 2>&1
        cd global-workflow.fd
        git checkout release/gefs_v12_port2hera #gefs_v12.3.0-0
    else
        git clone https://github.com/NOAA-EMC/global-workflow.git global-workflow.fd >>  ${logs_dir}/checkout-global-workflow.log 2>&1
        cd global-workflow.fd
        git checkout gefs_v12.3.0-0
    fi
	cd sorc
    ./checkout.sh
    ERR=$?

    if [ $ERR = 0 ]; then
        msg="Checkout global-workflow normally"
    else
        msg="Checkout global-workflow failed!"
    fi

    cd ${topdir}

    exit $ERR
else
    echo 'Skip. Directory global_workflow.fd already exists.'
fi

exit 0

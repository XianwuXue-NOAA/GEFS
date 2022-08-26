module load ips/18.0.1.163
module load g2/3.1.0
module load w3nco/2.0.6
module load bacio/2.0.2
#module load sfcio/1.0.0
module load jasper/1.900.29
module load libpng/1.2.59
module load zlib/1.2.11 
module load ip/3.0.1
module load sp/2.0.2

#module load impi/18.0.1
#module load nemsio/2.2.3

##
export FCMP=ifort
export LDFLAGSM=
export OMPFLAGM=


# Check final exec folder exists
if [ ! -d "../exec" ]; then
  mkdir ../exec
fi

export FCMP=${FCMP:-ifort}
export FCMP95=$FCMP

export FFLAGSM="-O3 -g -convert big_endian"
export RECURS=
export LDFLAGSM=${LDFLAGSM:-""}
export OMPFLAGM=${OMPFLAGM:-""}

export INCSM="-I ${G2_INC4}"

export LIBSM="${G2_LIB4} ${W3NCO_LIB4} ${BACIO_LIB4} ${IP_LIB4} ${SP_LIB4} ${JASPER_LIB} ${PNG_LIB} ${Z_LIB}"

cd /gpfs/hps3/emc/ensemble/save/Wei.Li/GEFSv12_daily/sorc 
make -f make.gefsv12_1mem_p1.dell
mv *.x ../exec/


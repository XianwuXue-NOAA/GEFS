#!/bin/ksh
#Created by Wei Li: Collect 52 SubX variables from pgrb2ap5 and pgrb2bp5 and interpolate to 1 degree  ---- Apr.14 2020

mem=${mem}
output_dir=${COMOUT}/pgrbsubx1p0
echo ${output_dir}

export gridp1="latlon 0:360:1 90:181:-1"
# The following are options for $WGRIB2 when used to change grid resolution
export option1=${option1:-' -set_grib_type same -new_grid_winds earth '}
export option21=${option21:-' -new_grid_interpolation bilinear  -if '}
export option22=${option22:-":(LAND|CSNOW|CRAIN|CFRZR|CICEP|ICSEV):"}
export option23=${option23:-' -new_grid_interpolation neighbor -fi '}
export option24=${option24:-' -set_bitmap 1 -set_grib_max_bits 16 -if '}
export option25=${option25:-":(APCP|ACPCP|NCPCP|PRATE|CPRAT):"}
export option26=${option26:-' -set_grib_max_bits 25 -fi -if '}
export option27=${option27:-":(APCP|ACPCP|NCPCP|PRATE|CPRAT|DZDT):"}
export option28=${option28:-' -new_grid_interpolation budget -fi '}

parmlist=$PARMgefs/gefs_subx.parm

for fhr in {0..$fhmax..6}
do

fhrs="$(printf "%03d\n" $fhr)"
echo $fhrs

##read pgrba and pgrbb
pgtema=${pgrb2ap5_dir}/${mem}.t00z.pgrb2a.0p50.f${fhrs}
pgtemb=${pgrb2bp5_dir}/${mem}.t00z.pgrb2b.0p50.f${fhrs}
$WGRIB2 -s $pgtema | grep -F -f $parmlist | $WGRIB2  $pgtema -s -i -grib ${output_dir}/${mem}.t00z.subx.0p50.f${fhrs} 
$WGRIB2 -s $pgtemb | grep -F -f $parmlist | $WGRIB2  $pgtemb -s -i -append -grib ${output_dir}/${mem}.t00z.subx.0p50.f${fhrs} 
#interpolation
$WGRIB2 ${output_dir}/${mem}.t00z.subx.0p50.f${fhrs} $option1 $option21 $option22 $option23 $option24 $option25 $option26 $option27 $option28 -new_grid $gridp1 ${output_dir}/${mem}.t00z.subx.1p0.f${fhrs} 

rm -rf ${output_dir}/${mem}.t00z.subx.0p50.f${fhrs}

done #fhr

program daily_ave_acc
! main program: daily_ave_acc 
! Author: Wei Li :2016-12-20
! REF: Yali Mao, Bo Cui
! Purpose: calculate daily mean and accumulation (00Z,06Z,12Z,18Z), (12Z-12Z) 
! 
! usage: daily_ave_acc.exe yyyymmdd
!
!   input file: ncep/cmc/fnmoc ensemble forecast                                          
!
!   output file: daily mean and accumulation

! programs called:
!   baopenr          grib i/o
!   baopenw          grib i/o
!   baclose          grib i/o
!   getgb2           grib reader
!   putgb2           grib writer
!   init_parm        define grid definition and product definition
!   printinfr        print grib2 data information
!   change_template4 change data values for specified Product Definition Template

! exit states:
!   cond =   0 - successful run
!   cond =   1 - I/O abort
!
! attributes:
!   language: fortran 90
!
!$$$

use grib_mod
use params
implicit none

type(gribfield) :: gfld,gfldo

!type pdt_t0 
!    integer :: npdt0   ! Product Definition Template Number
!    integer :: icat0   ! Parameter Category by Product Discipline 
!    integer :: iprm0   ! Parameter Number by Product Discipline and Parameter Category
!    integer :: igp0    ! Type of Generating Process
!    integer :: iffs0   ! Type of first fixed surface 
!    integer :: isf0    ! Scale factor of first fixed surface
!    integer :: isv0    !Scaled value of first fixed surface
!end type pdt_t0
!
!! PDT parameters in the input GRIB2 file (template 4 number, category, parameter, type of level)
!type(pdt_t0), parameter :: &
!in pgrb2a
!    pdt_hgt850  = pdt_t0(1, 3, 5, 4, 100, 0, 85000), &
!    pdt_tmp100  = pdt_t0(1, 0, 0, 4, 100, 0,10000), &
!    pdt_ugrd10  = pdt_t0(1, 2, 2, 4, 100, 0, 1000), &
!    pdt_ugrd50  = pdt_t0(1, 2, 2, 4, 100, 0, 5000), &
!    pdt_vgrd10  = pdt_t0(1, 2, 3, 4, 100, 0, 1000), &
!    pdt_vgrd50  = pdt_t0(1, 2, 3, 4, 100, 0, 5000), &
!    pdt_hgt50   = pdt_t0(1, 3, 5, 4, 100, 0, 5000), &
!    pdt_tmp10   = pdt_t0(1, 0, 0, 4, 100, 0, 1000), &
!    pdt_tmp50   = pdt_t0(1, 0, 0, 4, 100, 0, 5000), &
!    pdt_hgt10   = pdt_t0(1, 3, 5, 4, 100, 0, 1000), &

!now in pgrb2a
!    pdt_ugrd30  = pdt_t0(1, 2, 2, 4, 100, 0, 3000), &
!    pdt_vgrd30  = pdt_t0(1, 2, 3, 4, 100, 0, 3000), &
!    pdt_hgt30   = pdt_t0(1, 3, 5, 4, 100, 0, 3000), &
!    pdt_tmp30   = pdt_t0(1, 0, 0, 4, 100, 0, 3000), &

integer :: nfield
parameter(nfield=14) !not include SNOWC and ICEC

type pdt_t
    integer,dimension(nfield):: npdt  ! Product Definition Template Number
    integer,dimension(nfield):: icat  ! Parameter Category by Product Discipline
    integer,dimension(nfield):: iprm  ! Parameter Number by Product Discipline and Parameter Category
    integer,dimension(nfield):: igp   ! Type of Generating Process
    integer,dimension(nfield):: iffs  ! Type of first fixed surface 
    integer,dimension(nfield):: isf   ! Scale factor of first fixed surface
    integer,dimension(nfield):: isv   !Scaled value of first fixed surface
end type pdt_t

type(pdt_t) :: pdt

!  columns:   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36
data pdt%npdt/1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1/   ! Product Definition Template Number
data pdt%icat/3,  0,  2,  2,  2,  2,  3,  0,  0,  3,  2,  2,  3,  0/  ! Parameter Category by Product Discipline
data pdt%iprm/5,  0,  2,  2,  3,  3,  5,  0,  0,  5,  2,  3,  5,  0/     ! Parameter Number by Product Discipline and Parameter Category
data pdt%igp /4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4/    ! Type of Generating Process
data pdt%iffs/100,100,100,100,100,100,100,100,100,100,100,100,100,100/   ! Type of first fixed surface 
data pdt%isf /0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0/   ! Scale factor of first fixed surface
data pdt%isv/85000,10000,1000,5000,1000,5000,5000,1000,5000,1000,3000,3000,3000,3000/    !Scaled value of first fixed surface

integer :: n_time
parameter(n_time=141)
integer :: j,jpdtn,jgdtn
integer,dimension(200) :: jids,jpdt,jgdt
logical :: unpack=.true.
integer :: jdisc      ! discipline#, table 0.0(met:0 hydro:1 land:2)
integer :: day,month,year,hour,fhour
character(len=256) :: datafile(n_time),outfile,file_dir,out_dir
character(len=8) :: file_date
character(len=5) :: ens_mem
integer :: unit, nx,ny,iret,jret,i,k,ifh,nfi,maxgrd,ifd,ivar,ind,icount,ens_id
character(len=3) ::sfh,smn
character(len=2) ::sdy
character(len=4) ::syr
character(len=8) :: pabbrev
character(len=30) :: labbrev
character(len=30) :: labbrev_short

real, allocatable :: var(:,:) ! 
real, allocatable :: var_save(:,:) ! 
real, allocatable :: var_save_daily(:,:) ! (maxgrd,35,nen)

!datafile(1)='/gpfs/hps/emc/ensemble/noscrub/Wei.Li/SCRIPT/SubX/gefs.20141001/00/gep_APCP.2014100100.grb2'

call GET_COMMAND_ARGUMENT(1, file_date)
call get_environment_variable("file_dir", file_dir)
call get_environment_variable("out_dir", out_dir)
call get_environment_variable("ens_mem", ens_mem)
print *,'file dir:',trim(file_dir)


do ivar=1,nfield !number of required fields

icount=0

   nfi=0
   do_ifh_loop: do ifh=0,840,6  !foercast hours

     nfi=nfi+1
        write(sfh,'(i3.3)') ifh

!search in either pgrb2a and pgrb2b
          datafile(nfi)=trim(file_dir)//'/gefs.'//trim(file_date)//'/00/subx_dell/'//trim(ens_mem)//'.t00z.subx.1p0.f'//trim(sfh)

     unit = nfi

     call BAOPENR(unit, datafile(nfi), iret)

     if(iret /= 0 ) then
       write(*,*) "there is no GEFS forecast",datafile(nfi)
     end if

     j = 0
     jids=-9999;jpdt=-9999; jgdt=-9999
     jdisc=-1; jgdtn=-1

     jpdtn = pdt%npdt(ivar)  !template version num. 
     jpdt(1)  = pdt%icat(ivar)
     jpdt(2)  = pdt%iprm(ivar)
     jpdt(3)  = pdt%igp(ivar)
     jpdt(10) = pdt%iffs(ivar)
     jpdt(11) = pdt%isf(ivar)
     jpdt(12) = pdt%isv(ivar)
!
!     call init_parm(ipdtn,ipdt,igdtn,igdt,idisc,iids)
! for template 4.11, no varuable in f00
     if (jpdtn == 11 .and. ifh == 0 )then 
          cycle do_ifh_loop
     end if

     call getgb2(unit,0,j,jdisc,jids,jpdtn,jpdt,jgdtn,jgdt,unpack,j,gfld,iret)
     if (iret /= 0) then
        write(*,*) "reading file iret=", iret
        stop
     end if

     maxgrd=gfld%ngrdpts
     nx = gfld%igdtmpl(8)
     ny = gfld%igdtmpl(9)
! assign gfldo same arribute for gfld
     gfldo=gfld

     if(.not. allocated(var)) allocate(var(nx,ny))
     var(:,:) = reshape(gfld%fld(:),[nx,ny])

     if(.not. allocated(var_save)) allocate(var_save(maxgrd,n_time))
     var_save(:,nfi) = gfld%fld
! date
     year  = gfld%idsect(6)
     month = gfld%idsect(7)
     day   = gfld%idsect(8)
     hour  = gfld%idsect(9)
     write(syr,'(i4.4)') year
     write(sdy,'(i2.2)') day
     if (month.eq.1) then
         smn='jan'
     end if
     if (month.eq.2) then
         smn='feb'
     end if
     if (month.eq.3) then
         smn='mar'
     end if
     if (month.eq.4) then
         smn='apr'
     end if
     if (month.eq.5) then
         smn='may'
     end if
     if (month.eq.6) then
         smn='jun'
     end if
     if (month.eq.7) then
         smn='jul'
     end if
     if (month.eq.8) then
         smn='aug'
     end if
     if (month.eq.9) then
         smn='sep'
     end if
     if (month.eq.10) then
         smn='oct'
     end if
     if (month.eq.11) then
         smn='nov'
     end if
     if (month.eq.12) then
         smn='dec'
     end if
!- forecast hour
     fhour=gfld%ipdtmpl(9)
     ens_id=gfld%ipdtmpl(17)
     !write(*,*), 'yymmddhh:', year,month,day,hour,fhour

     pabbrev=param_get_abbrev(gfld%discipline,gfld%ipdtmpl(1),gfld%ipdtmpl(2))
     call prlevel(gfld%ipdtnum,gfld%ipdtmpl,labbrev)

     deallocate(var)
!WWLL: 4/15/2020 comments of for dell
!     call gf_free(gfld)
     call BACLOSE(unit, iret)


 enddo do_ifh_loop !ifh

!open files for output grib2
     labbrev_short=trim(labbrev)
     print *,pabbrev//trim(labbrev_short(1:4))
     if(pabbrev=='UGRD'.and.trim(labbrev_short(1:4)).eq.' 10') then
outfile=trim(out_dir)//'ua_10_GEFS_'//sdy//smn//syr//'_00z_d01_d35_m'//ens_mem(4:5)//'.grb2'
     end if
     if(pabbrev=='UGRD'.and.trim(labbrev_short(1:4)).eq.' 30') then
outfile=trim(out_dir)//'ua_30_GEFS_'//sdy//smn//syr//'_00z_d01_d35_m'//ens_mem(4:5)//'.grb2'
     end if
     if(pabbrev=='UGRD'.and.trim(labbrev_short(1:4)).eq.' 50') then
outfile=trim(out_dir)//'ua_50_GEFS_'//sdy//smn//syr//'_00z_d01_d35_m'//ens_mem(4:5)//'.grb2'
     end if
     if(pabbrev=='VGRD'.and.trim(labbrev_short(1:4)).eq.' 10') then
outfile=trim(out_dir)//'va_10_GEFS_'//sdy//smn//syr//'_00z_d01_d35_m'//ens_mem(4:5)//'.grb2'
     end if
     if(pabbrev=='VGRD'.and.trim(labbrev_short(1:4)).eq.' 30') then
outfile=trim(out_dir)//'va_30_GEFS_'//sdy//smn//syr//'_00z_d01_d35_m'//ens_mem(4:5)//'.grb2'
     end if
     if(pabbrev=='VGRD'.and.trim(labbrev_short(1:4)).eq.' 50') then
outfile=trim(out_dir)//'va_50_GEFS_'//sdy//smn//syr//'_00z_d01_d35_m'//ens_mem(4:5)//'.grb2'
     end if
     if(pabbrev=='HGT'.and.trim(labbrev_short(1:4)).eq.' 10') then
outfile=trim(out_dir)//'zg_10_GEFS_'//sdy//smn//syr//'_00z_d01_d35_m'//ens_mem(4:5)//'.grb2'
     end if
     if(pabbrev=='HGT'.and.trim(labbrev_short(1:4)).eq.' 30') then
outfile=trim(out_dir)//'zg_30_GEFS_'//sdy//smn//syr//'_00z_d01_d35_m'//ens_mem(4:5)//'.grb2'
     end if
     if(pabbrev=='HGT'.and.trim(labbrev_short(1:4)).eq.' 50') then
outfile=trim(out_dir)//'zg_50_GEFS_'//sdy//smn//syr//'_00z_d01_d35_m'//ens_mem(4:5)//'.grb2'
     end if
     if(pabbrev=='TMP'.and.trim(labbrev_short(1:4)).eq.' 10') then
outfile=trim(out_dir)//'ta_10_GEFS_'//sdy//smn//syr//'_00z_d01_d35_m'//ens_mem(4:5)//'.grb2'
     end if
     if(pabbrev=='TMP'.and.trim(labbrev_short(1:4)).eq.' 30') then
outfile=trim(out_dir)//'ta_30_GEFS_'//sdy//smn//syr//'_00z_d01_d35_m'//ens_mem(4:5)//'.grb2'
     end if
     if(pabbrev=='TMP'.and.trim(labbrev_short(1:4)).eq.' 50') then
outfile=trim(out_dir)//'ta_50_GEFS_'//sdy//smn//syr//'_00z_d01_d35_m'//ens_mem(4:5)//'.grb2'
     end if
     if(pabbrev=='TMP'.and.trim(labbrev_short(1:4)).eq.' 100') then
outfile=trim(out_dir)//'ta_100_GEFS_'//sdy//smn//syr//'_00z_d01_d35_m'//ens_mem(4:5)//'.grb2'
     end if
     if(pabbrev=='HGT'.and.trim(labbrev_short(1:4)).eq.' 850') then
outfile=trim(out_dir)//'zg_850_GEFS_'//sdy//smn//syr//'_00z_d01_d35_m'//ens_mem(4:5)//'.grb2'
     end if

     print *,outfile
     call baopenwa(200,outfile,iret) ! for add more than 1 members

     if(.not. allocated(var_save_daily)) allocate(var_save_daily(maxgrd,35))
     gfldo%fld=-999999.

!calculate the daily ave/acc
     do ind=1,35   !35 day forecast
      icount=icount+1

!daily avaerage 00z,06z,12z,18z
      if(pabbrev=='HGT'.or.pabbrev=='UGRD'.or.pabbrev=='VGRD'.or.pabbrev=='TMP') then
        var_save_daily(:,ind)=(var_save(:,1+(ind-1)*4)+var_save(:,2+(ind-1)*4)+var_save(:,3+(ind-1)*4)+var_save(:,ind*4))/4.         
      end if
!reasign gfldo%fld as daily
     gfldo%fld=var_save_daily(:,ind)

!reassign the ipdtmpl
     gfldo%ipdtmpl(17)=ens_id !!!! ensemble member: iens=0 ->CTL
     gfldo%ipdtmpl(9)=ind !forecast time
     gfldo%ipdtmpl(8)=2   !change hours to day (time unit)
!change template from 4.11 to 4.1
     if (jpdtn == 11 )then
        gfldo%ipdtnum=1
     end if
     call putgb2(200,gfldo,jret)
!     call printinfr(gfldo,icount)

    end do !ind
    call gf_free(gfldo)
    write(*,'(1i5,a10,a20,6f15.2)') ivar,pabbrev,trim(labbrev),var_save(100,1:5),var_save_daily(100,1)

deallocate(var_save)
deallocate(var_save_daily)
end do !ivar

end program daily_ave_acc

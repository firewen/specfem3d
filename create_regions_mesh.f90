!=====================================================================
!
!          S p e c f e m 3 D  B a s i n  V e r s i o n  1 . 1
!          --------------------------------------------------
!
!                 Dimitri Komatitsch and Jeroen Tromp
!    Seismological Laboratory - California Institute of Technology
!         (c) California Institute of Technology October 2002
!
!    A signed non-commercial agreement is required to use this program.
!   Please check http://www.gps.caltech.edu/research/jtromp for details.
!           Free for non-commercial academic research ONLY.
!      This program is distributed WITHOUT ANY WARRANTY whatsoever.
!      Do not redistribute this program without written permission.
!
!=====================================================================

  subroutine create_regions_mesh(xgrid,ygrid,zgrid,ibool,idoubling, &
           xstore,ystore,zstore,npx,npy,iproc_xi,iproc_eta,nspec, &
           volume_local,area_local_bottom,area_local_top, &
           NGLOB_AB,npointot, &
           NER_BOTTOM_MOHO,NER_MOHO_16,NER_16_BASEMENT,NER_BASEMENT_SEDIM,NER_SEDIM,NER, &
           NEX_PER_PROC_XI,NEX_PER_PROC_ETA, &
           NSPEC2DMAX_XMIN_XMAX,NSPEC2DMAX_YMIN_YMAX,NSPEC2D_BOTTOM,NSPEC2D_TOP, &
           HARVARD_3D_GOCAD_MODEL,NPROC_XI,NPROC_ETA,NSPEC2D_A_XI,NSPEC2D_B_XI, &
           NSPEC2D_A_ETA,NSPEC2D_B_ETA, &
           myrank,LOCAL_PATH,UTM_X_MIN,UTM_X_MAX,UTM_Y_MIN,UTM_Y_MAX,Z_DEPTH_BLOCK,UTM_PROJECTION_ZONE, &
           HAUKSSON_REGIONAL_MODEL,OCEANS, &
           VP_MIN_GOCAD,VP_VS_RATIO_GOCAD_TOP,VP_VS_RATIO_GOCAD_BOTTOM, &
           IMPOSE_MINIMUM_VP_GOCAD,THICKNESS_TAPER_BLOCKS,MOHO_MAP_LUPEI)

! create the different regions of the mesh

  implicit none

  include "constants.h"

! number of spectral elements in each block
  integer nspec

  integer NEX_PER_PROC_XI,NEX_PER_PROC_ETA,UTM_PROJECTION_ZONE
  integer NER_BOTTOM_MOHO,NER_MOHO_16,NER_16_BASEMENT,NER_BASEMENT_SEDIM,NER_SEDIM,NER

  integer NSPEC2DMAX_XMIN_XMAX,NSPEC2DMAX_YMIN_YMAX,NSPEC2D_BOTTOM,NSPEC2D_TOP

  integer NPROC_XI,NPROC_ETA,NSPEC2D_A_XI,NSPEC2D_B_XI
  integer NSPEC2D_A_ETA,NSPEC2D_B_ETA

  integer npx,npy
  integer npointot

  logical HARVARD_3D_GOCAD_MODEL,HAUKSSON_REGIONAL_MODEL
  logical OCEANS,IMPOSE_MINIMUM_VP_GOCAD
  logical MOHO_MAP_LUPEI

  double precision UTM_X_MIN,UTM_X_MAX,UTM_Y_MIN,UTM_Y_MAX,Z_DEPTH_BLOCK
  double precision VP_MIN_GOCAD,VP_VS_RATIO_GOCAD_TOP,VP_VS_RATIO_GOCAD_BOTTOM
  double precision horiz_size,vert_size,THICKNESS_TAPER_BLOCKS

  character(len=150) LOCAL_PATH

! arrays with the mesh
  double precision, dimension(NGLLX,NGLLY,NGLLZ,nspec) :: xstore,ystore,zstore

  double precision xstore_local(NGLLX,NGLLY,NGLLZ)
  double precision ystore_local(NGLLX,NGLLY,NGLLZ)
  double precision zstore_local(NGLLX,NGLLY,NGLLZ)

  double precision xgrid(0:2*NER,0:2*NEX_PER_PROC_XI,0:2*NEX_PER_PROC_ETA)
  double precision ygrid(0:2*NER,0:2*NEX_PER_PROC_XI,0:2*NEX_PER_PROC_ETA)
  double precision zgrid(0:2*NER,0:2*NEX_PER_PROC_XI,0:2*NEX_PER_PROC_ETA)

  double precision xmesh,ymesh,zmesh

  integer ibool(NGLLX,NGLLY,NGLLZ,nspec)

! use integer array to store topography values
  integer icornerlat,icornerlong
  double precision lat,long,elevation
  double precision long_corner,lat_corner,ratio_xi,ratio_eta
  integer itopo_bathy_basin(NX_TOPO,NY_TOPO)

! auxiliary variables to generate the mesh
  integer ix,iy,iz,ir,ir1,ir2,dir
  integer ix1,ix2,dix,iy1,iy2,diy
  integer iax,iay,iar
  integer isubregion,nsubregions,doubling_index

! Gauss-Lobatto-Legendre points and weights of integration
  double precision, dimension(:), allocatable :: xigll,yigll,zigll,wxgll,wygll,wzgll

! 3D shape functions and their derivatives
  double precision, dimension(:,:,:,:), allocatable :: shape3D
  double precision, dimension(:,:,:,:,:), allocatable :: dershape3D

! 2D shape functions and their derivatives
  double precision, dimension(:,:,:), allocatable :: shape2D_x,shape2D_y,shape2D_bottom,shape2D_top
  double precision, dimension(:,:,:,:), allocatable :: dershape2D_x,dershape2D_y,dershape2D_bottom,dershape2D_top

! topology of the elements
  integer iaddx(NGNOD)
  integer iaddy(NGNOD)
  integer iaddz(NGNOD)

  double precision xelm(NGNOD)
  double precision yelm(NGNOD)
  double precision zelm(NGNOD)

! parameters needed to store the radii of the grid points
! in the spherically symmetric Earth
  integer idoubling(nspec)

! for model density
  real(kind=CUSTOM_REAL), dimension(:,:,:,:), allocatable :: rhostore,kappastore,mustore

! the jacobian
  real(kind=CUSTOM_REAL) jacobianl

! boundary locator
  logical, dimension(:,:), allocatable :: iboun

! arrays with mesh parameters
  real(kind=CUSTOM_REAL), dimension(:,:,:,:), allocatable :: xixstore,xiystore,xizstore, &
    etaxstore,etaystore,etazstore,gammaxstore,gammaystore,gammazstore,jacobianstore

! mass matrix and bathymetry for ocean load
  integer ix_oceans,iy_oceans,iz_oceans,ispec_oceans
  integer ispec2D_top_crust
  integer nglob_oceans
  double precision xval,yval
  double precision height_oceans
  real(kind=CUSTOM_REAL), dimension(:), allocatable :: rmass_ocean_load

! proc numbers for MPI
  integer myrank

! check area and volume of the final mesh
  double precision weight
  double precision area_local_bottom,area_local_top
  double precision volume_local

! variables for creating array ibool (some arrays also used for AVS or DX files)
  integer, dimension(:), allocatable :: iglob,locval
  logical, dimension(:), allocatable :: ifseg
  double precision, dimension(:), allocatable :: xp,yp,zp

  integer nglob,NGLOB_AB
  integer ieoff,ilocnum

! mass matrix
  real(kind=CUSTOM_REAL), dimension(:), allocatable :: rmass

! boundary parameters locator
  integer, dimension(:), allocatable :: ibelm_xmin,ibelm_xmax,ibelm_ymin,ibelm_ymax,ibelm_bottom,ibelm_top

! 2-D jacobians and normals
  real(kind=CUSTOM_REAL), dimension(:,:,:), allocatable :: &
    jacobian2D_xmin,jacobian2D_xmax, &
    jacobian2D_ymin,jacobian2D_ymax,jacobian2D_bottom,jacobian2D_top

  real(kind=CUSTOM_REAL), dimension(:,:,:,:), allocatable :: &
    normal_xmin,normal_xmax,normal_ymin,normal_ymax,normal_bottom,normal_top

! MPI cut-planes parameters along xi and along eta
  logical, dimension(:,:), allocatable :: iMPIcut_xi,iMPIcut_eta

! name of the database file
  character(len=150) prname

! number of elements on the boundaries
  integer nspec2D_xmin,nspec2D_xmax,nspec2D_ymin,nspec2D_ymax

  integer i,j,k,ia,ispec,iglobnum,itype_element
  integer iproc_xi,iproc_eta

  double precision rho,vp,vs

! for the Harvard 3-D basin model
  double precision vp_block_gocad_MR(0:NX_GOCAD_MR-1,0:NY_GOCAD_MR-1,0:NZ_GOCAD_MR-1)
  double precision vp_block_gocad_HR(0:NX_GOCAD_HR-1,0:NY_GOCAD_HR-1,0:NZ_GOCAD_HR-1)
  integer irecord,nrecord,i_vp

! for Hauksson's model
  double precision, dimension(NLAYERS_HAUKSSON,NGRID_NEW_HAUKSSON,NGRID_NEW_HAUKSSON) :: vp_hauksson,vs_hauksson
  integer ilayer

! Stacey put back
! indices for Clayton-Engquist absorbing conditions
  integer, dimension(:,:), allocatable :: nimin,nimax,njmin,njmax,nkmin_xi,nkmin_eta
  real(kind=CUSTOM_REAL), dimension(:,:,:,:), allocatable :: rho_vp,rho_vs

! flag indicating whether point is in the sediments
  logical point_is_in_sediments
  logical, dimension(:,:,:,:), allocatable :: flag_sediments
  logical, dimension(:), allocatable :: not_fully_in_bedrock

! **************

! create the name for the database of the current slide and region
  call create_name_database(prname,myrank,LOCAL_PATH)

! Gauss-Lobatto-Legendre points of integration
  allocate(xigll(NGLLX))
  allocate(yigll(NGLLY))
  allocate(zigll(NGLLZ))

! Gauss-Lobatto-Legendre weights of integration
  allocate(wxgll(NGLLX))
  allocate(wygll(NGLLY))
  allocate(wzgll(NGLLZ))

! 3D shape functions and their derivatives
  allocate(shape3D(NGNOD,NGLLX,NGLLY,NGLLZ))
  allocate(dershape3D(NDIM,NGNOD,NGLLX,NGLLY,NGLLZ))

! 2D shape functions and their derivatives
  allocate(shape2D_x(NGNOD2D,NGLLY,NGLLZ))
  allocate(shape2D_y(NGNOD2D,NGLLX,NGLLZ))
  allocate(shape2D_bottom(NGNOD2D,NGLLX,NGLLY))
  allocate(shape2D_top(NGNOD2D,NGLLX,NGLLY))
  allocate(dershape2D_x(NDIM2D,NGNOD2D,NGLLY,NGLLZ))
  allocate(dershape2D_y(NDIM2D,NGNOD2D,NGLLX,NGLLZ))
  allocate(dershape2D_bottom(NDIM2D,NGNOD2D,NGLLX,NGLLY))
  allocate(dershape2D_top(NDIM2D,NGNOD2D,NGLLX,NGLLY))

! array with model density
  allocate(rhostore(NGLLX,NGLLY,NGLLZ,nspec))
  allocate(kappastore(NGLLX,NGLLY,NGLLZ,nspec))
  allocate(mustore(NGLLX,NGLLY,NGLLZ,nspec))

! Stacey
  allocate(rho_vp(NGLLX,NGLLY,NGLLZ,nspec))
  allocate(rho_vs(NGLLX,NGLLY,NGLLZ,nspec))

! flag indicating whether point is in the sediments
  allocate(flag_sediments(NGLLX,NGLLY,NGLLZ,nspec))
  allocate(not_fully_in_bedrock(nspec))

! boundary locator
  allocate(iboun(6,nspec))

! arrays with mesh parameters
  allocate(xixstore(NGLLX,NGLLY,NGLLZ,nspec))
  allocate(xiystore(NGLLX,NGLLY,NGLLZ,nspec))
  allocate(xizstore(NGLLX,NGLLY,NGLLZ,nspec))
  allocate(etaxstore(NGLLX,NGLLY,NGLLZ,nspec))
  allocate(etaystore(NGLLX,NGLLY,NGLLZ,nspec))
  allocate(etazstore(NGLLX,NGLLY,NGLLZ,nspec))
  allocate(gammaxstore(NGLLX,NGLLY,NGLLZ,nspec))
  allocate(gammaystore(NGLLX,NGLLY,NGLLZ,nspec))
  allocate(gammazstore(NGLLX,NGLLY,NGLLZ,nspec))
  allocate(jacobianstore(NGLLX,NGLLY,NGLLZ,nspec))

! boundary parameters locator
  allocate(ibelm_xmin(NSPEC2DMAX_XMIN_XMAX))
  allocate(ibelm_xmax(NSPEC2DMAX_XMIN_XMAX))
  allocate(ibelm_ymin(NSPEC2DMAX_YMIN_YMAX))
  allocate(ibelm_ymax(NSPEC2DMAX_YMIN_YMAX))
  allocate(ibelm_bottom(NSPEC2D_BOTTOM))
  allocate(ibelm_top(NSPEC2D_TOP))

! 2-D jacobians and normals
  allocate(jacobian2D_xmin(NGLLY,NGLLZ,NSPEC2DMAX_XMIN_XMAX))
  allocate(jacobian2D_xmax(NGLLY,NGLLZ,NSPEC2DMAX_XMIN_XMAX))
  allocate(jacobian2D_ymin(NGLLX,NGLLZ,NSPEC2DMAX_YMIN_YMAX))
  allocate(jacobian2D_ymax(NGLLX,NGLLZ,NSPEC2DMAX_YMIN_YMAX))
  allocate(jacobian2D_bottom(NGLLX,NGLLY,NSPEC2D_BOTTOM))
  allocate(jacobian2D_top(NGLLX,NGLLY,NSPEC2D_TOP))

  allocate(normal_xmin(NDIM,NGLLY,NGLLZ,NSPEC2DMAX_XMIN_XMAX))
  allocate(normal_xmax(NDIM,NGLLY,NGLLZ,NSPEC2DMAX_XMIN_XMAX))
  allocate(normal_ymin(NDIM,NGLLX,NGLLZ,NSPEC2DMAX_YMIN_YMAX))
  allocate(normal_ymax(NDIM,NGLLX,NGLLZ,NSPEC2DMAX_YMIN_YMAX))
  allocate(normal_bottom(NDIM,NGLLX,NGLLY,NSPEC2D_BOTTOM))
  allocate(normal_top(NDIM,NGLLX,NGLLY,NSPEC2D_TOP))

! Stacey put back
  allocate(nimin(2,NSPEC2DMAX_YMIN_YMAX))
  allocate(nimax(2,NSPEC2DMAX_YMIN_YMAX))
  allocate(njmin(2,NSPEC2DMAX_XMIN_XMAX))
  allocate(njmax(2,NSPEC2DMAX_XMIN_XMAX))
  allocate(nkmin_xi(2,NSPEC2DMAX_XMIN_XMAX))
  allocate(nkmin_eta(2,NSPEC2DMAX_YMIN_YMAX))

! MPI cut-planes parameters along xi and along eta
  allocate(iMPIcut_xi(2,nspec))
  allocate(iMPIcut_eta(2,nspec))

! set up coordinates of the Gauss-Lobatto-Legendre points
  call zwgljd(xigll,wxgll,NGLLX,GAUSSALPHA,GAUSSBETA)
  call zwgljd(yigll,wygll,NGLLY,GAUSSALPHA,GAUSSBETA)
  call zwgljd(zigll,wzgll,NGLLZ,GAUSSALPHA,GAUSSBETA)

! if number of points is odd, the middle abscissa is exactly zero
  if(mod(NGLLX,2) /= 0) xigll((NGLLX-1)/2+1) = ZERO
  if(mod(NGLLY,2) /= 0) yigll((NGLLY-1)/2+1) = ZERO
  if(mod(NGLLZ,2) /= 0) zigll((NGLLZ-1)/2+1) = ZERO

! get the 3-D shape functions
  call get_shape3D(myrank,shape3D,dershape3D,xigll,yigll,zigll)

! get the 2-D shape functions
  call get_shape2D(myrank,shape2D_x,dershape2D_x,yigll,zigll,NGLLY,NGLLZ)
  call get_shape2D(myrank,shape2D_y,dershape2D_y,xigll,zigll,NGLLX,NGLLZ)
  call get_shape2D(myrank,shape2D_bottom,dershape2D_bottom,xigll,yigll,NGLLX,NGLLY)
  call get_shape2D(myrank,shape2D_top,dershape2D_top,xigll,yigll,NGLLX,NGLLY)

! allocate memory for arrays
  allocate(iglob(npointot))
  allocate(locval(npointot))
  allocate(ifseg(npointot))
  allocate(xp(npointot))
  allocate(yp(npointot))
  allocate(zp(npointot))

!--- read Hauksson's model
  if(HAUKSSON_REGIONAL_MODEL) then
    open(unit=14,file='DATA/hauksson_model/hauksson_final_grid_smooth.dat',status='old')
    do iy = 1,NGRID_NEW_HAUKSSON
      do ix = 1,NGRID_NEW_HAUKSSON
        read(14,*) (vp_hauksson(ilayer,ix,iy),ilayer=1,NLAYERS_HAUKSSON), &
                   (vs_hauksson(ilayer,ix,iy),ilayer=1,NLAYERS_HAUKSSON)
      enddo
    enddo
    close(14)
    vp_hauksson(:,:,:) = vp_hauksson(:,:,:) * 1000.d0
    vs_hauksson(:,:,:) = vs_hauksson(:,:,:) * 1000.d0
  endif

!--- read the Harvard 3-D basin model
  if(HARVARD_3D_GOCAD_MODEL) then

! read medium-resolution model

! initialize array to undefined values everywhere
  vp_block_gocad_MR(:,:,:) = 20000.

! read Vp from extracted text file
  open(unit=27,file='DATA/la_3D_block_harvard/la_3D_medium_res/LA_MR_voxet_extracted.txt',status='old')
  read(27,*) nrecord
  do irecord = 1,nrecord
    read(27,*) ix,iy,iz,i_vp
    if(ix<0 .or. ix>NX_GOCAD_MR-1 .or. iy<0 .or. iy>NY_GOCAD_MR-1 .or. iz<0 .or. iz>NZ_GOCAD_MR-1) &
      stop 'wrong array index read in Gocad medium-resolution file'
    vp_block_gocad_MR(ix,iy,iz) = dble(i_vp)
  enddo
  close(27)

! read high-resolution model

! initialize array to undefined values everywhere
  vp_block_gocad_HR(:,:,:) = 20000.

! read Vp from extracted text file
  open(unit=27,file='DATA/la_3D_block_harvard/la_3D_high_res/LA_HR_voxet_extracted.txt',status='old')
  read(27,*) nrecord
  do irecord = 1,nrecord
    read(27,*) ix,iy,iz,i_vp
    if(ix<0 .or. ix>NX_GOCAD_HR-1 .or. iy<0 .or. iy>NY_GOCAD_HR-1 .or. iz<0 .or. iz>NZ_GOCAD_HR-1) &
      stop 'wrong array index read in Gocad high-resolution file'
    vp_block_gocad_HR(ix,iy,iz) = dble(i_vp)
  enddo
  close(27)

  endif

!--- apply heuristic rule to modify doubling regions to balance angles

  if(APPLY_HEURISTIC_RULE) then

! define number of subregions affected by heuristic rule in doubling regions
  nsubregions = 8

  do isubregion = 1,nsubregions

! define shape of elements for heuristic
    call define_subregions_heuristic(myrank,isubregion,iaddx,iaddy,iaddz, &
              ix1,ix2,dix,iy1,iy2,diy,ir1,ir2,dir,iax,iay,iar, &
              itype_element,npx,npy, &
              NER_BOTTOM_MOHO,NER_MOHO_16,NER_16_BASEMENT,NER_BASEMENT_SEDIM)

! loop on all the mesh points in current subregion
  do ir = ir1,ir2,dir
    do iy = iy1,iy2,diy
      do ix = ix1,ix2,dix

! this heuristic rule is only valid for 8-node elements
! it would not work in the case of 27 nodes

!----
    if(itype_element == ITYPE_UNUSUAL_1) then

! side 1
      horiz_size = xgrid(ir+iar*iaddz(2),ix+iax*iaddx(2),iy+iay*iaddy(2)) &
                 - xgrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1))
      xgrid(ir+iar*iaddz(5),ix+iax*iaddx(5),iy+iay*iaddy(5)) = &
         xgrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1)) + horiz_size * MAGIC_RATIO

      vert_size = zgrid(ir+iar*iaddz(5),ix+iax*iaddx(5),iy+iay*iaddy(5)) &
                 - zgrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1))
      zgrid(ir+iar*iaddz(5),ix+iax*iaddx(5),iy+iay*iaddy(5)) = &
         zgrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1)) + vert_size * MAGIC_RATIO / 0.50

! side 2
      horiz_size = xgrid(ir+iar*iaddz(3),ix+iax*iaddx(3),iy+iay*iaddy(3)) &
                 - xgrid(ir+iar*iaddz(4),ix+iax*iaddx(4),iy+iay*iaddy(4))
      xgrid(ir+iar*iaddz(8),ix+iax*iaddx(8),iy+iay*iaddy(8)) = &
         xgrid(ir+iar*iaddz(4),ix+iax*iaddx(4),iy+iay*iaddy(4)) + horiz_size * MAGIC_RATIO

      vert_size = zgrid(ir+iar*iaddz(8),ix+iax*iaddx(8),iy+iay*iaddy(8)) &
                 - zgrid(ir+iar*iaddz(4),ix+iax*iaddx(4),iy+iay*iaddy(4))
      zgrid(ir+iar*iaddz(8),ix+iax*iaddx(8),iy+iay*iaddy(8)) = &
         zgrid(ir+iar*iaddz(4),ix+iax*iaddx(4),iy+iay*iaddy(4)) + vert_size * MAGIC_RATIO / 0.50

!----
    else if(itype_element == ITYPE_UNUSUAL_1p) then

! side 1
      horiz_size = xgrid(ir+iar*iaddz(2),ix+iax*iaddx(2),iy+iay*iaddy(2)) &
                 - xgrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1))
      xgrid(ir+iar*iaddz(6),ix+iax*iaddx(6),iy+iay*iaddy(6)) = &
         xgrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1)) + horiz_size * (1. - MAGIC_RATIO)

      vert_size = zgrid(ir+iar*iaddz(5),ix+iax*iaddx(5),iy+iay*iaddy(5)) &
                 - zgrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1))
      zgrid(ir+iar*iaddz(6),ix+iax*iaddx(6),iy+iay*iaddy(6)) = &
         zgrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1)) + vert_size * MAGIC_RATIO / 0.50

! side 2
      horiz_size = xgrid(ir+iar*iaddz(3),ix+iax*iaddx(3),iy+iay*iaddy(3)) &
                 - xgrid(ir+iar*iaddz(4),ix+iax*iaddx(4),iy+iay*iaddy(4))
      xgrid(ir+iar*iaddz(7),ix+iax*iaddx(7),iy+iay*iaddy(7)) = &
         xgrid(ir+iar*iaddz(4),ix+iax*iaddx(4),iy+iay*iaddy(4)) + horiz_size * (1. - MAGIC_RATIO)

      vert_size = zgrid(ir+iar*iaddz(8),ix+iax*iaddx(8),iy+iay*iaddy(8)) &
                 - zgrid(ir+iar*iaddz(4),ix+iax*iaddx(4),iy+iay*iaddy(4))
      zgrid(ir+iar*iaddz(7),ix+iax*iaddx(7),iy+iay*iaddy(7)) = &
         zgrid(ir+iar*iaddz(4),ix+iax*iaddx(4),iy+iay*iaddy(4)) + vert_size * MAGIC_RATIO / 0.50

!----
    else if(itype_element == ITYPE_UNUSUAL_4) then

! side 1
      horiz_size = ygrid(ir+iar*iaddz(3),ix+iax*iaddx(3),iy+iay*iaddy(3)) &
                 - ygrid(ir+iar*iaddz(2),ix+iax*iaddx(2),iy+iay*iaddy(2))
      ygrid(ir+iar*iaddz(7),ix+iax*iaddx(7),iy+iay*iaddy(7)) = &
         ygrid(ir+iar*iaddz(2),ix+iax*iaddx(2),iy+iay*iaddy(2)) + horiz_size * (1. - MAGIC_RATIO)

      vert_size = zgrid(ir+iar*iaddz(6),ix+iax*iaddx(6),iy+iay*iaddy(6)) &
                 - zgrid(ir+iar*iaddz(2),ix+iax*iaddx(2),iy+iay*iaddy(2))
      zgrid(ir+iar*iaddz(7),ix+iax*iaddx(7),iy+iay*iaddy(7)) = &
         zgrid(ir+iar*iaddz(2),ix+iax*iaddx(2),iy+iay*iaddy(2)) + vert_size * MAGIC_RATIO / 0.50

! side 2
      horiz_size = ygrid(ir+iar*iaddz(4),ix+iax*iaddx(4),iy+iay*iaddy(4)) &
                 - ygrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1))
      ygrid(ir+iar*iaddz(8),ix+iax*iaddx(8),iy+iay*iaddy(8)) = &
         ygrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1)) + horiz_size * (1. - MAGIC_RATIO)

      vert_size = zgrid(ir+iar*iaddz(5),ix+iax*iaddx(5),iy+iay*iaddy(5)) &
                 - zgrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1))
      zgrid(ir+iar*iaddz(8),ix+iax*iaddx(8),iy+iay*iaddy(8)) = &
         zgrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1)) + vert_size * MAGIC_RATIO / 0.50

!----
    else if(itype_element == ITYPE_UNUSUAL_4p) then

! side 1
      horiz_size = ygrid(ir+iar*iaddz(3),ix+iax*iaddx(3),iy+iay*iaddy(3)) &
                 - ygrid(ir+iar*iaddz(2),ix+iax*iaddx(2),iy+iay*iaddy(2))
      ygrid(ir+iar*iaddz(6),ix+iax*iaddx(6),iy+iay*iaddy(6)) = &
         ygrid(ir+iar*iaddz(2),ix+iax*iaddx(2),iy+iay*iaddy(2)) + horiz_size * MAGIC_RATIO

      vert_size = zgrid(ir+iar*iaddz(6),ix+iax*iaddx(6),iy+iay*iaddy(6)) &
                 - zgrid(ir+iar*iaddz(2),ix+iax*iaddx(2),iy+iay*iaddy(2))
      zgrid(ir+iar*iaddz(6),ix+iax*iaddx(6),iy+iay*iaddy(6)) = &
         zgrid(ir+iar*iaddz(2),ix+iax*iaddx(2),iy+iay*iaddy(2)) + vert_size * MAGIC_RATIO / 0.50

! side 2
      horiz_size = ygrid(ir+iar*iaddz(4),ix+iax*iaddx(4),iy+iay*iaddy(4)) &
                 - ygrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1))
      ygrid(ir+iar*iaddz(5),ix+iax*iaddx(5),iy+iay*iaddy(5)) = &
         ygrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1)) + horiz_size * MAGIC_RATIO

      vert_size = zgrid(ir+iar*iaddz(5),ix+iax*iaddx(5),iy+iay*iaddy(5)) &
                 - zgrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1))
      zgrid(ir+iar*iaddz(5),ix+iax*iaddx(5),iy+iay*iaddy(5)) = &
         zgrid(ir+iar*iaddz(1),ix+iax*iaddx(1),iy+iay*iaddy(1)) + vert_size * MAGIC_RATIO / 0.50

    endif

      enddo
    enddo
  enddo

  enddo

  endif

!---

! generate the elements in all the regions of the mesh
  ispec = 0

! define number of subregions in the mesh
  if(NER_SEDIM > 1) then
    nsubregions = 30
  else
    nsubregions = 29
  endif

  do isubregion = 1,nsubregions

! define shape of elements
    call define_subregions_basin(myrank,isubregion,iaddx,iaddy,iaddz, &
              ix1,ix2,dix,iy1,iy2,diy,ir1,ir2,dir,iax,iay,iar, &
              doubling_index,npx,npy, &
              NER_BOTTOM_MOHO,NER_MOHO_16,NER_16_BASEMENT,NER_BASEMENT_SEDIM,NER_SEDIM,NER)

! loop on all the mesh points in current subregion
  do ir = ir1,ir2,dir
    do iy = iy1,iy2,diy
      do ix = ix1,ix2,dix

!       loop over the NGNOD nodes
        do ia=1,NGNOD
          xelm(ia) = xgrid(ir+iar*iaddz(ia),ix+iax*iaddx(ia),iy+iay*iaddy(ia))
          yelm(ia) = ygrid(ir+iar*iaddz(ia),ix+iax*iaddx(ia),iy+iay*iaddy(ia))
          zelm(ia) = zgrid(ir+iar*iaddz(ia),ix+iax*iaddx(ia),iy+iay*iaddy(ia))
        enddo

! add one spectral element to the list and store its material number
        ispec = ispec + 1
        if(ispec > nspec) call exit_MPI(myrank,'ispec greater than nspec in mesh creation')
        idoubling(ispec) = doubling_index

! initialize flag indicating whether element is in sediments
  not_fully_in_bedrock(ispec) = .false.

! create mesh element
  do k=1,NGLLZ
    do j=1,NGLLY
      do i=1,NGLLX

! compute mesh coordinates
       xmesh = ZERO
       ymesh = ZERO
       zmesh = ZERO
       do ia=1,NGNOD
         xmesh = xmesh + shape3D(ia,i,j,k)*xelm(ia)
         ymesh = ymesh + shape3D(ia,i,j,k)*yelm(ia)
         zmesh = zmesh + shape3D(ia,i,j,k)*zelm(ia)
       enddo
       xstore_local(i,j,k) = xmesh
       ystore_local(i,j,k) = ymesh
       zstore_local(i,j,k) = zmesh

! initialize flag indicating whether point is in the sediments
       point_is_in_sediments = .false.

! get the regional model parameters
       if(HAUKSSON_REGIONAL_MODEL) then
! get density from socal model
         call socal_model(doubling_index,zmesh,rho,vp,vs)
! get vp and vs from Hauksson
         call hauksson_model(vp_hauksson,vs_hauksson,xmesh,ymesh,zmesh,vp,vs)
! if Moho map is used, then assume homogeneous medium below the Moho
! and use bottom layer of Hauksson's model in the halfspace
         if(MOHO_MAP_LUPEI .and. doubling_index == IFLAG_HALFSPACE_MOHO) &
           call socal_model(IFLAG_HALFSPACE_MOHO,zmesh,rho,vp,vs)
       else
         call socal_model(doubling_index,zmesh,rho,vp,vs)
! include attenuation in first SoCal layer if needed
! uncomment line below to include attenuation in the 1D case
!        if(zmesh >= DEPTH_5p5km_SOCAL) point_is_in_sediments = .true.
       endif

! get the Harvard 3-D basin model
       if(HARVARD_3D_GOCAD_MODEL .and. &
            (doubling_index == IFLAG_ONE_LAYER_TOPOGRAPHY &
        .or. doubling_index == IFLAG_BASEMENT_TOPO) &
       .and. xmesh >= ORIG_X_GOCAD_MR &
       .and. xmesh <= END_X_GOCAD_MR &
       .and. ymesh >= ORIG_Y_GOCAD_MR &
       .and. ymesh <= END_Y_GOCAD_MR) then

! use medium-resolution model first
         call interpolate_gocad_block_MR(vp_block_gocad_MR, &
              xmesh,ymesh,zmesh,rho,vp,vs,point_is_in_sediments, &
              VP_MIN_GOCAD,VP_VS_RATIO_GOCAD_TOP,VP_VS_RATIO_GOCAD_BOTTOM, &
              IMPOSE_MINIMUM_VP_GOCAD,THICKNESS_TAPER_BLOCKS, &
              vp_hauksson,vs_hauksson,doubling_index,HAUKSSON_REGIONAL_MODEL)

! then superimpose high-resolution model
         if(xmesh >= ORIG_X_GOCAD_HR &
      .and. xmesh <= END_X_GOCAD_HR &
      .and. ymesh >= ORIG_Y_GOCAD_HR &
      .and. ymesh <= END_Y_GOCAD_HR) &
           call interpolate_gocad_block_HR(vp_block_gocad_HR,vp_block_gocad_MR,&
              xmesh,ymesh,zmesh,rho,vp,vs,point_is_in_sediments, &
              VP_MIN_GOCAD,VP_VS_RATIO_GOCAD_TOP,VP_VS_RATIO_GOCAD_BOTTOM, &
              IMPOSE_MINIMUM_VP_GOCAD,THICKNESS_TAPER_BLOCKS, &
              vp_hauksson,vs_hauksson,doubling_index,HAUKSSON_REGIONAL_MODEL)

    endif

! store flag indicating whether point is in the sediments
  flag_sediments(i,j,k,ispec) = point_is_in_sediments
  if(point_is_in_sediments) not_fully_in_bedrock(ispec) = .true.

! define elastic parameters in the model
! distinguish whether single or double precision for reals
       if(CUSTOM_REAL == SIZE_REAL) then
         rhostore(i,j,k,ispec) = sngl(rho)
         kappastore(i,j,k,ispec) = sngl(rho*(vp*vp - 4.d0*vs*vs/3.d0))
         mustore(i,j,k,ispec) = sngl(rho*vs*vs)

! Stacey
         rho_vp(i,j,k,ispec) = sngl(rho*vp)
         rho_vs(i,j,k,ispec) = sngl(rho*vs)
       else
         rhostore(i,j,k,ispec) = rho
         kappastore(i,j,k,ispec) = rho*(vp*vp - 4.d0*vs*vs/3.d0)
         mustore(i,j,k,ispec) = rho*vs*vs

! Stacey
         rho_vp(i,j,k,ispec) = rho*vp
         rho_vs(i,j,k,ispec) = rho*vs
       endif

     enddo
   enddo
 enddo

! detect mesh boundaries
  call get_flags_boundaries(nspec,iproc_xi,iproc_eta,ispec,doubling_index, &
        xstore_local,ystore_local,zstore_local, &
        iboun,iMPIcut_xi,iMPIcut_eta,NPROC_XI,NPROC_ETA, &
        UTM_X_MIN,UTM_X_MAX,UTM_Y_MIN,UTM_Y_MAX,Z_DEPTH_BLOCK)

! compute coordinates and jacobian
        call calc_jacobian(myrank,xixstore,xiystore,xizstore, &
               etaxstore,etaystore,etazstore, &
               gammaxstore,gammaystore,gammazstore,jacobianstore, &
               xstore,ystore,zstore, &
               xelm,yelm,zelm,shape3D,dershape3D,ispec,nspec)

! end of loop on all the mesh points in current subregion
      enddo
    enddo
  enddo

! end of loop on all the subregions of the current region the mesh
  enddo

! check total number of spectral elements created
  if(ispec /= nspec) call exit_MPI(myrank,'ispec should equal nspec')

  do ispec=1,nspec
  ieoff = NGLLCUBE*(ispec-1)
  ilocnum = 0
  do k=1,NGLLZ
    do j=1,NGLLY
      do i=1,NGLLX
        ilocnum = ilocnum + 1
        xp(ilocnum+ieoff) = xstore(i,j,k,ispec)
        yp(ilocnum+ieoff) = ystore(i,j,k,ispec)
        zp(ilocnum+ieoff) = zstore(i,j,k,ispec)
      enddo
    enddo
  enddo
  enddo

  call get_global(nspec,xp,yp,zp,iglob,locval,ifseg,nglob,npointot,UTM_X_MIN,UTM_X_MAX)

! put in classical format
  do ispec=1,nspec
  ieoff = NGLLCUBE*(ispec-1)
  ilocnum = 0
  do k=1,NGLLZ
    do j=1,NGLLY
      do i=1,NGLLX
        ilocnum = ilocnum + 1
        ibool(i,j,k,ispec) = iglob(ilocnum+ieoff)
      enddo
    enddo
  enddo
  enddo

  if(minval(ibool(:,:,:,:)) /= 1 .or. maxval(ibool(:,:,:,:)) /= NGLOB_AB) &
    call exit_MPI(myrank,'incorrect global numbering')

! creating mass matrix (will be fully assembled with MPI in the solver)
  allocate(rmass(nglob))
  rmass(:) = 0._CUSTOM_REAL

  do ispec=1,nspec
  do k=1,NGLLZ
    do j=1,NGLLY
      do i=1,NGLLX
        weight=wxgll(i)*wygll(j)*wzgll(k)
        iglobnum=ibool(i,j,k,ispec)

        jacobianl=jacobianstore(i,j,k,ispec)

! distinguish whether single or double precision for reals
    if(CUSTOM_REAL == SIZE_REAL) then
      rmass(iglobnum) = rmass(iglobnum) + &
             sngl(dble(rhostore(i,j,k,ispec)) * dble(jacobianl) * weight)
    else
      rmass(iglobnum) = rmass(iglobnum) + rhostore(i,j,k,ispec) * jacobianl * weight
    endif

      enddo
    enddo
  enddo
  enddo

  call get_jacobian_boundaries(myrank,iboun,nspec,xstore,ystore,zstore, &
      dershape2D_x,dershape2D_y,dershape2D_bottom,dershape2D_top, &
      ibelm_xmin,ibelm_xmax,ibelm_ymin,ibelm_ymax,ibelm_bottom,ibelm_top, &
      nspec2D_xmin,nspec2D_xmax,nspec2D_ymin,nspec2D_ymax, &
              jacobian2D_xmin,jacobian2D_xmax, &
              jacobian2D_ymin,jacobian2D_ymax, &
              jacobian2D_bottom,jacobian2D_top, &
              normal_xmin,normal_xmax, &
              normal_ymin,normal_ymax, &
              normal_bottom,normal_top, &
              NSPEC2D_BOTTOM,NSPEC2D_TOP, &
              NSPEC2DMAX_XMIN_XMAX,NSPEC2DMAX_YMIN_YMAX)

! create MPI buffers
! arrays locval(npointot) and ifseg(npointot) used to save memory
  call get_MPI_cutplanes_xi(myrank,prname,nspec,iMPIcut_xi,ibool, &
                  xstore,ystore,zstore,ifseg,npointot, &
                  NSPEC2D_A_ETA,NSPEC2D_B_ETA)
  call get_MPI_cutplanes_eta(myrank,prname,nspec,iMPIcut_eta,ibool, &
                  xstore,ystore,zstore,ifseg,npointot, &
                  NSPEC2D_A_XI,NSPEC2D_B_XI)

! Stacey put back
  call get_absorb(prname,iboun,nspec, &
       nimin,nimax,njmin,njmax,nkmin_xi,nkmin_eta, &
       NSPEC2DMAX_XMIN_XMAX,NSPEC2DMAX_YMIN_YMAX,NSPEC2D_BOTTOM)

! create AVS or DX mesh data for the slice, edges and faces
  if(SAVE_AVS_DX_MESH_FILES) then
    call write_AVS_DX_global_data(myrank,prname,nspec,ibool,idoubling,xstore,ystore,zstore,locval,ifseg,npointot)
    call write_AVS_DX_mesh_quality_data(prname,nspec,xstore,ystore,zstore, &
                   kappastore,mustore,rhostore)
    call write_AVS_DX_global_faces_data(myrank,prname,nspec,iMPIcut_xi,iMPIcut_eta,ibool, &
              idoubling,xstore,ystore,zstore,locval,ifseg,npointot)
    call write_AVS_DX_surface_data(myrank,prname,nspec,iboun,ibool, &
              idoubling,xstore,ystore,zstore,locval,ifseg,npointot)
  endif

! create ocean load mass matrix
  if(OCEANS) then

! adding ocean load mass matrix at the top of the crust for oceans
  nglob_oceans = nglob
  allocate(rmass_ocean_load(nglob_oceans))

! create ocean load mass matrix for degrees of freedom at ocean bottom
  rmass_ocean_load(:) = 0._CUSTOM_REAL

! add contribution of the oceans
! for surface elements exactly at the top of the crust (ocean bottom)
    do ispec2D_top_crust = 1,NSPEC2D_TOP

      ispec_oceans = ibelm_top(ispec2D_top_crust)

      iz_oceans = NGLLZ

      do ix_oceans = 1,NGLLX
        do iy_oceans = 1,NGLLY

        iglobnum=ibool(ix_oceans,iy_oceans,iz_oceans,ispec_oceans)

! compute local height of oceans

! get coordinates of current point
          xval = xstore(ix_oceans,iy_oceans,iz_oceans,ispec_oceans)
          yval = ystore(ix_oceans,iy_oceans,iz_oceans,ispec_oceans)

! project x and y in UTM back to long/lat since topo file is in long/lat
  call utm_geo(long,lat,xval,yval,UTM_PROJECTION_ZONE,IUTM2LONGLAT)

! get coordinate of corner in bathy/topo model
    icornerlong = int((long - ORIG_LONG_TOPO) / DEGREES_PER_CELL_TOPO) + 1
    icornerlat = int((lat - ORIG_LAT_TOPO) / DEGREES_PER_CELL_TOPO) + 1

! avoid edge effects and extend with identical point if outside model
    if(icornerlong < 1) icornerlong = 1
    if(icornerlong > NX_TOPO-1) icornerlong = NX_TOPO-1
    if(icornerlat < 1) icornerlat = 1
    if(icornerlat > NY_TOPO-1) icornerlat = NY_TOPO-1

! compute coordinates of corner
    long_corner = ORIG_LONG_TOPO + (icornerlong-1)*DEGREES_PER_CELL_TOPO
    lat_corner = ORIG_LAT_TOPO + (icornerlat-1)*DEGREES_PER_CELL_TOPO

! compute ratio for interpolation
    ratio_xi = (long - long_corner) / DEGREES_PER_CELL_TOPO
    ratio_eta = (lat - lat_corner) / DEGREES_PER_CELL_TOPO

! avoid edge effects
    if(ratio_xi < 0.) ratio_xi = 0.
    if(ratio_xi > 1.) ratio_xi = 1.
    if(ratio_eta < 0.) ratio_eta = 0.
    if(ratio_eta > 1.) ratio_eta = 1.

! interpolate elevation at current point
    elevation = &
      itopo_bathy_basin(icornerlong,icornerlat)*(1.-ratio_xi)*(1.-ratio_eta) + &
      itopo_bathy_basin(icornerlong+1,icornerlat)*ratio_xi*(1.-ratio_eta) + &
      itopo_bathy_basin(icornerlong+1,icornerlat+1)*ratio_xi*ratio_eta + &
      itopo_bathy_basin(icornerlong,icornerlat+1)*(1.-ratio_xi)*ratio_eta

! suppress positive elevation, which means no oceans
    if(elevation >= - MINIMUM_THICKNESS_3D_OCEANS) then
      height_oceans = 0.d0
    else
      height_oceans = dabs(elevation)
    endif

! take into account inertia of water column
        weight = wxgll(ix_oceans)*wygll(iy_oceans)*dble(jacobian2D_top(ix_oceans,iy_oceans,ispec2D_top_crust)) &
                   * dble(RHO_OCEANS) * height_oceans

! distinguish whether single or double precision for reals
        if(CUSTOM_REAL == SIZE_REAL) then
          rmass_ocean_load(iglobnum) = rmass_ocean_load(iglobnum) + sngl(weight)
        else
          rmass_ocean_load(iglobnum) = rmass_ocean_load(iglobnum) + weight
        endif

        enddo
      enddo

    enddo

! add regular mass matrix to ocean load contribution
  rmass_ocean_load(:) = rmass_ocean_load(:) + rmass(:)

  else

! allocate dummy array if no oceans
    nglob_oceans = 1
    allocate(rmass_ocean_load(nglob_oceans))

  endif

! save the binary files
  call save_arrays(flag_sediments,not_fully_in_bedrock,rho_vp,rho_vs,prname,xixstore,xiystore,xizstore, &
            etaxstore,etaystore,etazstore, &
            gammaxstore,gammaystore,gammazstore,jacobianstore, &
            xstore,ystore,zstore,kappastore,mustore, &
            ibool,idoubling,rmass,rmass_ocean_load,nglob_oceans, &
            ibelm_xmin,ibelm_xmax,ibelm_ymin,ibelm_ymax,ibelm_bottom,ibelm_top, &
            nspec2D_xmin,nspec2D_xmax,nspec2D_ymin,nspec2D_ymax, &
            normal_xmin,normal_xmax,normal_ymin,normal_ymax,normal_bottom,normal_top, &
            jacobian2D_xmin,jacobian2D_xmax, &
            jacobian2D_ymin,jacobian2D_ymax, &
            jacobian2D_bottom,jacobian2D_top, &
            iMPIcut_xi,iMPIcut_eta,nspec,nglob, &
            NSPEC2DMAX_XMIN_XMAX,NSPEC2DMAX_YMIN_YMAX,NSPEC2D_BOTTOM,NSPEC2D_TOP,OCEANS)

  do ispec=1,nspec
    do k=1,NGLLZ
      do j=1,NGLLY
        do i=1,NGLLX
          weight=wxgll(i)*wygll(j)*wzgll(k)
          jacobianl=jacobianstore(i,j,k,ispec)
          volume_local = volume_local + dble(jacobianl)*weight
        enddo
      enddo
    enddo
  enddo

  do ispec = 1,NSPEC2D_BOTTOM
    do i=1,NGLLX
      do j=1,NGLLY
        weight=wxgll(i)*wygll(j)
        area_local_bottom = area_local_bottom + dble(jacobian2D_bottom(i,j,ispec))*weight
      enddo
    enddo
  enddo

  do ispec = 1,NSPEC2D_TOP
    do i=1,NGLLX
      do j=1,NGLLY
        weight=wxgll(i)*wygll(j)
        area_local_top = area_local_top + dble(jacobian2D_top(i,j,ispec))*weight
      enddo
    enddo
  enddo

  end subroutine create_regions_mesh

!-------------------------------------------------------------------------------
! set up the mask for the sponge term
!-------------------------------------------------------------------------------
subroutine sponge_mask(time, mask_sponge)
  use vars
  use hdf5_wrapper
  implicit none
  real(kind=pr), intent (in) :: time
  real(kind=pr),dimension(0:nx-1,0:ny-1), intent(inout) :: mask_sponge
  real(kind=pr) :: R
  integer :: ix, iy
  logical, save :: first_call = .true.

  if (use_sponge == 0) return
  if (first_call .eqv. .false.) return

  mask_sponge = 0.d0

  select case (iSpongeType)
  case ('from_file')
    call read_flusi_hdf5_2d_openmp( infile_sponge, mask_sponge )
    ! if the maximum value of the mask is not 1.d0, then we have saved mask/eps
    ! in the previous simulation.
    if (maxval(mask_sponge) > 1.d0) then
      write(*,*) "The sponge mask we read does not appear to be normalized.."
      write(*,*) "Previous eps_sponge=", 1.d0/maxval(mask_sponge)
      ! re-normalize to unity
      mask_sponge = mask_sponge / maxval(mask_sponge)
    endif
  case ('everywhere')
    mask_sponge = 1.d0
  case('none')
    mask_sponge = 0.d0
  case default
    write (*,*) "mask not defnd", iSpongeType
    stop
  end select

  first_call = .false.

end subroutine sponge_mask

!-------------------------------------------------------------------------------
! Add the sponge term to the non-linear terms in fourier space
!-------------------------------------------------------------------------------
subroutine add_sponge_term(time, nlk, vor, mask_sponge, work1, work2)
  use vars
  implicit none
  real(kind=pr),intent(in) :: time
  real(kind=pr),dimension(0:nx-1,0:ny-1,1:2),intent(inout) :: nlk
  real(kind=pr),dimension(0:nx-1,0:ny-1),intent(inout) :: vor, mask_sponge, work1, work2

  real(kind=pr),dimension(:,:,:), allocatable :: sp_tmp
  integer :: iy

  if (use_sponge == 1) then
    ! allocate temporary array
    allocate( sp_tmp(0:nx-1, 0:ny-1,1:2) )

    ! apply sponge penalization to vorticity
    !$omp parallel do private(iy)
    do iy=0,ny-1
      work1(:,iy) = -mask_sponge(:,iy)*vor(:,iy)/eps_sponge
    enddo
    !$omp end parallel do

    call fft(work1,work2)

    ! obtain the velocity
    call vorticity2velocity( work2, sp_tmp )
    ! add sponge term to NL terms (in F-space)
    nlk = nlk + sp_tmp

    deallocate(sp_tmp)
  endif

end subroutine

!> \file advec_2nd.f90
!!  Does advection with a 2nd order central differencing scheme.
!! \par Revision list
!! \par Authors
!! Second order central differencing can be used for variables where neither very
!! high accuracy nor strict monotonicity is necessary.
!! \latexonly
!!\begin{eqnarray}
!! F_{i-\frac{1}{2}}^{2nd} &=&
!!\fav{u}_{i-\frac{1}{2}}\frac{\phi_{i}+\phi_{i-1}}{2},
!!\end{eqnarray}
!! \endlatexonly
!!
!  This file is part of DALES.
!
! DALES is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 3 of the License, or
! (at your option) any later version.
!
! DALES is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.
!
!  Copyright 1993-2009 Delft University of Technology, Wageningen University, Utrecht University, KNMI
!

!> Advection at cell center
subroutine advecc_2nd(putin,putout)

  use modglobal, only : i1,ih,j1,jh,k1,kmax,dxi5,dyi5,dzi5,dzf,dzh,leq
  use modfields, only : u0, v0, w0, rhobf

  !cstep IBM
  use modibm, only : lnorm_x, lnorm_y, lnorm_z, lapply_ibm
  use modibmdata,     only : lfluxform

  implicit none

  real, dimension(2-ih:i1+ih,2-jh:j1+jh,k1), intent(in)  :: putin !< Input: the cell centered field
  real, dimension(2-ih:i1+ih,2-jh:j1+jh,k1), intent(inout) :: putout !< Output: the tendency
    real, dimension(2-ih:i1+ih,2-jh:j1+jh,k1) :: tempputout !< Temporary tendency correction due to ibm bc  cstep IBM
!  real, dimension(2-ih:i1+ih,2-jh:j1+jh,k1) :: rhoputin

  integer :: i,j,k,ip,im,jp,jm,kp,km, Nsim, simid  !cstep IBM

!  do k=1,k1
!    do j=2-jh,j1+jh
!      do i=2-ih,i1+ih
!      rhoputin(i,j,k)=rhobf(k)*putin(i,j,k)
!      end do
!    end do
!  end do

  do k=1,kmax
    do j=2,j1
      do i=2,i1
        putout(i,j,k)  = putout(i,j,k)- (  &
              ( &
              u0(i+1,j,k) * ( putin(i+1,j,k) + putin(i,j,k) ) &
             -u0(i ,j,k) * ( putin(i-1,j,k) + putin(i,j,k) ) &
              )* dxi5 &
            +( &
              v0(i,j+1,k) * ( putin(i,j+1,k) + putin(i,j,k) ) &
             -v0(i,j ,k) * ( putin(i,j-1,k) + putin(i,j,k) ) &
              )* dyi5 )

      end do
    end do
  end do

  if (leq) then ! equidistant grid

    do j=2,j1
      do i=2,i1
        putout(i,j,1)  = putout(i,j,1)- (1./rhobf(1))*( &
                w0(i,j,2) * (rhobf(2) * putin(i,j,2) + rhobf(1) * putin(i,j,1) ) &
                ) * dzi5
      end do
    end do

    do j=2,j1
    do k=2,kmax         
       do i=2,i1
          putout(i,j,k)  = putout(i,j,k)- (1./rhobf(k))*( &
                w0(i,j,k+1) * (rhobf(k+1) * putin(i,j,k+1) + rhobf(k) * putin(i,j,k)) &
                -w0(i,j,k)   * (rhobf(k-1) * putin(i,j,k-1)+ rhobf(k) * putin(i,j,k)) &
                )*dzi5
        end do
      end do
    end do

  else   ! non-equidistant grid

    do j=2,j1
      do i=2,i1
        putout(i,j,1)  = putout(i,j,1)- (1./rhobf(1))*( &
                w0(i,j,2) * (rhobf(2) * putin(i,j,2) * dzf(1) + rhobf(1) * putin(i,j,1) * dzf(2) ) / (2.*dzh(2)) &
                ) / dzf(1)
      end do
    end do

    do j=2,j1
    do k=2,kmax
       do i=2,i1
          putout(i,j,k)  = putout(i,j,k)- (1./rhobf(k))*( &
                w0(i,j,k+1) * (rhobf(k+1) * putin(i,j,k+1) * dzf(k) + rhobf(k) * putin(i,j,k) * dzf(k+1) ) / dzh(k+1) &
               -w0(i,j,k ) * (rhobf(k-1) * putin(i,j,k-1) * dzf(k) + rhobf(k) * putin(i,j,k) * dzf(k-1) ) / dzh(k) &
                )/ (2. * dzf(k))
        end do
      end do
    end do

  end if

  ! MK: Apply immersed boundary conditions at the locations of the walls
  if (lapply_ibm .and. simid == Nsim) then
    if (lfluxform) then
      ! MK: Removal of the additional term at each point for each direction near the boundary
      tempputout(:,:,:)=0.
      do i=2,i1
        do j=2,j1
          do k=1,kmax
            if(lnorm_x(i,j,k) .or. lnorm_y(i,j,k) .or. lnorm_z(i,j,k) .or. lnorm_x(i+1,j,k) .or. lnorm_y(i,j+1,k) .or. lnorm_z(i,j,k+1)) then

              !MK: >>> Correct new advection of point (i,j,k)
			  !temprepl=-(u0(i+1,j,k)-u0(i,j,k))*dxi5*putin(i,j,k)
              tempputout(i,j,k)=tempputout(i,j,k)+( &
                (u0(i+1,j,k)-u0(i,j,k))*2*dxi5*putin(i,j,k) &
                )
              tempputout(i,j,k)=tempputout(i,j,k)+( &
                (v0(i,j+1,k)-v0(i,j,k))*2*dyi5*putin(i,j,k) &
                )
              !assume equidistant grid for walls
                tempputout(i,j,k)=tempputout(i,j,k)+( &
                  (w0(i,j,k+1)-w0(i,j,k))*2*dzi5*putin(i,j,k) &
                )
                ! non-equidistant grid
               ! write(6,*) "ERROR NON-EQUIDISTANT GRID NOT IMPLEMENTED YET"
              
            endif
          end do
        end do
      end do
    else ! Do not use fluxform and use original advection instead
    ! MK: Complete removal of flux form of advection + addition of original advection term)
      tempputout(:,:,:)=0.
      do i=2,i1
        do j=2,j1
          do k=1,kmax
            if(lnorm_x(i,j,k) .or. lnorm_y(i,j,k) .or. lnorm_z(i,j,k)) then
              !MK: >>> Complete removal of advection of point (i,j,k)
              tempputout(i,j,k)=tempputout(i,j,k)+( &
                -u0(i  ,j  ,k)*dxi5*(putin(i,j,k)+putin(i-1,j,k)) &
                +u0(i+1,j  ,k)*dxi5*(putin(i,j,k)+putin(i+1,j,k)) &
                -v0(i  ,j  ,k)*dyi5*(putin(i,j,k)+putin(i-1,j,k)) &
                +v0(i  ,j+1,k)*dyi5*(putin(i,j,k)+putin(i-1,j,k)) &
                )
               ! equidistant grid
                tempputout(i,j,k)  = tempputout(i,j,k) + (1./rhobf(k))*( &
                  -w0(i,j,k  ) * (rhobf(k-1) * putin(i,j,k-1) + rhobf(k) * putin(i,j,k)) &
                  +w0(i,j,k+1) * (rhobf(k+1) * putin(i,j,k+1) + rhobf(k) * putin(i,j,k)) &
                  )*dzi5
                 ! non-equidistant grid
               ! 'ERROR NON-EQUIDISTANT GRID NOT IMPLEMENTED YET'
                tempputout(i,j,k)  = tempputout(i,j,k) + (1./rhobf(k))*( &
                  -w0(i,j,k ) * (rhobf(k-1) * putin(i,j,k-1) * dzf(k) + rhobf(k) * putin(i,j,k) * dzf(k-1) ) / dzh(k) &
                  )/ (2. * dzf(k))
              
              !MK: >>> Correct new advection of point (i,j,k)
              tempputout(i,j,k)=tempputout(i,j,k)+( &
                -u0(i  ,j,k)*dxi5*(putin(i  ,j,k)-putin(i-1,j,k)) &
                +u0(i+1,j,k)*dxi5*(putin(i+1,j,k)-putin(i  ,j,k)) &
                )
              tempputout(i,j,k)=tempputout(i,j,k)+( &
                -v0(i,j  ,k)*dyi5*(putin(i,j  ,k)-putin(i,j-1,k)) &
                +v0(i,j+1,k)*dyi5*(putin(i,j+1,k)-putin(i,j  ,k)) &
                )
               ! equidistant grid
                tempputout(i,j,k)=tempputout(i,j,k)+( &
                  -w0(i,j,k  )*dzi5*(rhobf(k  )*putin(i,j,k  )-rhobf(k-1)*putin(i,j,k-1)) &
                  +w0(i,j,k+1)*dzi5*(rhobf(k+1)*putin(i,j,k+1)-rhobf(k  )*putin(i,j,k  )) &
                )
                 ! non-equidistant grid
               !"ERROR NON-EQUIDISTANT GRID NOT IMPLEMENTED YET"
              

              if (lnorm_x(i,j,k)) then
                !MK: >>> Complete removal of advection of point (i-1,j,k)
                tempputout(i-1,j,k)=tempputout(i-1,j,k)+( &
                  -u0(i-1,j  ,k)*dxi5*(putin(i-1,j  ,k)+putin(i-2,j  ,k)) &
                  +u0(i  ,j  ,k)*dxi5*(putin(i  ,j  ,k)+putin(i-1,j  ,k)) &
                  -v0(i-1,j  ,k)*dyi5*(putin(i-1,j  ,k)+putin(i-1,j-1,k)) &
                  +v0(i-1,j+1,k)*dyi5*(putin(i-1,j+1,k)+putin(i-1,j  ,k)) &
                  )
                ! equidistant grid
                  tempputout(i-1,j,k)  = tempputout(i-1,j,k) + (1./rhobf(k))*( &
                    -w0(i-1,j,k  ) * (rhobf(k-1) * putin(i-1,j,k-1) + rhobf(k) * putin(i-1,j,k)) &
                    +w0(i-1,j,k+1) * (rhobf(k+1) * putin(i-1,j,k+1) + rhobf(k) * putin(i-1,j,k)) &
                    )*dzi5
                  ! non-equidistant grid
               ! 'ERROR NON-EQUIDISTANT GRID NOT IMPLEMENTED YET'
                  tempputout(i,j,k-1)  = tempputout(i,j,k-1) + (1./rhobf(k-1))*( &
                    w0(i,j,k) * (rhobf(k) * putin(i,j,k) * dzf(k-1) + rhobf(k-1) * putin(i,j,k-1) * dzf(k-1) ) / dzh(k) &
                    )/ (2. * dzf(k))
                
                !MK: >>> Correct new advection
                tempputout(i-1,j,k)=tempputout(i-1,j,k)+( &
                  -u0(i-1,j,k)*dxi5*(putin(i-1,j,k)-putin(i-2,j,k)) &
                  +u0(i  ,j,k)*dxi5*(putin(i  ,j,k)-putin(i-1,j,k)) &
                  )
                tempputout(i-1,j,k)=tempputout(i-1,j,k)+( &
                  -v0(i-1,j  ,k)*dyi5*(putin(i-1,j  ,k)-putin(i-1,j-1,k)) &
                  +v0(i-1,j+1,k)*dyi5*(putin(i-1,j+1,k)-putin(i-1,j  ,k)) &
                  )
                 ! equidistant grid
                  tempputout(i-1,j,k)=tempputout(i-1,j,k)+( &
                    -w0(i-1,j,k  )*dzi5*(rhobf(k  )*putin(i-1,j,k  )-rhobf(k-1)*putin(i-1,j,k-1)) &
                    +w0(i-1,j,k+1)*dzi5*(rhobf(k+1)*putin(i-1,j,k+1)-rhobf(k  )*putin(i-1,j,k  )) &
                  )
                   ! non-equidistant grid
                ! "ERROR NON-EQUIDISTANT GRID NOT IMPLEMENTED YET"
                
              endif
              if (lnorm_y(i,j,k)) then
                !MK: >>> Complete removal of advection of point (i,j-1,k)
                tempputout(i,j-1,k)=tempputout(i,j-1,k)+( &
                  -u0(i  ,j-1,k)*dxi5*(putin(i  ,j-1,k)+putin(i-1,j-1,k)) &
                  +u0(i+1,j-1,k)*dxi5*(putin(i+1,j-1,k)+putin(i  ,j-1,k)) &
                  -v0(i  ,j-1,k)*dyi5*(putin(i  ,j-1,k)+putin(i  ,j-2,k)) &
                  +v0(i  ,j  ,k)*dyi5*(putin(i  ,j  ,k)+putin(i  ,j-1,k)) &
                  )
                 ! equidistant grid
                  tempputout(i,j-1,k)  = tempputout(i,j-1,k) + (1./rhobf(k))*( &
                    -w0(i,j-1,k  ) * (rhobf(k-1) * putin(i,j-1,k-1) + rhobf(k) * putin(i,j-1,k)) &
                    +w0(i,j-1,k+1) * (rhobf(k+1) * putin(i,j-1,k+1) + rhobf(k) * putin(i,j-1,k)) &
                    )*dzi5
                   ! non-equidistant grid
                ! 'ERROR NON-EQUIDISTANT GRID NOT IMPLEMENTED YET'
                  tempputout(i,j,k-1)  = tempputout(i,j,k-1) + (1./rhobf(k-1))*( &
                    w0(i,j,k) * (rhobf(k) * putin(i,j,k) * dzf(k-1) + rhobf(k-1) * putin(i,j,k-1) * dzf(k-1) ) / dzh(k) &
                    )/ (2. * dzf(k))
                
                !MK: >>> Correct new advection
                tempputout(i,j-1,k)=tempputout(i,j-1,k)+( &
                  -u0(i  ,j-1,k)*dxi5*(putin(i  ,j-1,k)-putin(i-1,j-1,k)) &
                  +u0(i+1,j-1,k)*dxi5*(putin(i+1,j-1,k)-putin(i  ,j-1,k)) &
                  )
                tempputout(i,j-1,k)=tempputout(i,j-1,k)+( &
                  -v0(i,j-1,k)*dyi5*(putin(i,j-1,k)-putin(i,j-2,k)) &
                  +v0(i,j  ,k)*dyi5*(putin(i,j  ,k)-putin(i,j-1,k)) &
                  )
                 ! equidistant grid
                  tempputout(i,j-1,k)=tempputout(i,j-1,k)+( &
                    -w0(i,j-1,k  )*dzi5*(rhobf(k  )*putin(i,j-1,k  )-rhobf(k-1)*putin(i,j-1,k-1)) &
                    +w0(i,j-1,k+1)*dzi5*(rhobf(k+1)*putin(i,j-1,k+1)-rhobf(k  )*putin(i,j-1,k  )) &
                  )
                  ! non-equidistant grid
                ! "ERROR NON-EQUIDISTANT GRID NOT IMPLEMENTED YET"
                
              endif
              if (lnorm_z(i,j,k)) then
                !MK: >>> Complete removal of advection of point (i,j,k-1)
                tempputout(i,j,k-1)=tempputout(i,j,k-1)+( &
                  -u0(i  ,j  ,k-1)*dxi5*(putin(i  ,j  ,k-1)+putin(i-1,j  ,k-1)) &
                  +u0(i+1,j  ,k-1)*dxi5*(putin(i+1,j  ,k-1)+putin(i  ,j  ,k-1)) &
                  -v0(i  ,j  ,k-1)*dyi5*(putin(i  ,j  ,k-1)+putin(i  ,j-1,k-1)) &
                  +v0(i  ,j+1,k-1)*dyi5*(putin(i  ,j+1,k-1)+putin(i  ,j  ,k-1)) &
                  )
                 ! equidistant grid
                  tempputout(i,j,k-1)  = tempputout(i,j,k-1) + (1./rhobf(k-1))*( &
                    -w0(i,j,k-1) * (rhobf(k-2) * putin(i,j,k-2) + rhobf(k-1) * putin(i,j,k-1)) &
                    +w0(i,j,k  ) * (rhobf(k  ) * putin(i,j,k  ) + rhobf(k-1) * putin(i,j,k-1)) &
                    )*dzi5
                   ! non-equidistant grid
                 !'ERROR NON-EQUIDISTANT GRID NOT IMPLEMENTED YET'
                  tempputout(i,j,k-1)  = tempputout(i,j,k-1) + (1./rhobf(k-1))*( &
                    w0(i,j,k) * (rhobf(k) * putin(i,j,k) * dzf(k-1) + rhobf(k-1) * putin(i,j,k-1) * dzf(k-1) ) / dzh(k) &
                    )/ (2. * dzf(k))
                
                !MK: >>> Correct new advection
                tempputout(i,j,k-1)=tempputout(i,j,k-1)+( &
                  -u0(i  ,j,k-1)*dxi5*(putin(i  ,j,k-1)-putin(i-1,j,k-1)) &
                  +u0(i+1,j,k-1)*dxi5*(putin(i+1,j,k-1)-putin(i  ,j,k-1)) &
                  )
                tempputout(i,j,k-1)=tempputout(i,j,k-1)+( &
                  -v0(i,j  ,k-1)*dyi5*(putin(i,j  ,k-1)-putin(i,j-1,k-1)) &
                  +v0(i,j+1,k-1)*dyi5*(putin(i,j+1,k-1)-putin(i,j  ,k-1)) &
                  )
                 ! equidistant grid
                  tempputout(i,j,k-1)=tempputout(i,j,k-1)+( &
                    -w0(i,j,k-1)*dzi5*(rhobf(k-1)*putin(i,j,k-1)-rhobf(k-2)*putin(i,j,k-2)) &
                    +w0(i,j,k  )*dzi5*(rhobf(k  )*putin(i,j,k  )-rhobf(k-1)*putin(i,j,k-1)) &
                  )
                  ! non-equidistant grid
                ! "ERROR NON-EQUIDISTANT GRID NOT IMPLEMENTED YET"
                
              endif
            endif
          end do
        end do
      end do
    endif ! end of lfluxform statement (calculation of correction)
    !Apply correction step
    do i=2,i1
      do j=2,j1
        do k=1,kmax
          if(putin(i,j,k) == 0.) then
            putout(i,j,k)=0.
          else
            putout(i,j,k)=putout(i,j,k)+tempputout(i,j,k)
          endif
        end do
      end do
    end do
  endif


end subroutine advecc_2nd


!> Advection at the u point.
subroutine advecu_2nd(putin, putout)

  use modglobal, only : i1,ih,j1,jh,k1,kmax,dxiq,dyiq,dziq,dzf,dzh,leq
  use modfields, only : u0, v0, w0, rhobf
  implicit none

  real, dimension(2-ih:i1+ih,2-jh:j1+jh,k1), intent(in) :: putin
  real, dimension(2-ih:i1+ih,2-jh:j1+jh,k1), intent(inout) :: putout
!  real, dimension(2-ih:i1+ih,2-jh:j1+jh,k1) :: rhoputin

  integer :: i,j,k,ip,im,jp,jm,kp,km

!  do k=1,k1
!    do j=2-jh,j1+jh
!      do i=2-ih,i1+ih
!      rhoputin(i,j,k)=rhobf(k)*putin(i,j,k)
!      end do
!    end do
!  end do

  do k=1,kmax
  km=k-1
  kp=k+1
    do j=2,j1
    jm=j-1
    jp=j+1
      do i=2,i1
      im=i-1
      ip=i+1
        putout(i,j,k)  = putout(i,j,k)- ( &
                ( &
                (putin(i,j,k)+putin(ip,j,k))*(u0(i,j,k)+u0(ip,j,k)) &
                -(putin(i,j,k)+putin(im,j,k))*(u0(i,j,k)+u0(im,j,k)) &
                )*dxiq &
                +(  &
                (putin(i,j,k)+putin(i,jp,k))*(v0(i,jp,k)+v0(im,jp ,k)) &
                -(putin(i,j,k)+putin(i,jm,k))*(v0(i,j  ,k)+v0(im,j  ,k)) &
                )*dyiq )

      end do
    end do
  end do

  if (leq) then

    do j=2,j1
    jm=j-1
    jp=j+1
      do i=2,i1
      im=i-1
      ip=i+1
        putout(i,j,1)  = putout(i,j,1)-(1./rhobf(1))*( &
            ( rhobf(2) * putin(i,j,2) + rhobf(1) * putin(i,j,1))*( w0(i,j,2)+ w0(im,j,2) ) &
            ) *dziq
      end do
    end do

    do j=2,j1
    jm=j-1
    jp=j+1
    do k=2,kmax
       km=k-1
       kp=k+1
       do i=2,i1
          im=i-1
          ip=i+1
          putout(i,j,k)  = putout(i,j,k)- (1./rhobf(k))*( &
              (rhobf(k) * putin(i,j,k) + rhobf(kp) * putin(i,j,kp) )*(w0(i,j,kp)+w0(im,j,kp)) &
              -(rhobf(k) * putin(i,j,k) + rhobf(km) * putin(i,j,km) )*(w0(i,j,k )+w0(im,j,k )) &
                  )*dziq
        end do
      end do
    end do

  else

    do j=2,j1
    jm=j-1
    jp=j+1
      do i=2,i1
      im=i-1
      ip=i+1
        putout(i,j,1)  = putout(i,j,1)- (1./rhobf(1))*( &
              ( rhobf(2) * putin(i,j,2)*dzf(1) + rhobf(1) * putin(i,j,1)*dzf(2) ) / dzh(2) &
                *( w0(i,j,2)+ w0(im,j,2) ))/ (4.*dzf(1))
      end do
    end do

    do j=2,j1
    jm=j-1
    jp=j+1
    do k=2,kmax
       km=k-1
       kp=k+1
       do i=2,i1
          im=i-1
          ip=i+1
          putout(i,j,k)  = putout(i,j,k)- (1./rhobf(k))*( &
                ( rhobf(kp) * putin(i,j,kp)*dzf(k) + rhobf(k) * putin(i,j,k)*dzf(kp) ) / dzh(kp) &
                  *( w0(i,j,kp)+ w0(im,j,kp) ) &
               -( rhobf(k) * putin(i,j,k)*dzf(km) + rhobf(km) * putin(i,j,km)*dzf(k) ) / dzh(k) &
                  *( w0(i,j,k)  + w0(im,j,k)   ) &
                )/ (4.*dzf(k))
        end do
      end do
    end do




  end if

end subroutine advecu_2nd


!> Advection at the v point.
subroutine advecv_2nd(putin, putout)

  use modglobal, only : i1,ih,j1,jh,k1,kmax,dxiq,dyiq,dziq,dzf,dzh,leq
  use modfields, only : u0, v0, w0, rhobf
  implicit none

  real, dimension(2-ih:i1+ih,2-jh:j1+jh,k1), intent(in)  :: putin !< Input: the v-field
  real, dimension(2-ih:i1+ih,2-jh:j1+jh,k1), intent(inout) :: putout !< Output: the tendency
!  real, dimension(2-ih:i1+ih,2-jh:j1+jh,k1) :: rhoputin

  integer :: i,j,k,ip,im,jp,jm,kp,km

!  do k=1,k1
!    do j=2-jh,j1+jh
!      do i=2-ih,i1+ih
!      rhoputin(i,j,k)=rhobf(k)*putin(i,j,k)
!      end do
!    end do
!  end do

  do k=1,kmax
  km=k-1
  kp=k+1
    do j=2,j1
    jm=j-1
    jp=j+1
      do i=2,i1
      im=i-1
      ip=i+1

        putout(i,j,k)  = putout(i,j,k)- ( &
              ( &
              ( u0(ip,j,k)+u0(ip,jm,k))*(putin(i,j,k)+putin(ip,j,k)) &
              -(u0(i ,j,k)+u0(i ,jm,k))*(putin(i,j,k)+putin(im,j,k)) &
              )*dxiq &
              +( &
              ( v0(i,jp,k)+v0(i,j,k))*(putin(i,j,k)+putin(i,jp,k)) &
              -(v0(i,jm,k)+v0(i,j,k))*(putin(i,j,k)+putin(i,jm,k)) &
              )*dyiq )
      end do
    end do
  end do

  if (leq) then

    do j=2,j1
    jm=j-1
    jp=j+1
      do i=2,i1
      im=i-1
      ip=i+1
        putout(i,j,1)  = putout(i,j,1)- (1./rhobf(1))*( &
           (w0(i,j,2)+w0(i,jm,2))*(rhobf(2) * putin(i,j,2)+rhobf(1) * putin(i,j,1)) &
            )*dziq
      end do
    end do

    do j=2,j1
    jm=j-1
    jp=j+1
    do k=2,kmax
       km=k-1
       kp=k+1
       do i=2,i1
          im=i-1
          ip=i+1
          putout(i,j,k)  = putout(i,j,k)- (1./rhobf(k))*( &
                ( w0(i,j,kp)+w0(i,jm,kp))*(rhobf(kp) * putin(i,j,kp) + rhobf(k) * putin(i,j,k)) &
                -(w0(i,j,k) +w0(i,jm,k)) *(rhobf(km) * putin(i,j,km) + rhobf(k) * putin(i,j,k)) &
                )*dziq
        end do
      end do
    end do

  else
    do j=2,j1
    jm=j-1
    jp=j+1
      do i=2,i1
        im=i-1
        ip=i+1
        putout(i,j,1)  = putout(i,j,1)- (1./rhobf(1))*( &
          (w0(i,j,2)+w0(i,jm,2)) &
          *(rhobf(2) * putin(i,j,2)*dzf(1) + rhobf(1) * putin(i,j,1)*dzf(2) )/ dzh(2) &
          ) / (4. * dzf(1))
      end do
    end do

    do j=2,j1
    jm=j-1
    jp=j+1
    do k=2,kmax
       km=k-1
       kp=k+1
       do i=2,i1
          im=i-1
          ip=i+1
          putout(i,j,k)  = putout(i,j,k)- (1./rhobf(k))*( &
            (w0(i,j,kp)+w0(i,jm,kp)) &
            *(rhobf(kp) * putin(i,j,kp)*dzf(k) + rhobf(k) * putin(i,j,k)*dzf(kp) )/ dzh(kp) &
            -(w0(i,j,k)+w0(i,jm,k)) &
            *(rhobf(km) * putin(i,j,km)*dzf(k) + rhobf(k) * putin(i,j,k)*dzf(km)) / dzh(k) &
            ) / (4. * dzf(k))
        end do
      end do
    end do

  end if

end subroutine advecv_2nd



!> Advection at the w point.
subroutine advecw_2nd(putin,putout)

  use modglobal, only : i1,ih,j1,jh,k1,kmax,dxiq,dyiq,dziq,dzf,dzh,leq
  use modfields, only : u0, v0, w0, rhobh
  implicit none

  real, dimension(2-ih:i1+ih,2-jh:j1+jh,k1), intent(in)  :: putin !< Input: the w-field
  real, dimension(2-ih:i1+ih,2-jh:j1+jh,k1), intent(inout) :: putout !< Output: the tendency
!  real, dimension(2-ih:i1+ih,2-jh:j1+jh,k1) :: rhoputin

  integer :: i,j,k,ip,im,jp,jm,kp,km

!  do k=1,k1
!    do j=2-jh,j1+jh
!      do i=2-ih,i1+ih
!      rhoputin(i,j,k)=rhobh(k)*putin(i,j,k)
!      end do
!    end do
!  end do

  if (leq) then


    do k=2,kmax
    km=k-1
    kp=k+1
      do j=2,j1
      jm=j-1
      jp=j+1
        do i=2,i1
        im=i-1
        ip=i+1

          putout(i,j,k)  = putout(i,j,k)- ( &
                ( &
                (putin(ip,j,k)+putin(i,j,k))*(u0(ip,j,k)+u0(ip,j,km)) &
              -(putin(im,j,k)+putin(i,j,k))*(u0(i  ,j,k)+u0(i  ,j,km)) &
                )*dxiq &
              + &
                ( &
                (putin(i,jp,k)+putin(i,j,k))*(v0(i,jp,k)+v0(i,jp,km)) &
              -(putin(i,jm,k)+putin(i,j,k))*(v0(i,j  ,k)+v0(i,j  ,km)) &
                )*dyiq &
              + &
                (1./rhobh(k))*( &
                (rhobh(k) * putin(i,j,k) + rhobh(kp) * putin(i,j,kp) )*(w0(i,j,k) + w0(i,j,kp)) &
               -(rhobh(k) * putin(i,j,k) + rhobh(km) * putin(i,j,km) )*(w0(i,j,k) + w0(i,j,km)) &
                )*dziq &
                )

        end do
      end do
    end do
  else
    do k=2,kmax
    km=k-1
    kp=k+1
      do j=2,j1
        jm=j-1
        jp=j+1
        do i=2,i1
        im=i-1
        ip=i+1

          putout(i,j,k)  = putout(i,j,k) - (1./rhobh(k))*( &
                ( &
                ( rhobh(k) * putin(ip,j,k) + rhobh(k) * putin(i,j,k) ) &
              *( dzf(km)*u0(ip,j,k) + dzf(k)*u0(ip,j,km) ) &
              -( rhobh(k) * putin(i,j,k) + rhobh(k) * putin(im,j,k) ) &
              *( dzf(km)*u0(i,j,k)+dzf(k)*u0(i ,j,km) ) &
                )*dxiq / dzh(k) &
              + &
                ( &
                ( rhobh(k) * putin(i,jp,k) + rhobh(k) * putin(i,j,k) ) &
              *( dzf(km)*v0(i,jp,k) + dzf(k)*v0(i,jp,km) ) &
              -( rhobh(k) * putin(i,j,k) + rhobh(k) * putin(i,j-1,k) ) &
              *( dzf(km)*v0(i,j,k) + dzf(k)*v0(i,j,km) ) &
                ) *dyiq / dzh(k) &
              + &
                ( &
                ( rhobh(k) * putin(i,j,k) + rhobh(kp) * putin(i,j,kp) ) * (w0(i,j,k) + w0(i,j,kp) ) &
               -( rhobh(k) * putin(i,j,k) + rhobh(km) * putin(i,j,km) ) * (w0(i,j,k) + w0(i,j,km) ) &
                ) / (4. *dzh(k) ) &
                )

        end do
      end do
    end do

  end if


end subroutine advecw_2nd

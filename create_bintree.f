        subroutine create_bintree(a,b,q,eps,nmax,max_st,lnds_ch,
     1                     lnds_cr,lnds_idst,chnodes,len_nds)
C-----------------------------------------------------------------------------
C create a binary tree on which the initial condition u_init
c is resolved by picewise chebyshev polynomials of order q
C to precision eps
C the sequence is in ascending order of leaf_nodes.center
C
C input:
C   a and b: endpoints of the interval where everything is performed
C   q: order of chebyshev approximation
C   eps: self-explaining...
C   nmax: maximum number of leaf nodes allowed
C   max_st: maximum steps of refinement
C
C output:
C   lnds_ch: Chebyshev coefficients of each leaf node
C   lnds_cr(1): center of the node
C   lnds_cr(2): radius of the node
C   lnds_idst(1): index of the node, within all nodes of the tree
C   lnds_idst(2): status of the node, 1 for resolved, 0 for unresolved 
C   chnodes: all the chebyshev nodes on [a,b]
C   len_nds: length of the array of leaf nodes
C-----------------------------------------------------------------------------
        implicit real*8 (a-h,o-z)
        integer q,nmax,max_st,len_nds
        integer lnds_idst(2,nmax)
        real*8 a,b,eps
        real*8 lnds_ch((q+1),nmax), lnds_cr(2,nmax)
        real*8 chnodes((q+1)*nmax)

        real*8 theta(q+1)       
        integer lnds_pt
C           lnds_pt: pointer to the current tail (not void) of the lnds arrays
        integer unresv_pt
C           pointer to the current tail of the unresv arrays (not void)
        real*8 unresv_ch((q+1),nmax), unresv_cr(2,nmax),c,r
        real*8 kids_ch((q+1),2),kids_cr(2,2)
        integer unresv_idst(2,nmax),p,stat,kids_idst(2,2)
        integer i,j,k,step,l

        done=1.0d0        
        pi=4*atan(done)
C--------------------------------------------------
        lnds_pt=0
        unresv_pt=1
        do i=1,(q+1)
          unresv_ch(i,1)=0
        enddo
        unresv_idst(1,1)=0
        unresv_idst(2,1)=0
        unresv_cr(1,1)=0.5d0*(a+b)
        unresv_cr(2,1)=0.5d0*(b-a)
        step=0
C         put the root node into the unresv stack

C--------------------------------
        do while((unresv_pt .gt. 0).and.(step .lt. max_st))
C               attention: change the step constraint later!!!!
          step=step+1
C          write(*,*) 'step',step
          p=unresv_idst(1,unresv_pt)
          stat=unresv_idst(2,unresv_pt)
          c=unresv_cr(1,unresv_pt)
          r=unresv_cr(2,unresv_pt)
C               read the last element of the unresv stack
          if (stat .gt. 0) then
            lnds_pt=lnds_pt+1
C               the first element in unresv is actually resolved, put it into the lnds arrays
C               assign Chebyshev coefficients
            do i=1,(q+1)
              lnds_ch(i,lnds_pt)=unresv_ch(i,unresv_pt)
            enddo
C               assign index and status
            lnds_idst(1,lnds_pt)=unresv_idst(1,unresv_pt)
            lnds_idst(2,lnds_pt)=unresv_idst(2,unresv_pt)
C               assign center and radius
            lnds_cr(1,lnds_pt)=unresv_cr(1,unresv_pt)
            lnds_cr(2,lnds_pt)=unresv_cr(2,unresv_pt)
          endif

          unresv_pt=unresv_pt-1
C               take away the first element from the stack

          if (stat .le. 0) then
C               the first element in unresv is indeed unresolved, subdivie it
            call subdivide(p,c,r,q,eps,kids_ch,kids_cr,kids_idst)
C               put the two kids into the unresv stack, no matter they're resolved or not
C               right kid first, left kid next
            do i=2,1,-1
              unresv_pt=unresv_pt+1
              unresv_idst(1,unresv_pt)=kids_idst(1,i)
              unresv_idst(2,unresv_pt)=kids_idst(2,i)
              unresv_cr(1,unresv_pt)=kids_cr(1,i)
              unresv_cr(2,unresv_pt)=kids_cr(2,i)
              do j=1,(q+1)
                unresv_ch(j,unresv_pt)=kids_ch(j,i)
              enddo

            enddo

          endif 



c       testing output...
        write(*,*) 'unresv_pt=', unresv_pt
c       end testing output...

        enddo
C--------------------------------
C       add an output of all the chebyshev nodes in [a,b]...
        h=pi/(2*(q+1))
        do j=1,(q+1)
          theta(q+2-j)=(2*j-1)*h 
        enddo
        len_nds=lnds_pt
C         length of leaf nodes
        do i=1,len_nds
          cc=lnds_cr(1,i)
          rr=lnds_cr(2,i)
          do j=1,(q+1)
            chnodes((i-1)*(q+1)+j)=cc+rr*dcos(theta(j))
C             chebyshev nodes of first kind
          enddo
        enddo


C--------------------------------
        end subroutine



C-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.
C-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.



        subroutine subdivide(p,c,r,q,eps,kids_ch,kids_cr,kids_idst)
C-------------------------------------------------------------------------
C subdivide the current node with

C index: p, center: c, radius: r
C approx the function u_init by q-th order chebyshev poly
C to recision eps
C
C output:
C kids_ch(j,i) : j-th Chebyshev coefficients of the i-th kid
C kids_cr(1,i): center of the i-th kid
C kids_cr(2,i): radius of the i-th kid
C kids_idst(1,i): index of the i-th kid
C kids_idst(2,i): status of the i-th kid, 1 for resolved, 0 for unresolved
C-------------------------------------------------------------------------
        implicit real*8 (a-h,o-z)
        integer p,q,kids_idst(2,2),pp,dir
        real*8 c,r,eps,kids_ch(q+1,2),kids_cr(2,2)
        real*8 x(q+1),u(q+1,q+1),v(q+1,q+1),whts(q+1)
        real*8 chebnodes(q+1),f(q+1)
        real*8 cheb(q+1)
C--------------------------------------------------
c       testing vars
        real*8 l
        integer Nlevel
C--------------------------------------------------
        done=1.0d0
        pi=4*atan(done)

        call chebexps(2,q+1,x,u,v,whts)

        a=c-r
        b=c+r
        rr=r/2
c       testing------
        l=log(1.0d0/rr)/log(2.0d0)
c        write(*,*) 'l=', l
        Nlevel=ceiling(l)
        write(*,*) 'subdivide-level=', Nlevel
c       end testing------
        do i=1,2
          pp = 2*p + i;
          dir=2*i-3;
          cc = c + dir*rr;

          do j=1,(q+1)
            chebnodes(j)=cc+rr*x(j)
            call u_init(chebnodes(j),f(j))
c             call forcing(chebnodes(j),f(j))
C             test only, change back to u_init later
            cheb(j)=0
          enddo

cccccccc          call cheb_coeff(q,f,cheb)
          do k=1,q+1
            do j=1,q+1
              cheb(k)=cheb(k)+u(k,j)*f(j)
            enddo
          enddo
c.................................................
c                 to compute chebyshev coefficients,
c                 use chebexps instead!
c.................................................
           
C          compute the corresponding chebyshev coefficients
C          input: order q, function values f, output: chebyshev coefficients cheb

          do j=1,(q+1)
            kids_ch(j,i)=cheb(j)
          enddo
          kids_cr(1,i)=cc
          kids_cr(2,i)=rr
          kids_idst(1,i)=pp
          kids_idst(2,i)=0
          tail=abs(cheb(q+1))
          epsuse = eps
            if (2.ne.3) epsuse = eps/10
            write(*,*) 'epsuse',epsuse 
          if (tail .lt. epsuse) then
            kids_idst(2,i)=1
          endif
c          terminate anyway, if level>max_lv, 
c          when endpoints of interval become indistinguishable...
c          the thrashing problem can be avoided now!!!!! 
        enddo
          
        end subroutine



C-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.
C-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.



        subroutine split_bintree(lnds_cr,len_nds,rs,ind_dir,len_dir
     1                          ,ind_her,len_her)
        implicit real*8 (a-h,o-z)
        integer len_nds
        real*8 lnds_cr(2,len_nds),rs, thrs
        integer ind_dir(len_nds),ind_her(len_nds),len_dir,len_her

c         rs: radius of the supp of gaussian
c         ind_dir: local index (within all leaf nodes) of direct evaluation parts
c                  of the leaf nodes
c         ind_her: hermite part (small intervals)

        len_dir=0
        len_her=0

c        thrs=rs
        thrs=0.5*rs

        do j=1,len_nds
          if (lnds_cr(2,j) .ge. thrs) then
c           big intervals (radius>= thrs), direct evaluation
            len_dir=len_dir+1
            ind_dir(len_dir)=j
          else
c           small intervals, hermite expansion
            len_her=len_her+1
            ind_her(len_her)=j
          endif
        enddo

        
        end subroutine



C-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.
C-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.








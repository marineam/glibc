/* longjmp for ARM.
   Copyright (C) 1997-2014 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library.  If not, see
   <http://www.gnu.org/licenses/>.  */

#include <sysdep.h>
#include <stap-probe.h>
#include <bits/setjmp.h>
#include <rtld-global-offsets.h>
#include <arm-features.h>

/* __longjmp(jmpbuf, val) */

ENTRY (__longjmp)
	mov	ip, r0

#ifdef CHECK_SP
	sfi_breg ip, \
	ldr	r4, [\B]	/* jmpbuf's sp */
	cfi_undefined (r4)
#ifdef PTR_DEMANGLE
	PTR_DEMANGLE (r4, r4, a3, a4)
#endif
	CHECK_SP (r4)
#endif

#ifdef PTR_DEMANGLE
	sfi_breg ip, \
	ldr	a4, [\B], #4
	PTR_DEMANGLE (a4, a4, a3, r4)
	cfi_undefined (r4)
	sfi_breg ip, \
	ldr	r4, [\B], #4
	PTR_DEMANGLE2 (r4, r4, a3)
#else
	sfi_breg ip, \
	ldr	a4, [\B], #4
	sfi_breg ip, \
	ldr	r4, [\B], #4
	cfi_undefined (r4)
#endif
	/* longjmp probe expects longjmp first argument (4@r0), second
	   argument (-4@r1), and target address (4@r4), respectively.  */
	LIBC_PROBE (longjmp, 3, 4@r0, -4@r1, 4@r4)
	sfi_sp \
	mov	sp, a4
	mov	lr, r4
	sfi_breg ip, \
	ldmia	\B!, JMP_BUF_REGLIST
	cfi_restore (v1)
	cfi_restore (v2)
	cfi_restore (v3)
	cfi_restore (v4)
	cfi_restore (v5)
	cfi_restore (v6)
	cfi_restore (sl)
	cfi_restore (fp)
	cfi_restore (sp)
	cfi_restore (lr)

#if !defined ARM_ASSUME_NO_IWMMXT || defined __SOFTFP__
# define NEED_HWCAP 1
#endif

#ifdef NEED_HWCAP
# ifdef IS_IN_rtld
	ldr	a4, 1f
	ldr	a3, .Lrtld_local_ro
0:	add	a4, pc, a4
	add	a4, a4, a3
	ldr	a4, [a4, #RTLD_GLOBAL_RO_DL_HWCAP_OFFSET]
# else
#  ifdef SHARED
	ldr	a4, 1f
	ldr	a3, .Lrtld_global_ro
0:	add	a4, pc, a4
	ldr	a4, [a4, a3]
	ldr	a4, [a4, #RTLD_GLOBAL_RO_DL_HWCAP_OFFSET]
#  else
	ldr	a4, .Lhwcap
	ldr	a4, [a4, #0]
#  endif
# endif
#endif

#ifdef __SOFTFP__
	tst	a4, #HWCAP_ARM_VFP
	beq	.Lno_vfp
#endif

	/* Restore the VFP registers.  */
	/* Following instruction is vldmia ip!, {d8-d15}.  */
	sfi_breg r12, \
	ldc	p11, cr8, [\B], #64
.Lno_vfp:

#ifndef ARM_ASSUME_NO_IWMMXT
	tst	a4, #HWCAP_ARM_IWMMXT
	beq	.Lno_iwmmxt

	/* Restore the call-preserved iWMMXt registers.  */
	/* Following instructions are wldrd wr10, [ip], #8 (etc.)  */
	sfi_breg r12, \
	ldcl	p1, cr10, [\B], #8
	sfi_breg r12, \
	ldcl	p1, cr11, [\B], #8
	sfi_breg r12, \
	ldcl	p1, cr12, [\B], #8
	sfi_breg r12, \
	ldcl	p1, cr13, [\B], #8
	sfi_breg r12, \
	ldcl	p1, cr14, [\B], #8
	sfi_breg r12, \
	ldcl	p1, cr15, [\B], #8
.Lno_iwmmxt:
#endif

	/* longjmp_target probe expects longjmp first argument (4@r0), second
	   argument (-4@r1), and target address (4@r14), respectively.  */
	LIBC_PROBE (longjmp_target, 3, 4@r0, -4@r1, 4@r14)

	movs	r0, r1		/* get the return value in place */
	it	eq
	moveq	r0, #1		/* can't let setjmp() return zero! */

	DO_RET(lr)

#ifdef NEED_HWCAP
# ifdef IS_IN_rtld
1:	.long	_GLOBAL_OFFSET_TABLE_ - 0b - PC_OFS
.Lrtld_local_ro:
	.long	C_SYMBOL_NAME(_rtld_local_ro)(GOTOFF)
# else
#  ifdef SHARED
1:	.long	_GLOBAL_OFFSET_TABLE_ - 0b - PC_OFS
.Lrtld_global_ro:
	.long	C_SYMBOL_NAME(_rtld_global_ro)(GOT)
#  else
.Lhwcap:
	.long	C_SYMBOL_NAME(_dl_hwcap)
#  endif
# endif
#endif

END (__longjmp)

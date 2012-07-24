/*
 * Copyright (C) 2008-2012 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * JNI method invocation.  This is used to call a C/C++ JNI method.  The
 * argument list has to be pushed onto the native stack according to
 * local calling conventions.
 *
 * This version supports the PPC classic ABI.
 */

/*
 * Function prototype:
 *
 *void dvmPlatformInvoke(void* pEnv, ClassObject* clazz, int argInfo, int argc,
 *   const u4* argv, const char* signature, void* func, JValue* pReturn) 
 *
 * The method we are calling has the form:
 *
 *  return_type func(JNIEnv* pEnv, ClassObject* clazz, ...)
 *   -or-
 *  return_type func(JNIEnv* pEnv, Object* this, ...)
 *
 * We receive a collection of 32-bit values which correspond to arguments from
 * the interpreter (e.g. float occupies one, double occupies two).  It's up to
 * us to convert these into local calling conventions.
 */

/*
 * PPC  Classic ABI notes:
 *
 * r1     stack pointer. must be 16byte aligned
 * r3-r10 hold first 8 non-float args to a method (there may be padding)
 * f1-f8  hold first 8 float&double args to a method. no padding because the
 *        registers are 64bit
 *
 * r3 holds non-float returns of <= 4 bytes
 * r3-r4 hold non-float returns of 8 bytes, low word in r3.
 * f1 hold float&double returns
 * 
 * Only the arguments that don't fit in the r3-r10, f1-f8 registers are placed
 * on the stack. Stack is NOT allocated for arguments passing in registers. The
 * first overflow argument starts as offset 8 from sp.
 *
 * The "sp" must be 16-byte aligned on entry to a function, and any
 * 64-bit quantities (long long, double) must be 64-bit aligned.  This means
 * we have to scan the method signature, identify arguments that must be
 * padded, and fix them up appropriately.
 */

	.text
	.align 2

	.global dvmPlatformInvoke
	.type   dvmPlatformInvoke, @function

/*
 * On entry:
 *   r3  JNIEnv (can be left alone)
 *   r4  clazz (NULL for virtual method calls, non-NULL for static)
 *   r5  arg info
 *   r6  argc (number of 32-bit values in argv)
 *   r7  argv
 *   r8  short signature
 *   r9  func
 *   r10 pReturn
 *
 * For a virtual method call, the "this" reference is in argv[0].
 *
 * argInfo (32-bit int) layout:
 *    SRRRLLLL PPPPPPPP PPPPPPP PPPPPPPPP
 *
 *    S - if set, ignore the hints and do things the hard way (scan signature)
 *    R - return-type enumeration
 *    L - number of double words of storage required on the stack
 *    P - a 3 bit hint from PowerPCHints determining where to put the argument
 *    N - not used 
 */
dvmPlatformInvoke:
	cmpwi	r4, 0
	bne-	.Lstatic_method

	/* Not static method, load r4 with *argv++ ("this") and argc-- */
	subi	r6, r6, 1
	lwz	r4, 0(r7)
	addi	r7, r7, 4

.Lstatic_method:

	mflr	r0
	stw	r0, 4(r1)

	stwu	r1, -80(r1)	/* aligned (31-14+1)*4 + 8*/
	stmw	r14, 8(r1)

	cmpwi	r6, 0
	mr	r30, r10	/* pReturn */
	mr	r29, r9		/* func */

	rlwinm	r25, r5, 4, 28, 31 /* only return type here */
	beq	.Lmake_dummy_args	/* if no args, skip it all */

	mr	r27, r7		/* argv */
	mtctr	r6		/* argc */

	subi	r27, r27, 4		/* argv -- for easier access */

	/* Test to see if the hint has argument information for the fast
	 * path, or if we have to do the signature scan.
	 */
	cmpwi	r5, 0

	lis	r21, .Lstore_gpr_5@ha
	addi	r21, r21, .Lstore_gpr_5@l

	lis	r20, .Lstore_fprd_1@ha
	addi	r20, r20, .Lstore_fprd_1@l

	lis	r19, .Lstore_fprs_1@ha
	addi	r19, r19, .Lstore_fprs_1@l

	/* no valid arguments hint */
	blt	.Lsig_scan

	rlwinm	r16, r25, 8, 24, 31	/* stack depth */
	addi	r16, r16, 1+1		/* one dword for backtrace/LR, one for alignment */
	rlwinm	r16, r16, 3, 0, 27	/* shift and align */
	neg	r16, r16
	stwux	r1, r1, r16	/* allocate it */

	addi	r26, r1, 8-4	/* pointer for args on stack, minus 1 for easier access */

	mr	r24, r5
.Lfast_args_loop:
	rlwinm	r23, r24, 0, 29, 31
	rlwinm	r24, r24, 29, 3, 31

	/* switch table handling */
	slwi	r23, r23, 2
	addis	r23, r23, .Lfast_tab@ha
	lwz	r0, .Lfast_tab@l(r23)
	mtlr	r0
	blr

.Lfast_tab:
	.long .Lfast_float
	.long .Lfast_u4_gpr
	.long .Lfast_u8_gpr
	.long .Lfast_u8_gpr_pad
	.long .Lfast_double
	.long .Lfast_u4_stack
	.long .Lfast_u8_stack
	.long .Lfast_u8_stack_pad

.Lfast_float:
	mtlr	r19
	blrl
	bdz	.Lcopy_done
	b	.Lfast_args_loop
.Lfast_u8_gpr_pad:
	/* skip one register */
	addi	r21, r21, .Lstore_gpr_6 - .Lstore_gpr_5
.Lfast_u8_gpr:
	mtlr	r21	/* one word */
	blrl
.Lfast_u4_gpr:
	mtlr	r21	/* another word */
	blrl
	bdz	.Lcopy_done
	b	.Lfast_args_loop
.Lfast_double:
	mtlr	r20
	blrl
	bdz	.Lcopy_done
	b	.Lfast_args_loop
.Lfast_u4_stack:
	lwzu	r18, 4(r27) /* *(++argv) */
	stwu	r18, 4(r26)
	bdz	.Lcopy_done
	b	.Lfast_args_loop
.Lfast_u8_stack_pad:
	addi	r26, r26, 4
.Lfast_u8_stack:
	lwz	r18, 4(r27) /* *(argv+1) */
	lwzu	r17, 8(r27) /* *( argv += 2) */
	stw	r18, 4(r26)
	stwu	r17, 8(r26)
	bdz	.Lcopy_done
	b	.Lfast_args_loop

.Lsig_scan:
	mr	r28, r8		/* signature */
	li	r23, 5		/* next GPR, 3 and 4 are already loaded */
	li	r22, 1		/* next FPR, starting from f1 */	

	mr	r18, r28
	li	r16, 2 /* 2 words for LR and backchain */
	lbzu	r17, 1(r18)
.Lstack_count:
	cmpwi	r17, 0
	beq	.Lcount_done
	cmpwi	r17, 'D' /* double ... */
	beq	3f
	cmpwi	r17, 'J' /* or long ... */
	beq	3f	/* can take up to 3 words */
	addi	r16, r16, 1	/* rest takes 1 */
	lbzu	r17, 1(r18)
	b	.Lstack_count
3:
	addi	r16, r16, 3
	lbzu	r17, 1(r18)
	b	.Lstack_count

.Lcount_done:
	/* alloc space on stack */
	/* round up to 4 words stack align */
	addi	r16, r16, 3
	rlwinm	r16, r16, 2, 0, 27 /* shift and align */
	neg	r16, r16
	stwux	r1, r1, r16	/* allocate it */

	addi	r26, r1, 8-4	/* pointer for args on stack, minus 1 for easier access */

	addi	r28, r28, 1	/* skip rettype */
	lbz	r18, 0(r28)
	/* just to be sure */
	cmpwi	r18, 0
	beq	.Lcopy_done
.Lsig_loop:
	addi	r28, r28, 1	/* sig ++ */
	cmpwi	r18, 'D'	/* double */
	beq-	.Lstore_double

	cmpwi	r18, 'F'	/* float */
	beq-	.Lstore_float

	cmpwi	r18, 'J'
	beq-	.Lstore_long

/* .Lstore_u4: */
	cmpwi	r23, 10
	bgt	.Lstore_stack_4
	addi	r23, r23, 1
	mtlr	r21	/* one word */
	blrl
	lbz	r18, 0(r28)
	bdz	.Lcopy_done
	b	.Lsig_loop


.Lstore_double:
	cmpwi	r22, 8
	bgt	.Lstore_stack_8
	addi	r22, r22, 1
	mtlr	r20
	blrl
	lbz	r18, 0(r28)
	bdz	.Lcopy_done
	b	.Lsig_loop

.Lstore_float:
	cmpwi	r22, 8
	bgt	.Lstore_stack_4
	addi	r22, r22, 1
	mtlr	r19
	blrl
	lbz	r18, 0(r28)
	bdz	.Lcopy_done
	b	.Lsig_loop
	
.Lstore_long:
	cmpwi	r23, 9
	bgt	.Lstore_long_to_stack_8
	andi.	r0, r23, 1	/* do we need to pad a register pair */
	bne	.Lstore_long_no_reg_pad
	addi	r23, r23, 1
	addi	r21, r21, .Lstore_gpr_6 - .Lstore_gpr_5
.Lstore_long_no_reg_pad:
	addi	r23, r23, 2
	mtlr	r21	/* one word */
	blrl
	mtlr	r21	/* another word */
	blrl
	lbz	r18, 0(r28)
	bdz	.Lcopy_done
	b	.Lsig_loop

.Lstore_long_to_stack_8:
	li r23, 11 /* so no more arguments are allowed */
	/* fall through! */
.Lstore_stack_8:
	andi.	r0, r26, 4
	bne	.Lstore_stack_8_no_pad
	addi	r26, r26, 4
.Lstore_stack_8_no_pad:
	lwz	r18, 4(r27) /* *(argv+1) */
	lwzu	r17, 8(r27) /* *( argv += 2) */
	stw	r18, 4(r26)
	stwu	r17, 8(r26)

	lbz	r18, 0(r28)
	bdz	.Lcopy_done
	b	.Lsig_loop

.Lstore_stack_4:
	lwzu	r18, 4(r27) /* *(++argv) */
	stwu	r18, 4(r26)

	lbz	r18, 0(r28)
	bdz	.Lcopy_done
	b	.Lsig_loop

.Lmake_dummy_args:
	stwu	r1, -16(r1) /* make dummy frame for empty argset */

.Lcopy_done:
	mtlr	r29
	blrl

	/* Back, results are in r3, or if longlong in r3-r4, or if
	 * float/double in f1
	 * Return type (in dalvik/vm/JniInternal.h:
	 *	0 - void
	 *	1 - float
	 *	2 - double
	 *	3 - S8
	 *	4 - S4  (anything else in our case)
	 *	5 - S2
	 * 	6 - U2
	 * 	7 - S1
	 *
	 * The ordering of the instrucitons below is due to an attempt to
	 * catch the more likely return types first.
	 */
	cmpwi	r25, 0
	beq+	.Lvoid_return
	cmpwi	r25, 2
	ble-	.Lfpr_return
	
	/* copy S8 just in case */
	stw	r3, 0(r30)
	stw	r4, 4(r30)

.Lvoid_return:
	lwz	r1, 0(r1)	/* drop the arguments stack */
	lmw	r14, 8(r1)
	addi	r1, r1, 80	/* see at .Lsig_scan */
	lwz	r0, 4(r1)
	mtlr	r0
	blr

.Lfpr_return:
	bne-	.Lfloat_return
	stfd	f1, -8(r1)
	lwz	r3, -8(r1)
	lwz	r4, -4(r1)
	stw	r3, 0(r30)
	stw	r4, 4(r30)
	b	.Lvoid_return

.Lfloat_return:
	stfs	f1, 0(r30)
	b	.Lvoid_return


#define STORE_GPR(num) \
.Lstore_gpr_ ## num: \
	lwzu	r ## num, 4(r27) /* *(++argv) */ ; \
	addi	r21, r21, .Lstore_gpr_6 - .Lstore_gpr_5 ; \
	blr

/*
 * Load a single precision floating value from memory pointed by register r27
 * into FP register # num. Increment pointer in r27
 */
#define STORE_FPRS(num) \
.Lstore_fprs_ ## num: \
	lfsu	f ## num, 4(r27) /* *(++argv)*/ ; \
	addi	r20, r20, .Lstore_fprd_2 - .Lstore_fprd_1; \
	addi	r19, r19, .Lstore_fprs_2 - .Lstore_fprs_1; \
	blr

#define STORE_FPRD(num, rT1, rT2) \
.Lstore_fprd_ ## num: \
	lwz	rT1, 4(r27) /* *(argv++) */ ; \
	lwzu	rT2, 8(r27) /* *(argv++) */ ; \
	stw	rT1, -8(r1); \
	stw	rT2, -4(r1); \
	lfd	f ## num, -8(r1); \
	addi	r20, r20, .Lstore_fprd_2 - .Lstore_fprd_1; \
	addi	r19, r19, .Lstore_fprs_2 - .Lstore_fprs_1; \
	blr

STORE_GPR(5)
STORE_GPR(6)
STORE_GPR(7)
STORE_GPR(8)
STORE_GPR(9)
STORE_GPR(10)

STORE_FPRS(1)
STORE_FPRS(2)
STORE_FPRS(3)
STORE_FPRS(4)
STORE_FPRS(5)
STORE_FPRS(6)
STORE_FPRS(7)
STORE_FPRS(8)

STORE_FPRD(1, r18, r17)
STORE_FPRD(2, r18, r17)
STORE_FPRD(3, r18, r17)
STORE_FPRD(4, r18, r17)
STORE_FPRD(5, r18, r17)
STORE_FPRD(6, r18, r17)
STORE_FPRD(7, r18, r17)
STORE_FPRD(8, r18, r17)

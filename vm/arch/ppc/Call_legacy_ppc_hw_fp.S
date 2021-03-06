/*
 * Copyright (C) 2008 The Android Open Source Project
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
 * Load a value from memory pointed by register rS into GP register # num.
 * Increment pointer in rS
 */  
#define LOAD_GPR(num, rS) \
load_gpr_ ## num: \
	lwz	r ## num, 0(rS); \
	addi	rS, rS, 4; \
	ori	r0, r0, 0; \
	blr 

/*
 * Load a single precision floating value from memory pointed by register rS
 * into FP register # num. Increment pointer in rS
 */
#define LOAD_FPRS(num, rS) \
load_fprs_ ## num: \
	lfs	f ## num, 0(rS); \
	addi	rS, rS, 4; \
	ori	r0, r0, 0; \
	blr

/*
 * Load a double precision floating value from memory pointed by register rS
 * into FP register # num. Increment pointer in rS on 8 byte
 */
#define LOAD_FPRD(num, rS) \
load_fprd_ ## num: \
	lfd	f ## num, 0(rS); \
	addi	rS, rS, 8; \
	ori	r0, r0, 0; \
	blr

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
 *      registers are 64bit
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
	.align  2

LOAD_GPR(5, r28)
LOAD_GPR(6, r28)
LOAD_GPR(7, r28)
LOAD_GPR(8, r28)
LOAD_GPR(9, r28)
LOAD_GPR(10, r28)

LOAD_FPRS(1, r28)
LOAD_FPRS(2, r28)
LOAD_FPRS(3, r28)
LOAD_FPRS(4, r28)
LOAD_FPRS(5, r28)
LOAD_FPRS(6, r28)
LOAD_FPRS(7, r28)
LOAD_FPRS(8, r28)

LOAD_FPRD(1, r28)
LOAD_FPRD(2, r28)
LOAD_FPRD(3, r28)
LOAD_FPRD(4, r28)
LOAD_FPRD(5, r28)
LOAD_FPRD(6, r28)
LOAD_FPRD(7, r28)
LOAD_FPRD(8, r28)

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
 *   0RRRNNNN NNNNNNNN LLLLLLLL LLLLLLLL
 *
 *   L - number of  words of storage required on the stack
 *   N - not used
 *
 */
dvmPlatformInvoke:
	cmpwi	cr0, r4, 0
	bne	static_method

	/* Not static method, load r4 with *argv++ ("this") and argc-- */
	subi	r6, r6, 1
	lwz	r4, 0(r7)
	addi	r7, r7, 4

static_method:
	/* Test to see if the hint has argument information for the fast
	 * path, or if we have to do the signature scan.
	 *
	 * TODO: fast path is not implemented for PPC yet. 
	 */
	b sig_scan /* no fast path w/o sig scan for now, lets go scan */

copy_done:
	mtlr	r26
	blrl

	/* Back, results are in r3, or if longlong in r3-r4, or if
	 * float/double in f1
	 * Return type (in dalvik/vm/JniInternal.h:
	 *	0 - void
	 *	1 - float
	 *	2 - double
	 *	3 - S8
	 *	4 - S4  (anything else in our case)
	 *
	 * The ordering of the instrucitons below is due to an attempt to
	 * catch the more likely return types first.
	 */
	cmpwi	cr0, r30, 0
	beq	void_return
	subi	r5, r30, 2
	cmpwi	cr0, r5, 0
	stw	r3, 0(r29)	/* Always store S4, S8 result */
	stw	r4, 4(r29)

	bgt	void_return	/* Not floats, we are done */
	subi	r5, r30, 1
	cmpwi	cr0, r5, 0
	beq	rfloat
	stfd	f1, 0(r29)
	b	void_return
rfloat:
	stfs	f1, 0(r29)

void_return:
	mr	r11, r17
	mr	r12, r31

	/* restore r17-r31 */
	lmw	r17, -60(r11)

	lwz	r0, 4(r11)
	stwux	r1, r1, r12

	mtlr	r0
	blr

	/*
	 * Slow path.
	 *
	 * The Hints function has already calculated the stack size, but we
	 * don't know if we need to stuff pad values for S8 ('J') or
	 * double ('D')data objects.
	 *
	 * So, we allocate the stack, but then have to scan the signature
	 * while moving the objects to see if any alignment is needed.
	 */
sig_scan:
	mr	r11, r1		    /* Original stack pointer */
 
	rlwinm	r12, r5, 0, 16, 31  /* get required stack size in words */

	addi	r12, r12, 4	    /* get 4 words more */
	addi	r12, r12, 2	    /* 2 words for back chain and LR */
	addi	r12, r12, 15	    /* 15 words for GPR save area */

	rlwinm	r12, r12, 0, 16, 29 /* stack must be 16-byte aligned */

	slwi	r12, r12, 2	    /* Convert to bytes of stack */
	neg	r12, r12

	stwux	r1, r1, r12	    /* allocate the stack */
	neg	r12, r12
	mflr	r0
	stw	r0, 4(r11)

	/* Save non-volatile regs r17-r31 in GPR save area */
	stmw	r17, -60(r11)

	mr	r31, r12	/* bytes of stack allocated in r31 */
	mr	r17, r11	/* original stack pointer in r17 */

	/*
	 * Get a pointer for storing the args.
	 * Parameter area follows back chain and LR
	 * save words on the stack
	 */
	addi	r12, r1, 8

	/*
	 * Get the return type; shift is sign extended
	 * but current assumption is that S bit is 
	 * never set  
	 */
	srwi	r30, r5, 28
	mr	r29, r10	/* save return buffer */

	mr	r28, r7
	mr	r27, r8
	mr	r26, r9

	/* initialize GPR and FPR counts */
	li	r25, 0
	li	r24, 0

	/* get pointers to GRP/FPR load instructions array */
	lis	r23, load_gpr_5@ha
	addi	r23, r23, load_gpr_5@l

	lis	r22, load_fprs_1@ha
	addi	r22, r22, load_fprs_1@l

	lis	r21, load_fprd_1@ha
	addi	r21, r21, load_fprd_1@l

	/*
	 * Currently:
	 *	r3	don't touch
	 *	r4	don't touch
	 *	r12	pointer for storing the args
	 * 	r17	original stack pointer
	 *	r18-r20	"working  hourses"
	 * 	r21	pointer to array of routines to store double precision
	 *	  	floating value in FPR
	 *	r22	pointer to array of routines to store single precision
	 *	   	floating value in FPR
	 * 	r23	pointer to array of routines to store non-floating
	 *	   	value in GPR. r3 and r4 are already holding needed
	 * 	   	values, so r5 thru r10 are used for non-floating
	 * 	   	arguments
	 * 	r24	counter of used up FP registers
	 * 	r25	counter of used up GP registers
	 *   	r26	method to call
	 *   	r27	short signature
	 *	r28	argv
	 *	r29	return buffer
	 *	r30	return type
	 *	r31	bytes of stack allocated
	 */

	/* Copy loop */
	addi	r27, r27, 1	/* sig[0] stores return type, skip it */ 
	lbz	r20, 0(r27)	/* Prime the pump */
sig_loop:
	cmpwi	cr0, r20, 0
	beq	copy_done

	addi	r27, r27, 1	/* sig++ */
	cmpwi	cr0, r20, 'D'	/* double */
	mr	r19, r21
	beq	store_in_fpr

	cmpwi	cr0, r20, 'F'	/* float */
	mr	r19, r22
	beq	store_in_fpr

	/* ok, dealing w/ non-float now */
	cmpwi	cr0, r20, 'J'
	mr	r19, r23
	beq	store_long

	cmpwi	cr0, r25, 6	/* all 6 GPRs exhausted ? */
	bge	store_on_stack 

store_i32:
	slwi	r18, r25, 4	
	add	r18, r19, r18
	mtlr	r18
	blrl

	lbz	r20, 0(r27)
	addi	r25, r25, 1

	/*
	 * argv++ is done by "saving a value in GPR" instructions
	 */
	b	sig_loop

store_long:
	/*
	 * if only r10 is available it holds a pad and the 64bit arg goes on
	 * stack
	 */
	cmpwi	cr0, r25, 5
	bne	skip_r10_pad
	addi	r25, r25, 1	/* pad goes in r10 */
skip_r10_pad:
	bge	store_on_stack

	andi.	r18, r25, 0x01	/* warn: an odd reg has an even index in r25 */
	beq	aligned_store
	addi	r25, r25, 1	/* pad goes in this register */
aligned_store:
	slwi	r18, r25, 4	
	add	r18, r19, r18
	mtlr	r18
	blrl

	addi	r25, r25, 1
	b	store_i32

store_in_fpr:
	cmpwi	cr0, r24, 8	/* all 8 FPRs exhausted ? */
	bge	store_on_stack 

	slwi	r18, r24, 4
	add	r19, r19, r18
	mtlr	r19
	blrl
			
	lbz	r20, 0(r27)
	addi	r24, r24, 1
	
	/*
	 * argv++ or argv +=2 is done by "saving a value in FPR" instructions
	 */
	b	sig_loop

store_on_stack:
	lwz	r18, 0(r28)	/* Get the arg */
	cmpwi	cr0, r20, 'J'	/* long long */
	beq	sig_double
	cmpwi	cr0, r20, 'D'	/* double */
	beq	sig_double
store_one:
	lbz	r20, 0(r27)	/* *sig - delay slot, but it's OK */
	stw	r18, 0(r12)	/* Put the arg on the stack */
	addi	r28, r28, 4	/* argv++ */
	addi	r12, r12, 4	/* sp++ */
	b	sig_loop

sig_double:
	andi.	r19, r12, 0x07	/* Test for 8-byte alignment */
	beq	double_align
	addi	r12, r12, 4	/* sp++ pad */
double_align:
	stw	r18, 0(r12)
	addi	r28, r28, 4	/* argv++ */
	lwz	r18, 0(r28)	/* Get the arg other half */
	addi	r12, r12, 4
	b	store_one

	.end	dvmPlatformInvoke

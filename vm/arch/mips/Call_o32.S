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
 * This version supports the old MIPS o32 ABI.
 */

#include <machine/asm.h>
#include <sys/regdef.h>


/*
Function prototype:

void dvmPlatformInvoke(void* pEnv, ClassObject* clazz, int argInfo, int argc,
    const u4* argv, const char* signature, void* func, JValue* pReturn) 

The method we are calling has the form:

  return_type func(JNIEnv* pEnv, ClassObject* clazz, ...)
    -or-
  return_type func(JNIEnv* pEnv, Object* this, ...)

We receive a collection of 32-bit values which correspond to arguments from
the interpreter (e.g. float occupies one, double occupies two).  It's up to
us to convert these into local calling conventions.
*/

/*
MIPS o32 EABI notes:

Big Endian greater than 32-bit value register pairs to memory work as expected.
Little Endian is bass ackwards, but we don't have to worry about this
for the memory transfers we are making (only when loading constants).

a0-a3 hold first 4 args to a method
s6 will save the stack size across the function call
s7 will save the return value type across the function call

v0 holds returns of <= 4 bytes
v0-v1 hold returns of 8 bytes, low word in v0 for Little Endian.

Stack is allocated even for arguments passing in registers.  That is,
16 bytes of stack is always allocated, nothing is placed there (I guess
we could for code convenience if it gains any performance).  The first
overflow argument starts as offset 16 from sp.  We store the arg2 and
arg3 to the stack as part of the processing, and load them into the
a2 and a3 registers just prior to the function call.

FP: Single precision results in f0, double in f0/f1;
    The o32 only passes arg0 and arg1 in float registers.  This makes it
    easier for us, since those are never FP values.  If arg2 is a double,
    or arg2 and arg3 are floats, they are passed in the integer registers
    just like any other arguments.  NOTE: we need a way to provide conditional
    compilation hard/soft FP build type into here for storage of return values.

The "sp" must be 64-bit aligned on entry to a function, and any
64-bit quantities (long long, double) must be 64-bit aligned.  This means
we have to scan the method signature, identify arguments that must be
padded, and fix them up appropriately.
*/

	.text
	.align  2
	.global dvmPlatformInvoke
	.type   dvmPlatformInvoke, @function
	.ent    dvmPlatformInvoke, 0
	.set	noreorder

/*
 * On entry:
 *   a0  JNIEnv (can be left alone)
 *   a1  clazz (NULL for virtual method calls, non-NULL for static)
 *   a2  arg info
 *   a3  argc (number of 32-bit values in argv)
 *   16(sp)   argv
 *   20(sp)   short signature
 *   24(sp)   func
 *   28(sp)   pReturn
 *
 * For a virtual method call, the "this" reference is in argv[0].
 *
 * argInfo (32-bit int) layout:
 *   SRRRFFFF FFFFFFFF FFFFFFFF FFZLLLLM
 *       FFFF FFFFFFFF FFFFFFFF FFZLLLL0
 *       0000 00000000 LLLLLLL LLLLLLLL1
 *
 *   M - If not set, then there are up to 24 arguments with possible padding
 *       If set, the the lower 16-bits indicate the stack size required.
 *   L - number of double-words of storage required on the stack (0-28 words)
 *   Z - always 0.  Mainly due to first arg always aligned, not worth the
 *   	 complexity of trying to pack flags.  dvmPlatformInvoke assembler
 *   	 relies on this to eliminate a masking operation.
 *   F - pad flag -- if set, write a pad word to the stack before copying
 *       the next 32 bits
 *
 * With this arrangement we can efficiently push up to 24 words of arguments
 * onto the stack.  Anything requiring more than that -- which should happen
 * rarely to never -- can do the slow signature scan.
 */
dvmPlatformInvoke:
	move	t7, sp		/* Original stack pointer */
	subu	sp, sp, 16	/* Room to save callee saved regs */
	sw	ra, 0(sp)
	sw	s6, 4(sp)
	sw	s7, 8(sp)
	bnez	a1, static_method
	lw	t6, 16(t7)	/* argv */

	/* Not static method, load a1 with *argv++ ("this") and argc--
	*/
	addiu	a3, a3, -1
	lw	a1, 0(t6)
	addiu	t6, t6, 4

static_method:
	/* Test to see if the hint has argument information for the fast
	 * path, or if we have to do the signature scan.
	 */
	andi	v0, a2, 0x0001
	andi	s6, a2, 0x1e	/* Get number of words of stack */
	sll	s6, s6, 0x2	/* Convert to bytes of stack */
	bnez	v0, sig_scan
	srl	s7, a2, 28	/* Get the return type */

	subu	sp, sp, s6	/* allocate the stack */
	move	t5, sp		/* Get a pointer for storing the args. */
	addiu	t5, t5, 8	/* Adjust for a0, a1 already on the stack */
	li	v1, 0x20	/* Pad bit test mask */

	/* Fast path.
	 * Currently:
	 *	v1	pad mask tester
	 *	a0	pEnv
	 *	a1	clazz or 'this'
	 *	a2	pad words bit mask
	 *	a3	argc
	 *	t5	destination stack pointer
	 *	t6	argv
	 *	t7	pointer to original stack
	 *	s6	bytes of stack
	 *	s7	return type
	 */

	/* Copy loop.
	*/
fast_loop:
	beqz	a3, copy_done
	srl	a2, a2, 1	/* get the "next" pad word flag */
	lw	t4, 0(t6)	/* Get the arg */
	and	v0, v1, a2	/* test if we should push a pad */
	sw	t4, 0(t5)	/* Put the arg on the stack */
	addiu	a3, a3, -1	/* argc-- */
	addiu	t6, t6, 4	/* argv++ */
	beqz	v0, fast_loop
	addiu	t5, t5, 4	/* sp++ */
	b	fast_loop
	addiu	t5, t5, 4	/* sp++  pad */

	/*
	 * Currently:
	 *	a0-a3   args (JNIEnv*, thisOrClass, arg0, arg1)
	 *	t7	pointer to original stack
	 *	s6	bytes of stack
	 *	s7	return type
	 *
	 * The stack copy is complete.  Grab the first two words off of argv
	 * and tuck them into a2/a3.  If the first arg is 32-bit and the second
	 * arg is 64-bit, then r3 "holds" a pad word and the load is unnecessary
	 * but harmless.
	 *
	 * If there are 0 or 1 arg words in argv, we will be loading
	 * uninitialized data into the registers, but since nothing tries
	 * to use it it's also harmless (assuming argv[0] and argv[1] point
	 * to valid memory, which is a reasonable assumption for Dalvik's
	 * interpreted stacks).
	 */
copy_done:
	lw	t9, 24(t7)		/* function pointer */
	lw	a2, 8(sp)
	jalr	t9
	lw	a3, 12(sp)

	/* Back, results are in v0, or if longlong/double in v0-v1
	 * Return type (in dalvik/vm/JniInternal.h:
	 *	0 - void
	 *	1 - float
	 *	2 - double
	 *	3 - S8
	 *	4 - S4  (anything else in our case)
	 *
	 * Since we are doing soft-float, we don't need to check for the
	 * float/double type yet.  These will require storing the proper
	 * fp0-fp1 registers.
	 *
	 * The ordering of the instrucitons below is due to an attempt to
	 * catch the more likely return types first.  We also want to avoid
	 * the FP stores in case we are running on a FP emulated system.
	 */
	beqz	s7, void_return
	addu	sp, sp, s6	/* Toss the method call stack */
	lw	t7, 28+16(sp)	/* Get pReturn */
	addiu	t6, s7, -2	/* No cost due to likely t7 interlock */
	sw	v0, 0(t7)	/* Always store S4, S8 result */
#if defined(__mips_hard_float)
	sw	v1, 4(t7)
	bgtz	t6, void_return	/* Not floats, we are done */
	addiu	t5, s7, -1
	beqz	t5, void_return
	swc1	$f0, 0(t7)
	swc1	$f1, 4(t7)	/* If we fall through, must be double */
#elif defined(__mips_soft_float)
	/* I did this as a way of just ensuring the compiler provided
	 * one of these two #defines.
	 */
	sw	v1, 4(t7)
#else
#error "Neither __mips_hard_float or __mips_soft_float defined"
#endif

void_return:
	lw	ra, 0(sp)
	lw	s6, 4(sp)
	lw	s7, 8(sp)
	jr	ra
	addiu	sp, sp, 16


	/*
	 * Slow path.
	 *
	 * I made an assumption here that even if we don't set the
	 * DALVIK_JNI_NO_ARG_INFO flag in the hints we will get the
	 * valid signature pointer.  The reason for this is the Hints
	 * function has already calculated the stack size, but we don't
	 * know if we need to stuff pad values for S8 ('J') or double ('D')
	 * data objects.
	 *
	 * So, we allocate the stack, but then have to scan the signature
	 * while moving the objects to see if any alignment is needed.
	 *
	 * Currently:
	 *	a0	pEnv
	 *	a1	clazz or 'this'
	 *	a2	Hints value
	 *	a3	argc
	 *	t6	argv
	 *	t7	pointer to original stack
	 *	s7	return type
	 */

sig_scan:
	xori	s6, a2, 0x1	/* Get nbr of stack words, LSBit always set */
	sll	s6, s6, 0x2	/* Convert to bytes of stack */
	subu	sp, sp, s6	/* allocate the stack */
	move	t5, sp		/* Get a pointer for storing the args. */
	addiu	t5, t5, 8	/* Adjust for a0, a1 already on the stack */
	lw	a2, 20(t7)	/* Get signature pointer */

	/* Copy loop.
	*/
	lbu	a3, 0(a2)	/* Prime the pump */
sig_loop:
	beqz	a3, copy_done
	addiu	a2, a2, 1	/* sig++ */
	lw	t4, 0(t6)	/* Get the arg */
	subu	v0, a3, 'J'	/* long long */
	beqz	v0, sig_double
	subu	v0, a3, 'D''	/* double */
	beqz	v0, sig_double
store_one:
	lbu	a3, 0(a2)	/* *sig - delay slot, but it's OK */
	sw	t4, 0(t5)	/* Put the arg on the stack */
	addiu	t6, t6, 4	/* argv++ */
	b	sig_loop
	addiu	t5, t5, 4	/* sp++ */

sig_double:
	andi	v0, t5, 0x07	/* Test for 8-byte alignment */
	beqz	v0, double_align
	nop
	addiu	t5, t5, 0x04	/* sp++ pad */
double_align:
	sw	t4, 0(t5)
	addiu	t6, t6, 4	/* argv++ */
	lw	t4, 0(t6)	/* Get the arg other half */
	b	store_one
	addiu	t5, t5, 4	/* sp++ */

	.end	dvmPlatformInvoke

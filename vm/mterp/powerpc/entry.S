/*
 * Copyright (C) 2009 The Android Open Source Project
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
 * Interpreter entry point.
 */

/*
 * To the build tools, this is the beginning of one large function.
 * This is very important so the gp we load at the start is valid
 * throughout the entire set of opcodes.  Be very careful adding any
 * kind of debug information to help gdb.  If you create a new function
 * entry point, you properly manage gp both for this function and
 * ensure it is restored for others.
 */

	.text
	.align	2
	.global	dvmMterpStdRun
	.type	dvmMterpStdRun, @function

/*
 * On entry:
 *  r3  MterpGlue* glue
 *
 * This function returns a boolean "changeInterp" value.  The return comes
 * via a call to dvmMterpStdBail().
 */
dvmMterpStdRun:

	/* Allocate stack and save registers we are using.
	 * The s4, s5, and s6 are used for local temporary saves
	 * across function calls.
	 * Also, allocate 4 stack words starting at offset zero
	 * as the argument space for C function calls with up to 4 args.
	 */
	stwu	r1, -176(r1)	/* stack frame */
	mflr	r0
	stw	r0, 180(r1)	/* save return address */
	stw	r14, 52(r1)	/* rPC */
	stw	r15, 48(r1)	/* rFP */
	stw	r16, 44(r1)	/* rGLUE */
	stw	r17, 40(r1)	/* rIBASE */
	stw	r18, 36(r1)	/* rINST */
	stw	r19, 32(r1)	/* r19 */
	stw	r20, 28(r1)	/* r20 */
	stw	r21, 24(r1)	/* r21 */
	stw	r22, 20(r1)	/* r22 */

#ifdef KEEP_CONSTANTS_IN_REGS
	stfd	f14, 64(r1)	/* f14 */
	stfd	f15, 72(r1)	/* f15 */
	stfd	f16, 80(r1)	/* f16 */
	stfd	f17, 88(r1)	/* f17 */
	stfd	f18, 96(r1)	/* f18 */
	stfd	f19, 104(r1)	/* f19 */
#endif
	/* fast access to fields */
	stw	r23, 120(r1)	/* r23 */
	stw	r24, 124(r1)	/* r24 */
	stw	r25, 128(r1)	/* r25 */
	stw	r26, 132(r1)	/* r26 */

	/* save stack pointer for later return. */
	stw	r1, offGlue_bailPtr(r3)

	/* keep various constants in registers; 
	 * since the registers are available you 
	 * might as well use them
	 */
#ifdef KEEP_CONSTANTS_IN_REGS
	lis	r4, .Lfloat_table@ha		/* r4<- start of constant table */
	addi	r4, r4, .Lfloat_table@l
#endif
#ifdef KEEP_MAX_MIN_INT_IN_REGS
	lfd	fMaxInt, 0(r4)			/* fMaxInt <- max-int in double format */
	lfd	fMinInt, 8(r4)			/* fMinInt <- min-int in double format */
#endif
#ifdef KEEP_MAX_MIN_LONG_IN_REGS
	lfd	fMaxLong, 16(r4)		/* fMaxLong <- max-long in double format */
	lfd	fMinLong, 24(r4)		/* fMinLong <- min-long in double format */
#endif
#ifdef KEEP_INT_ADJUST_IN_REG
	lfs	fIntAdj, 32(r4)			/* fIntAdj <- adjustment for OP_INT_TO_FLOAT */
#endif

	/* set up "named" registers, figure out entry point */
	mr	rGLUE, r3			/* move r3 to glue */

	lbz	r3, offGlue_entryPoint(rGLUE)	/* r3 is now InterpEntry */
	LOAD_PC_FP_FROM_GLUE()			/* setup rGLUE */
#ifdef KEEP_RES_FIELDS_IN_REGS
	lwz	rResStr, offGlue_methodClassDex(rGLUE)
	lwz	rResFld, offDvmDex_pResFields(rResStr)
	lwz	rResCls, offDvmDex_pResClasses(rResStr)
	lwz	rResStr, offDvmDex_pResStrings(rResStr)
#endif
	lis	rIBASE, dvmAsmInstructionStart@ha
	addi	rIBASE, rIBASE, dvmAsmInstructionStart@l
	cmpwi	r3, kInterpEntryInstr		/* usual case? */
	bne-	.Lnot_instr			/* no, handle it */

	/* start executing the instruction at rPC */
	FETCH_INST()
	GET_INST_OPCODE_GOTO(r0)

.Lnot_instr:
	/* were we returning from a method? */
	cmpwi	r3, kInterpEntryReturn
	bne	.Lnot_return
	b	common_returnFromMethod

.Lnot_return:
	/* were we throwing an exception? */
	cmpwi	r3, kInterpEntryThrow 
	bne	.Lbad_arg
	b	common_exceptionThrown

.Lbad_arg:
	lis	r3, .LstrBadEntryPoint@ha
	addi	r3, r3, .LstrBadEntryPoint@l
	bl	puts@plt
	b	dvmAbort@plt
	.size	dvmMterpStdRun,.-dvmMterpStdRun


/*
 * Restore the stack pointer and PC from the save point established on entry.
 * This is essentially the same as a longjmp, but should be cheaper.
 *
 * On entry:
 *  r3  MterpGlue* glue
 *  r4  bool changeInterp
 */
	.global	dvmMterpStdBail
	.type	dvmMterpStdBail, @function
dvmMterpStdBail:
	lwz	r1, offGlue_bailPtr(r3)

	lwz	r26, 132(r1)	/* r26 */
	lwz	r25, 128(r1)	/* r25 */
	lwz	r24, 124(r1)	/* r24 */
	lwz	r23, 120(r1)	/* r23 */

#ifdef KEEP_CONSTANTS_IN_REGS
	lfd	f19, 104(r1)	/* f19 */
	lfd	f18, 96(r1)	/* f18 */
	lfd	f17, 88(r1)	/* f17 */
	lfd	f16, 80(r1)	/* f16 */
	lfd	f15, 72(r1)	/* f15 */
	lfd	f14, 64(r1)	/* f14 */
#endif

	lwz	r22, 20(r1)	/* r20 */
	lwz	r21, 24(r1)	/* r21 */
	lwz	r20, 28(r1)	/* r20 */
	lwz	r19, 32(r1)	/* r19 */
	lwz	r18, 36(r1)	/* rINST */
	lwz	r17, 40(r1)	/* rIBASE */
	lwz	r16, 44(r1)	/* rGLUE */
	lwz	r15, 48(r1)	/* rFP */
	lwz	r14, 52(r1)	/* rPC */
	mr	r3, r4		/* return the changeInterp value */
	lwz	r0, 180(r1)	/* load the return address */
	addi	r1, r1, 176	/* stack frame back */
	mtlr	r0
	blr
	.size	dvmMterpStdBail,.-dvmMterpStdBail

#ifdef KEEP_CONSTANTS_IN_REGS
	.align 8
.Lfloat_table:
	.double	 2147483647		/* max-int */
	.double	-2147483648		/* min-int */
	.double	 9223372036854775807	/* max-long */
	.double -9223372036854775808	/* min-long */
	.long	0x59800004		/* int-adjust */
#endif

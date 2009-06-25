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
    .align  2
    .global dvmMterpStdRun
    .type   dvmMterpStdRun, @function
    .set    noreorder
    .set    noat

/*
 * On entry:
 *  a0  MterpGlue* glue
 *
 * This function returns a boolean "changeInterp" value.  The return comes
 * via a call to dvmMterpStdBail().
 */
dvmMterpStdRun:
	.cpload	t9

	/* Allocate stack and save registers we are using.
	 * The s4, s5, and s6 are used for local temporary saves
	 * across function calls.
	 * Also, allocate 4 stack words starting at offset zero
	 * as the argument space for C function calls with up to 4 args.
	 */
	addiu	sp, sp, -64
	sw	ra, 16(sp)
	sw	s0, 20(sp)	/* rPC */
	sw	s1, 24(sp)	/* rFP */
	sw	s2, 28(sp)	/* rGlue */
	sw	s3, 32(sp)	/* rIBASE */
	sw	s4, 36(sp)
	sw	s5, 40(sp)
	sw	s6, 44(sp)
	sw	s7, 48(sp)	/* rINST */
	sw	s8, 52(sp)	/* Saved gp */

	/* save stack pointer for later return.
	*/
	sw     sp, offGlue_bailPtr(a0)

	move	s8, gp		/* So we don't have to restore across calls */

	/* set up "named" registers, figure out entry point
	*/
	move    rGLUE, a0
	lbu     a1, offGlue_entryPoint(a0)
	LOAD_PC_FP_FROM_GLUE()
	la	rIBASE, dvmAsmInstructionStart
	subu	v0, a1, kInterpEntryInstr	/* usual case? */
	bnez	v0, .Lnot_instr                 /* no, handle it */

	/* start executing the instruction at rPC
	*/
	FETCH_INST()
	GET_INST_OPCODE(t7)
	GOTO_OPCODE(t7)

.Lnot_instr:
	/* were we returning from a method?
	*/
	subu	v0, a1, kInterpEntryReturn
	beqz	v0, common_returnFromMethod

.Lnot_return:
	subu	v0, a1, kInterpEntryThrow  /* were we throwing an exception? */
	beqz	v0, common_exceptionThrown

.Lbad_arg:
	move    gp, s8
	la	a0, .strBadEntryPoint
	/* a1 holds value of entryPoint */
	la	t9, printf
	jalr	t9
	nop
	move    gp, s8
	la	t9, dvmAbort
	jalr	t9
	nop

	.global dvmMterpStdBail

/*
 * Restore the stack pointer and PC from the save point established on entry.
 * This is essentially the same as a longjmp, but should be cheaper.
 *
 * On entry:
 *  a0  MterpGlue* glue
 *  a1  bool changeInterp
 */
dvmMterpStdBail:
	lw	sp, offGlue_bailPtr(a0)
	lw	ra, 16(sp)
	lw	s0, 20(sp)
	lw	s1, 24(sp)
	lw	s2, 28(sp)
	lw	s3, 32(sp)
	lw	s4, 36(sp)
	lw	s5, 40(sp)
	lw	s6, 44(sp)
	lw	s7, 48(sp)
	lw	s8, 52(sp)
	move	v0, a1			/* return the changeInterp value */
	jr	ra
	addiu	sp, sp, 64



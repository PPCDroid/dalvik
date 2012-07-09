/*
 * This file was generated automatically by gen-mterp.py for 'powerpc'.
 *
 * --> DO NOT EDIT <--
 */

/* File: powerpc/header.S */
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
 * PPC definitions and declarations.
 */

/*
POWERPC EABI notes:

Volatile registers can be clobbered across calls; dedicated registers have
a specific usage, while non-volatile registers will be 

reg.    Usage           Description
-------	--------------- -------------------------------------------------
r0	Volatile 	May be modified during function linkage
r1	Dedicated	Stack pointer
r2	Dedicated	TLS pointer to thread local area
r3-r4	Volatile	Parameter passing/Return values
r5-r10	Volatile	Parameter passing
r11-r12	Volatile	May be modified during function linkage
r13	Dedicated	Small data area pointer (unused for android)
r14-r31	Nonvolatile	Registers used for local variables
f0	Volatile	May be modified during function linkage
f1	Volatile	Parameter passing/Return values
f2-f8	Volatile	Parameter passing
f9-f13	Volatile	May be modified during function linkage
f14-f31	Nonvolatile	Registers used for local variables
CR0-CR1 Volatile	Volatile condition code registers
CR2-CR4	Nonvolatile	Non volatile condition code registers
CR5-CR7 Volatile	Volatile condition code registers
Every other register is volatile.

Mterp and POWERPC notes:

The following registers have fixed assignments.  They all need to be
saved across function calls.

  reg nick      purpose
  r14 rPC       interpreted program counter, used for fetching instructions
  r15 rFP       interpreted frame pointer, used for accessing locals and args
  r16 rGLUE     MterpGlue pointer
  r17 rIBASE    interpreted instruction base pointer, used for computed goto
  r18 rINST     first 16-bit code unit of current instruction
  r19-r22	used for temporaries across function calls
  r23 rResFld	rGLUE->methodClassDex->pResFields
  r24 rResCls	rGLUE->methodClassDex->pResClasses
  r25 rResStr	rGLUE->methodClassDex->pResStrings
  r26-r29	unused - not saved

  f14 fMaxInt	keeps a constant max-int value in double format
  f15 fMinInt	keeps a constant min-int value in double format
  f16 fMaxLong	keeps a constant max-long value in double format
  f17 fMinLong	keeps a constant min-long value in double format
  f18 fIntAdj	keeps the float adjustment value for OP_INT_TO_FLOAT
  f19-f31	unused - not saved

Macros are provided for common operations.  Each macro MUST emit only
one instruction to make instruction-counting easier.  They MUST NOT alter
unspecified registers or condition codes.
*/
#include <machine/asm.h>

/* single-purpose registers, given names for clarity.
 * Sometimes, a C helper function is called, and many need to
 * be saved across that call.
 */
#define rPC		r14
#define rFP		r15
#define rGLUE		r16
#define rIBASE		r17
#define rINST		r18
#define rResFld		r23
#define rResCls		r24
#define rResStr		r25

/* these are kept in registers to avoid reloads */
#define fMaxInt		f14
#define fMinInt		f15
#define fMaxLong	f16
#define fMinLong	f17
#define fIntAdj		f18

/* keep constants in registers */

#define KEEP_MAX_MIN_INT_IN_REGS
#define KEEP_MAX_MIN_LONG_IN_REGS
#define KEEP_INT_ADJUST_IN_REG

#define KEEP_RES_FIELDS_IN_REGS

#if defined(KEEP_MAX_MIN_INT_IN_REGS) || \
	defined(KEEP_MAX_MIN_LONG_IN_REGS) || \
	defined(KEEP_INT_ADJUST_IN_REG)
#define KEEP_CONSTANTS_IN_REGS
#endif

/* save/restore the PC and/or FP from the glue struct */
#define LOAD_PC_FROM_GLUE() \
	lwz	rPC, offGlue_pc(rGLUE)
#define SAVE_PC_TO_GLUE() \
	stw	rPC, offGlue_pc(rGLUE)
#define LOAD_FP_FROM_GLUE() \
	lwz	rFP, offGlue_fp(rGLUE)
#define SAVE_FP_TO_GLUE() \
	stw	rFP, offGlue_fp(rGLUE)

#define LOAD_PC_FP_FROM_GLUE()	\
	LOAD_PC_FROM_GLUE(); \
	LOAD_FP_FROM_GLUE()

#define SAVE_PC_FP_TO_GLUE()	\
	SAVE_PC_TO_GLUE(); \
	SAVE_FP_TO_GLUE()

/*
 * "export" the PC to the stack frame, f/b/o future exception objects.  Must
 * be done *before* something calls dvmThrowException.
 *
 * In C this is "SAVEAREA_FROM_FP(fp)->xtra.currentPc = pc", i.e.
 * fp - sizeof(StackSaveArea) + offsetof(SaveArea, xtra.currentPc)
 *
 * It's okay to do this more than once.
 */
#define EXPORT_PC() \
	stw	rPC, (-sizeofStackSaveArea + offStackSaveArea_currentPc)(rFP)

/*
 * Given a frame pointer, find the stack save area.
 *
 * In C this is "((StackSaveArea*)(_fp) -1)".
 */
#define SAVEAREA_FROM_FP(_reg, _fpreg) \
	addi	_reg, _fpreg, -sizeofStackSaveArea

/*
 * Fetch the next instruction from rPC into rINST.  Does not advance rPC.
 */
#define FETCH_INST() \
	lhz	rINST, 0(rPC)

/*
 * Fetch the next instruction from the specified offset.  Advances rPC
 * to point to the next instruction.  "_count" is in 16-bit code units.
 *
 * Because of the limited size of immediate constants on MIPS, this is only
 * suitable for small forward movements (i.e. don't try to implement "goto"
 * with this).
 *
 * This must come AFTER anything that can throw an exception, or the
 * exception catch may miss.  (This also implies that it must come after
 * EXPORT_PC().)
 */
#define FETCH_ADVANCE_INST(_count) \
	lhzu	rINST, _count*2(rPC)

/*
 * Fetch the next instruction from an offset specified by _reg.  Updates
 * rPC to point to the next instruction.  "_reg" must specify the distance
 * in bytes, *not* 16-bit code units, and may be a signed value.
 *
 * panto: update form first updates rPC to rPC+_reg, then loads
 */
#define FETCH_ADVANCE_INST_RB(_reg) \
	lhzux	rINST, rPC, _reg

/*
 * Fetch a half-word code unit from an offset past the current PC.  The
 * "_count" value is in 16-bit code units.  Does not advance rPC.
 *
 * The "_S" variant works the same but treats the value as signed.
 */
#define FETCH(_reg, _count) \
	lhz	_reg, _count*2(rPC)

#define FETCH_S(_reg, _count) \
	lha	_reg, _count*2(rPC)

/*
 * Fetch one byte from an offset past the current PC.  Pass in the same
 * "_count" as you would for FETCH, and an additional 0/1 indicating which
 * byte of the halfword you want (lo/hi).
 */
#define FETCH_B(_reg, _count, _byte) \
	lbz	_reg, _count*2+_byte(rPC)

/*
 * Put the instruction's opcode field into the specified register.
 */
#define GET_INST_OPCODE(_reg)   \
	clrlwi	_reg, rINST, 24

/*
 * Begin executing the opcode in _reg.
 */
#define GOTO_OPCODE(_reg) \
	slwi	r0, _reg, 7; \
	add	r0, r0, rIBASE; \
	mtctr	r0; \
	bctr

/*
 * Get opcode & goto - optimized
 * panto: please note that the GET_INST_OPCODE + GOTO_OPCODE sequence can be 
 * combined for PPC saving an insn
 *
 */
#define GET_INST_OPCODE_GOTO(_reg) \
	/* for handler_size_bits=7, rlwinm _reg, rINST, 7, 17, 24 */ \
	rlwinm	_reg, rINST, 7, \
		31 - 7 - 8 + 1, 31 - 7; \
	add	_reg, _reg, rIBASE; \
	mtctr	_reg; \
	bctr

/*
 * Get/set the 32-bit value from a Dalvik register.
 */
#define GET_VREG(_reg, _vreg) \
	slwi	r0, _vreg, 2; \
	lwzx	_reg, rFP, r0

#define SET_VREG(_reg, _vreg) \
	slwi	r0, _vreg, 2; \
	stwx	_reg, rFP, r0

/*
 * Get/set the 32-bit value from a Dalvik register.
 * _vreg_s is already shifted by 2
 */
#define GET_VREG_S(_reg, _vreg_s) \
	lwzx	_reg, rFP, _vreg_s

#define SET_VREG_S(_reg, _vreg_s) \
	stwx	_reg, rFP, _vreg_s

/*
 * Get/set the single precision value from a Dalvik register.
 * _vreg_s is already shifted by 2
 */
#define GET_VREG_F_S(_reg, _vreg_s) \
	lfsx	_reg, rFP, _vreg_s

#define SET_VREG_F_S(_reg, _vreg_s) \
	stfsx	_reg, rFP, _vreg_s

/*
 * Get/set the double precision value
 * _vreg_s is already shifted by 2
 * 
 * Split 8-byte double into two 4-byte integer and merge them back on the stack to get proper alignment for lfdx.
 */
#define GET_VREG_D_S(_reg, _vreg_s) \
	addi	r20, _vreg_s, 4; \
	lwzx	r21, rFP, _vreg_s; \
	lwzx	r22, rFP, r20; \
	addi	r1, r1, -8; \
	stw	r21, 0(r1); \
	stw	r22, 4(r1); \
	li	r20, 0; \
	lfdx	_reg, r1, r20; \
	addi	r1, r1, 8

#define SET_VREG_D_S(_reg, _vreg_s) \
	addi	r1, r1, -8; \
	stfd	_reg, 0(r1); \
	lwz	r21, 0(r1); \
	lwz	r22, 4(r1); \
	addi	r1, r1, 8; \
	stwx	r21, rFP, _vreg_s; \
	addi	r20, _vreg_s, 4; \
	stwx	r22, rFP, r20

/*
 * This is a #include, not a %include, because we want the C pre-processor
 * to expand the macros into assembler assignment statements.
 */
#include "../common/asm-constants.h"


/* File: powerpc/entry.S */
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
	stw	r27, 136(r1)	/* r27 */
	stw	r28, 140(r1)	/* r28 */
	stw	r29, 144(r1)	/* r29 */
	stw	r30, 148(r1)	/* r30 */
	stw	r31, 152(r1)	/* r31 */

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

	lwz	r3, offGlue_entryPoint(rGLUE)	/* r3 is now InterpEntry */
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

	lwz	r31, 152(r1)	/* r31 */
	lwz	r30, 148(r1)	/* r30 */
	lwz	r29, 144(r1)	/* r29 */
	lwz	r28, 140(r1)	/* r28 */
	lwz	r27, 136(r1)	/* r27 */
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


    .global dvmAsmInstructionStart
    .type   dvmAsmInstructionStart, %function
dvmAsmInstructionStart = .L_OP_NOP
    .text

/* ------------------------------ */
    .balign 128
.L_OP_NOP: /* 0x00 */
/* File: powerpc/OP_NOP.S */
	FETCH_ADVANCE_INST(1)			/* advance to next instr, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* r0<- opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_MOVE: /* 0x01 */
/* File: powerpc/OP_MOVE.S */
	/* for move, move-object, long-to-int */
	/* op vA, vB */
	rlwinm  r4,rINST,22,10,29		/* r6<- B << 2 */
	rlwinm  r3,rINST,26,26,29		/* r7<- (A+ & 15) << 2 */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	GET_VREG_S(r5, r4)			/* r5<- fp[B] */
	SET_VREG_S(r5, r3)			/* fp[A]<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* r0<- opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_MOVE_FROM16: /* 0x02 */
/* File: powerpc/OP_MOVE_FROM16.S */
	/* for: move/from16, move-object/from16 */
	/* op vAA, vBBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	rlwinm  r3,rINST,26,6,29		/* r3<- AA << 2 */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_VREG(r5, r4)			/* r5<- fp[BBBB] */
	SET_VREG_S(r5, r3)			/* fp[AA]<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_MOVE_16: /* 0x03 */
/* File: powerpc/OP_MOVE_16.S */
	/* for: move/16, move-object/16 */
	/* op vAAAA, vBBBB */
	FETCH(r4, 2)				/* r4<- BBBB */
	FETCH(r3, 1)				/* r3<- AAAA */
	FETCH_ADVANCE_INST(3)			/* advance rPC, load rINST */
	GET_VREG(r5, r4)			/* r5<- fp[BBBB] */
	SET_VREG(r5, r3)			/* fp[AAAA]<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_MOVE_WIDE: /* 0x04 */
/* File: powerpc/OP_MOVE_WIDE.S */
	/* move-wide vA, vB */
	/* NOTE: regs can overlap, e.g. "move v6,v7" or "move v7,v6" */
	rlwinm  r5,rINST,26,26,29		/* r5<- A(+) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	add     r6, rFP, r6			/* r6<- &fp[B] */
	add     r5, rFP, r5			/* r5<- &fp[A] */
	lwz	r3, 0(r6)			/* r3/r4<- fp[B] */
	lwz	r4, 4(r6)
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	stw	r3, 0(r5)			/* fp[A]<- r3/r4 */
	stw	r4, 4(r5)
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_MOVE_WIDE_FROM16: /* 0x05 */
/* File: powerpc/OP_MOVE_WIDE_FROM16.S */
	/* move-wide/from16 vAA, vBBBB */
	/* NOTE: regs can overlap, e.g. "move v6,v7" or "move v7,v6" */
	FETCH(r6, 1)				/* r6<- BBBB */
	rlwinm  r5,rINST,26,6,29		/* r2<- AA << 2 */
	slwi	r6, r6, 2			/* r6 <<= 2 */
	add     r5, rFP, r5			/* r5<- &fp[AA] */
	add     r6, rFP, r6			/* r6<- &fp[BBBB] */
	lwz	r3, 0(r6)			/* r3/r4<- fp[BBBB] */
	lwz	r4, 4(r6)
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	stw	r3, 0(r5)			/* fp[AA]<- r3/r4 */
	stw	r4, 4(r5)
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_MOVE_WIDE_16: /* 0x06 */
/* File: powerpc/OP_MOVE_WIDE_16.S */
	/* move-wide/16 vAAAA, vBBBB */
	/* NOTE: regs can overlap, e.g. "move v6,v7" or "move v7,v6" */
	FETCH(r5, 1)				/* r5<- AAAA */
	FETCH(r6, 2)				/* r6<- BBBB */
	slwi	r5, r5, 2			/* r5 <<= 2 */
	slwi	r6, r6, 2			/* r6 <<= 2 */
	add     r6, rFP, r6			/* r6<- &fp[B] */
	add     r5, rFP, r5			/* r5<- &fp[A] */
	lwz	r3, 0(r6)			/* r3/r4<- fp[B] */
	lwz	r4, 4(r6)
	FETCH_ADVANCE_INST(3)			/* advance rPC, load rINST */
	stw	r3, 0(r5)			/* fp[A]<- r3/r4 */
	stw	r4, 4(r5)
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_MOVE_OBJECT: /* 0x07 */
/* File: powerpc/OP_MOVE_OBJECT.S */
/* File: powerpc/OP_MOVE.S */
	/* for move, move-object, long-to-int */
	/* op vA, vB */
	rlwinm  r4,rINST,22,10,29		/* r6<- B << 2 */
	rlwinm  r3,rINST,26,26,29		/* r7<- (A+ & 15) << 2 */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	GET_VREG_S(r5, r4)			/* r5<- fp[B] */
	SET_VREG_S(r5, r3)			/* fp[A]<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* r0<- opcode from rINST & exec */



/* ------------------------------ */
    .balign 128
.L_OP_MOVE_OBJECT_FROM16: /* 0x08 */
/* File: powerpc/OP_MOVE_OBJECT_FROM16.S */
/* File: powerpc/OP_MOVE_FROM16.S */
	/* for: move/from16, move-object/from16 */
	/* op vAA, vBBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	rlwinm  r3,rINST,26,6,29		/* r3<- AA << 2 */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_VREG(r5, r4)			/* r5<- fp[BBBB] */
	SET_VREG_S(r5, r3)			/* fp[AA]<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_MOVE_OBJECT_16: /* 0x09 */
/* File: powerpc/OP_MOVE_OBJECT_16.S */
/* File: powerpc/OP_MOVE_16.S */
	/* for: move/16, move-object/16 */
	/* op vAAAA, vBBBB */
	FETCH(r4, 2)				/* r4<- BBBB */
	FETCH(r3, 1)				/* r3<- AAAA */
	FETCH_ADVANCE_INST(3)			/* advance rPC, load rINST */
	GET_VREG(r5, r4)			/* r5<- fp[BBBB] */
	SET_VREG(r5, r3)			/* fp[AAAA]<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_MOVE_RESULT: /* 0x0a */
/* File: powerpc/OP_MOVE_RESULT.S */
	/* for: move-result, move-result-object */
	/* op vAA */
	rlwinm  r5,rINST,26,6,29		/* r2<- AA << 2 */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	lwz	r3, offGlue_retval(rGLUE)	/* r3<- glue->retval.i */
	SET_VREG_S(r3, r5)			/* fp[AA]<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_MOVE_RESULT_WIDE: /* 0x0b */
/* File: powerpc/OP_MOVE_RESULT_WIDE.S */
	/* move-result-wide vAA */
	rlwinm  r5,rINST,26,6,29		/* r5<- AA << 2 */
	addi	r6, rGLUE, offGlue_retval	/* r3<- &glue->retval */
	add	r5, rFP, r5			/* r5<- &fp[AA] */
	lwz	r3, offGlue_retval(rGLUE)	/* r3/r4<- retval.j */
	lwz	r4, offGlue_retval+4(rGLUE)
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	stw	r3, 0(r5)			/* fp[AA]<- r3/r4 */
	stw	r4, 4(r5)
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_MOVE_RESULT_OBJECT: /* 0x0c */
/* File: powerpc/OP_MOVE_RESULT_OBJECT.S */
/* File: powerpc/OP_MOVE_RESULT.S */
	/* for: move-result, move-result-object */
	/* op vAA */
	rlwinm  r5,rINST,26,6,29		/* r2<- AA << 2 */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	lwz	r3, offGlue_retval(rGLUE)	/* r3<- glue->retval.i */
	SET_VREG_S(r3, r5)			/* fp[AA]<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */



/* ------------------------------ */
    .balign 128
.L_OP_MOVE_EXCEPTION: /* 0x0d */
/* File: powerpc/OP_MOVE_EXCEPTION.S */
	/* move-exception vAA */
	lwz	r3, offGlue_self(rGLUE)		/* r3<- glue->self */
	rlwinm	r5, rINST, 26, 6, 29		/* r5<- AA << 2 */
	lwz	r6, offThread_exception(r3)	/* r6<- dvmGetException bypass */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	li	r4, 0				/* r4<- 0 */
	SET_VREG_S(r6, r5)			/* fp[AA]<- exception obj */
	stw	r4, offThread_exception(r3)	/* dvmClearException bypass */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_RETURN_VOID: /* 0x0e */
/* File: powerpc/OP_RETURN_VOID.S */
	b	common_returnFromMethod

/* ------------------------------ */
    .balign 128
.L_OP_RETURN: /* 0x0f */
/* File: powerpc/OP_RETURN.S */
	/*
	 * Return a 32-bit value.  Copies the return value into the "glue"
	 * structure, then jumps to the return handler.
	 *
	 * for: return, return-object
	 */
	/* op vAA */
	rlwinm  r5,rINST,26,6,29		/* r5<- AA << 2*/
	GET_VREG_S(r3, r5)			/* r0<- vAA */
	stw	r3, offGlue_retval(rGLUE)	/* retval.i <- vAA */
	b	common_returnFromMethod

/* ------------------------------ */
    .balign 128
.L_OP_RETURN_WIDE: /* 0x10 */
/* File: powerpc/OP_RETURN_WIDE.S */
	/*
	 * Return a 64-bit value.  Copies the return value into the "glue"
	 * structure, then jumps to the return handler.
	 */
	/* return-wide vAA */
	rlwinm  r5,rINST,26,6,29		/* r5<- AA << 2*/
	add     r5, rFP, r5			/* r5<- &fp[AA] */
	lwz	r3, 0(r5)			/* r3/r4 <- vAA/vAA+1 */
	lwz	r4, 4(r5)
	stw	r3, offGlue_retval(rGLUE)	/* retval<- r3/r4 */
	stw	r4, offGlue_retval+4(rGLUE)
	b	common_returnFromMethod

/* ------------------------------ */
    .balign 128
.L_OP_RETURN_OBJECT: /* 0x11 */
/* File: powerpc/OP_RETURN_OBJECT.S */
/* File: powerpc/OP_RETURN.S */
	/*
	 * Return a 32-bit value.  Copies the return value into the "glue"
	 * structure, then jumps to the return handler.
	 *
	 * for: return, return-object
	 */
	/* op vAA */
	rlwinm  r5,rINST,26,6,29		/* r5<- AA << 2*/
	GET_VREG_S(r3, r5)			/* r0<- vAA */
	stw	r3, offGlue_retval(rGLUE)	/* retval.i <- vAA */
	b	common_returnFromMethod


/* ------------------------------ */
    .balign 128
.L_OP_CONST_4: /* 0x12 */
/* File: powerpc/OP_CONST_4.S */
	/* const/4 vA, #+B */
	rlwinm  r4,rINST,16,0,15		/* r4<- Bxxx0000 */
	rlwinm  r3,rINST,26,26,29		/* r3<- A+ << 2 */
	srawi   r4,r4,28			/* r4<- sssssssB (sign-extended) */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	SET_VREG_S(r4, r3)			/* fp[A]<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_CONST_16: /* 0x13 */
/* File: powerpc/OP_CONST_16.S */
	/* const/16 vAA, #+BBBB */
	FETCH_S(r3, 1)				/* r3<- ssssBBBB (sign-extended) */
	rlwinm  r6,rINST,26,6,29		/* r6<- AA << 2 */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r6)			/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_CONST: /* 0x14 */
/* File: powerpc/OP_CONST.S */
	/* const vAA, #+BBBBbbbb */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r3, 1)				/* r3<- bbbb (low) */
	FETCH(r4, 2)				/* r4<- BBBB (high) */
	FETCH_ADVANCE_INST(3)			/* advance rPC, load rINST */
	rotlwi	r4, r4, 16			/* rotate */
	or	r3, r3, r4			/* r3<- BBBBbbbb */
	SET_VREG_S(r3, r19)			/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* ------------------------------ */
    .balign 128
.L_OP_CONST_HIGH16: /* 0x15 */
/* File: powerpc/OP_CONST_HIGH16.S */
	/* const/high16 vAA, #+BBBB0000 */
	FETCH(r3, 1)				/* r3<- 0000BBBB (zero-extended) */
	rlwinm  r6,rINST,26,6,29		/* r6<- AA << 2 */
	slwi	r3, r3, 16			/* r3<- BBBB0000 */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r6)			/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_CONST_WIDE_16: /* 0x16 */
/* File: powerpc/OP_CONST_WIDE_16.S */
	/* const-wide/16 vAA, #+BBBB */
	FETCH_S(r4, 1)				/* r4<- ssssBBBB (sign-extended) */
	rlwinm	r6,rINST,26,6,29		/* r6<- AA << 2 */
	srawi	r3, r4, 31			/* r3<- ssssssss */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	add	r6, rFP, r6			/* r6<- &fp[AA] */
	stw	r3, 0(r6)			/* vAA<- r3/r4 */
	stw	r4, 4(r6)
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_CONST_WIDE_32: /* 0x17 */
/* File: powerpc/OP_CONST_WIDE_32.S */
	/* const-wide/32 vAA, #+BBBBbbbb */
	FETCH(r3, 1)				/* r3<- bbbb (low) */
	rlwinm	r7,rINST,26,6,29		/* r7<- AA << 2 */
	FETCH(r4, 2)				/* r4<- BBBB (low middle) */
	add     r7, rFP, r7			/* r7<- &fp[AA] */
	rotlwi	r4, r4, 16			/* r4<- BBBB0000 */
	or	r4, r4, r3			/* r4<- BBBBbbbb (low word) */
	srawi	r3, r4, 31			/* r3<- ssssssss */
	FETCH_ADVANCE_INST(3)			/* advance rPC, load rINST */
	stw	r3, 0(r7)			/* store high word */
	stw	r4, 4(r7)			/* store low word */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_CONST_WIDE: /* 0x18 */
/* File: powerpc/OP_CONST_WIDE.S */
	/* const-wide vAA, #+HHHHhhhhBBBBbbbb */
	FETCH(r4, 2)				/* r4<- BBBB (low middle) */
	rlwinm	r7,rINST,26,6,29		/* r7<- AA << 2 */
	FETCH(r3, 1)				/* r3<- bbbb (low) */
	rotlwi	r4, r4, 16			/* r4<- BBBB0000 */
	FETCH(r6, 4)				/* r6<- HHHH (high) */
	add     r7, rFP, r7			/* r7<- &fp[AA] */
	FETCH(r5, 3)				/* r5<- hhhh (high middle) */
	rotlwi	r6, r6, 16			/* r6<- HHHH0000 */
	or	r3, r3, r4			/* r3<- BBBBbbbb (low word) */
	or	r4, r5, r6			/* r4<- HHHHhhhh (high word) */
	FETCH_ADVANCE_INST(5)			/* advance rPC, load rINST */
	stw	r4, 0(r7)			/* store high word */
	stw	r3, 4(r7)			/* store low word */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_CONST_WIDE_HIGH16: /* 0x19 */
/* File: powerpc/OP_CONST_WIDE_HIGH16.S */
	/* const-wide/high16 vAA, #+BBBB000000000000 */
	FETCH_S(r3, 1)				/* r3<- ssssBBBB (sign-extended) */
	rlwinm	r6,rINST,26,6,29		/* r6<- AA << 2 */
	slwi	r3, r3, 16			/* r3<- BBBB0000 */
	li	r4, 0				/* r4<- 00000000 */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	add	r6, rFP, r6			/* r6<- &fp[AA] */
	stw	r3, 0(r6)			/* vAA<- r3/r4 */
	stw	r4, 4(r6)
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_CONST_STRING: /* 0x1a */
/* File: powerpc/OP_CONST_STRING.S */
	/* const/string vAA, String@BBBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- BBBB */
	slwi	r6, r4, 2			/* r6<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r5, offGlue_methodClassDex(rGLUE)	/* r5<- glue->methodClassDex */
	lwz	r5, offDvmDex_pResStrings(r5)	/* r5<- dvmDex->pResStrings */
	lwzx	r3, r5, r6			/* r3<- pResStrings[BBBB] */
#else
	lwzx	r3, rResStr, r6			/* r3<- pResStrings[BBBB] */
#endif
	cmpwi	r3, 0				/* not yet resolved? */
	bne+	0f				/* resolved, handle it */
	EXPORT_PC()
	lwz	r3, offGlue_method(rGLUE)	/* r3<- glue->method */
	lwz	r3, offMethod_clazz(r3)		/* r3<- method->clazz */
	bl	dvmResolveString@plt		/* r3<- String reference */
	cmpwi	r3, 0				/* failed? */
	beq-	common_exceptionThrown		/* yup, handle the exception */
0:	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_CONST_STRING_JUMBO: /* 0x1b */
/* File: powerpc/OP_CONST_STRING_JUMBO.S */
	/* const/string vAA, String@BBBBBBBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r3, 1)				/* r3<- bbbb (low) */
	FETCH(r4, 2)				/* r4<- BBBB (high) */
	rotlwi	r4, r4, 16			/* rotate */
	or	r4, r3, r4			/* r4<- BBBBbbbb */
	slwi	r6, r4, 2			/* r6<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r5, offGlue_methodClassDex(rGLUE)	/* r5<- glue->methodClassDex */
	lwz	r5, offDvmDex_pResStrings(r5)	/* r5<- dvmDex->pResStrings */
	lwzx	r3, r5, r6			/* r3<- pResStrings[BBBBBBBB] */
#else
	lwzx	r3, rResStr, r6			/* r3<- pResStrings[BBBBBBBB] */
#endif
	cmpwi	r3, 0				/* not yet resolved? */
	bne+	0f				/* resolved, handle it */
	EXPORT_PC()
	lwz	r3, offGlue_method(rGLUE)	/* r3<- glue->method */
	lwz	r3, offMethod_clazz(r3)		/* r3<- method->clazz */
	bl	dvmResolveString@plt		/* r3<- String reference */
	cmpwi	r3, 0				/* failed? */
	beq-	common_exceptionThrown		/* yup, handle the exception */
0:	FETCH_ADVANCE_INST(3)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_CONST_CLASS: /* 0x1c */
/* File: powerpc/OP_CONST_CLASS.S */
	/* const/class vAA, Class@BBBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- BBBB */
	slwi	r6, r4, 2			/* r6<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r5, offGlue_methodClassDex(rGLUE)	/* r5<- glue->methodClassDex */
	lwz	r5, offDvmDex_pResClasses(r5)		/* r5<- dvmDex->pResClasses */
	lwzx	r3, r5, r6			/* r3<- pResClasses[BBBB] */
#else
	lwzx	r3, rResCls, r6			/* r3<- pResClasses[BBBB] */
#endif
	cmpwi	r3, 0				/* not yet resolved? */
	bne+	0f				/* resolved, handle it */
	EXPORT_PC()
	lwz	r3, offGlue_method(rGLUE)	/* r3<- glue->method */
	li	r5, 1				/* r5<- true */
	lwz	r3, offMethod_clazz(r3)		/* r3<- method->clazz */
	bl	dvmResolveClass@plt		/* r3<- Class reference */
	cmpwi	r3, 0				/* failed? */
	beq-	common_exceptionThrown		/* yup, handle the exception */
0:	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_MONITOR_ENTER: /* 0x1d */
/* File: powerpc/OP_MONITOR_ENTER.S */
	/*
	 * Synchronize on an object.
	 */
	/* monitor-enter vAA */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	GET_VREG_S(r4, r19)			/* r4<- vAA (object) */
	lwz	r3, offGlue_self(rGLUE)		/* r3<- glue->self */
	cmpwi	r4, 0				/* null object? */
	EXPORT_PC()				/* need for precise GC, MONITOR_TRACKING */
	beq-	common_errNullObject		/* null object, throw an exception */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	bl	dvmLockObject@plt		/* call(self, obj) */
#ifdef WITH_DEADLOCK_PREDICTION /* implies WITH_MONITOR_TRACKING */
	lwz	r3, offGlue_self(rGLUE)		/* r3<- glue->self */
	lwz	r4, offThread_exception(r3)	/* check for exception */
	cmpwi	r4, 0
	bne-	common_exceptionThrown		/* exception raised, bail out */
#endif
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_MONITOR_EXIT: /* 0x1e */
/* File: powerpc/OP_MONITOR_EXIT.S */
	/*
	 * Unlock an object.
	 *
	 * Exceptions that occur when unlocking a monitor need to appear as
	 * if they happened at the following instruction.  See the Dalvik
	 * instruction spec.
	 */
	/* monitor-exit vAA */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	EXPORT_PC()				/* before fetch: export the PC */
	GET_VREG_S(r4, r19)			/* r4<- vAA (object) */
	cmpwi	r4, 0				/* null object? */
	beq-	1f
	lwz	r3, offGlue_self(rGLUE)		/* r3<- glue->self */
	bl	dvmUnlockObject@plt		/* call(self, obj) */
	cmpwi	r3, 0				/* failed? */
	FETCH_ADVANCE_INST(1)			/* before throw: advance rPC, load rINST */
	beq-	common_exceptionThrown		/* yes, exception is pending */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */
1:
	FETCH_ADVANCE_INST(1)			/* advance before throw */
	beq-	common_errNullObject

/* ------------------------------ */
    .balign 128
.L_OP_CHECK_CAST: /* 0x1f */
/* File: powerpc/OP_CHECK_CAST.S */
	/*
	 * Check to see if a cast from one class to another is allowed.
	 */
	/* check-cast vAA, class@BBBB */
	rlwinm	r6,rINST,26,6,29		/* r6<- AA << 2 */
	FETCH(r4, 1)				/* r4<- BBBB */
	GET_VREG_S(r19, r6)			/* r19<- object */
	cmpwi	r19, 0				/* is object null? */
	beq-    0f				/* null obj, cast always succeeds */
	slwi	r5, r4, 2			/* r5<- BBBB << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r6, offDvmDex_pResClasses(r6)	/* r6<- pDvmDex->pResClasses */
	lwzx	r4, r6, r5			/* r4<- resolved class */
#else
	lwzx	r4, rResCls, r5			/* r4<- resolved class */
#endif
	cmpwi	r4, 0				/* have we resolved this before? */
	beq-	.LOP_CHECK_CAST_resolve		/* not resolved, do it now */
.LOP_CHECK_CAST_resolved:
	lwz	r3, offObject_clazz(r19)	/* r3<- obj->clazz */
	cmpw	r3, r4				/* same class (trivial success)? */
	beq-	0f				/* yes, skip full check */
	/*
	* Trivial test failed, need to perform full check.  This is common.
	*  r3 holds obj->clazz
	*  r4 holds class resolved from BBBB
	*  r19 holds object
	*/
	bl	dvmInstanceofNonTrivial@plt	/* r3<- boolean result */
	cmpwi	r3, 0				/* failed? */
	beq-	.LOP_CHECK_CAST_throw		/* yes, throw exception */
0:	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_INSTANCE_OF: /* 0x20 */
/* File: powerpc/OP_INSTANCE_OF.S */
	/*
	 * Check to see if an object reference is an instance of a class.
	 *
	 * Most common situation is a non-null object, being compared against
	 * an already-resolved class.
	 */
	/* instance-of vA, vB, class@CCCC */
	rlwinm	r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm	r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r6)			/* r3<- vB (object) */
	cmpwi	r3, 0				/* is object null? */
	beq-	0f				/* null obj, not an instance, store r3 */
	FETCH(r4, 1)				/* r4<- CCCC */
	slwi	r5, r4, 2			/* r5<- CCCC << 2 */
	lwz	r3, offObject_clazz(r3)		/* r3<- obj->clazz */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r6, offDvmDex_pResClasses(r6)	/* r6<- pDvmDex->pResClasses */
	lwzx	r4, r6, r5			/* r4<- resolved class */
#else
	lwzx	r4, rResCls, r5			/* r4<- resolved class */
#endif
	cmpwi	r4, 0				/* have we resolved this before? */
	beq-	.LOP_INSTANCE_OF_resolve		/* not resolved, do it now */
.LOP_INSTANCE_OF_resolved:				/* r0=obj->clazz, r1=resolved class */
	cmpw	r3, r4				/* same class (trivial success)? */
	bne-	1f				/* yes, do full check */
	li	r3, 1				/* indicate success */
	b	0f
1:	bl	dvmInstanceofNonTrivial@plt	/* r3<- boolean result */
0:	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* vA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_ARRAY_LENGTH: /* 0x21 */
/* File: powerpc/OP_ARRAY_LENGTH.S */
	/*
	 * Return the length of an array.
	 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r6)			/* r3<- vB */
	cmpwi	r3, 0				/* is object null? */
	beq-	common_errNullObject		/* yup, fail */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	lwz	r3, offArrayObject_length(r3)	/* r3<- array length */
	SET_VREG_S(r3, r19)			/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* ------------------------------ */
    .balign 128
.L_OP_NEW_INSTANCE: /* 0x22 */
/* File: powerpc/OP_NEW_INSTANCE.S */
	/*
	 * Create a new instance of a class.
	 */
	/* new-instance vAA, class@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	slwi	r5, r4, 2			/* r5<- BBBB << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r6, offDvmDex_pResClasses(r6)	/* r6<- pDvmDex->pResClasses */
	lwzx	r3, r6, r5			/* r3<- resolved class */
#else
	lwzx	r3, rResCls, r5			/* r3<- resolved class */
#endif
	EXPORT_PC()				/* req'd for init, resolve, alloc */
	cmpwi	r3, 0				/* already resolved? */
	bne+	0f				/* yes, continue */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	li	r5, 0				/* r5<- false */
	bl	dvmResolveClass@plt		/* r3<- resolved ClassObject ptr */
	cmpwi	r3, 0				/* got null? */
	beq-	common_exceptionThrown		/* yes, handle exception */
0:	lbz	r4, offClassObject_status(r3)	/* r1<- ClassStatus enum */
	cmpwi	r4, CLASS_INITIALIZED		/* has class been initialized? */
	bne-	.LOP_NEW_INSTANCE_needinit		/* no, init class now */
.LOP_NEW_INSTANCE_initialized:			/* r3=class */
						/* finish */
	li	r4, ALLOC_DONT_TRACK		/* flags for alloc call */
	bl	dvmAllocObject@plt		/* r3<- new object */
	cmpwi	r3, 0				/* failed? */
	beq-	common_exceptionThrown		/* yes, handle the exception */
	rlwinm	r6,rINST,26,6,29		/* r6<- AA << 2 */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r6)			/* vAA<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_NEW_ARRAY: /* 0x23 */
/* File: powerpc/OP_NEW_ARRAY.S */
	/*
	 * Allocate an array of objects, specified with the array class
	 * and a count.
	 *
	 * The verifier guarantees that this is an array class, so we don't
	 * check for it here.
	 */
	/* new-array vA, vB, class@CCCC */
	rlwinm	r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm	r3,rINST,22,10,29		/* r3<- B << 2 */
	GET_VREG_S(r4, r3)			/* r4<- vB (array length) */
	cmpwi	r4, 0				/* check length */
	blt-	common_errNegativeArraySize	/* negative length, bail */
	FETCH(r5, 1)				/* r5<- CCCC */
	slwi	r7, r5, 2			/* r7<- CCCC << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r6, offDvmDex_pResClasses(r6)	/* r6<- pDvmDex->pResClasses */
	lwzx	r3, r6, r7			/* r3<- resolved class */
#else
	lwzx	r3, rResCls, r7			/* r3<- resolved class */
#endif
	EXPORT_PC()				/* req'd for resolve, alloc */
	cmpwi	r3, 0				/* already resolved? */
	beq-	.LOP_NEW_ARRAY_resolve		/* do resolve now */
.LOP_NEW_ARRAY_finish:
	li	r5, ALLOC_DONT_TRACK		/* don't track in local refs table */
	bl	dvmAllocArrayByClass@plt	/* r3<- call(clazz(r3), length(r4), flags(r5)) */
	cmpwi	r3, 0				/* failed? */
	beq-	common_exceptionThrown		/* yes, handle the exception */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* vA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_FILLED_NEW_ARRAY: /* 0x24 */
/* File: powerpc/OP_FILLED_NEW_ARRAY.S */
	/*
	* Create a new array with elements filled from registers.
	*
	* for: filled-new-array, filled-new-array/range
	*/
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op {vCCCC..v(CCCC+AA-1)}, type@BBBB */

	.if	0
	rlwinm  r20,rINST,24,24,31		/* r20<- AA */
	.else
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r20,rINST,20,28,31		/* r20<- B */
	.endif
	FETCH(r4, 1)				/* r4<- CCCC or BBBB */
	slwi	r5, r4, 2			/* r5<- CCCC << 2 or BBBB << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r6, offDvmDex_pResClasses(r6)	/* r6<- pDvmDex->pResClasses */
	lwzx	r3, r6, r5			/* r3<- resolved class */
#else
	lwzx	r3, rResCls, r5			/* r3<- resolved class */
#endif
	EXPORT_PC()				/* need for resolve and alloc */
	cmpwi	r3, 0				/* already resolved? */
	bne+	.LOP_FILLED_NEW_ARRAY_continue		/*  yes, continue on */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	li	r5, 0				/* r5<- false */
	bl	dvmResolveClass@plt		/* r3<- call(clazz, ref) */
	cmpwi	r3, 0				/* got null? */
	bne+    .LOP_FILLED_NEW_ARRAY_continue		/* continue? */
	b	common_exceptionThrown		/* no, handle exception */


/* ------------------------------ */
    .balign 128
.L_OP_FILLED_NEW_ARRAY_RANGE: /* 0x25 */
/* File: powerpc/OP_FILLED_NEW_ARRAY_RANGE.S */
/* File: powerpc/OP_FILLED_NEW_ARRAY.S */
	/*
	* Create a new array with elements filled from registers.
	*
	* for: filled-new-array, filled-new-array/range
	*/
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op {vCCCC..v(CCCC+AA-1)}, type@BBBB */

	.if	1
	rlwinm  r20,rINST,24,24,31		/* r20<- AA */
	.else
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r20,rINST,20,28,31		/* r20<- B */
	.endif
	FETCH(r4, 1)				/* r4<- CCCC or BBBB */
	slwi	r5, r4, 2			/* r5<- CCCC << 2 or BBBB << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r6, offDvmDex_pResClasses(r6)	/* r6<- pDvmDex->pResClasses */
	lwzx	r3, r6, r5			/* r3<- resolved class */
#else
	lwzx	r3, rResCls, r5			/* r3<- resolved class */
#endif
	EXPORT_PC()				/* need for resolve and alloc */
	cmpwi	r3, 0				/* already resolved? */
	bne+	.LOP_FILLED_NEW_ARRAY_RANGE_continue		/*  yes, continue on */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	li	r5, 0				/* r5<- false */
	bl	dvmResolveClass@plt		/* r3<- call(clazz, ref) */
	cmpwi	r3, 0				/* got null? */
	bne+    .LOP_FILLED_NEW_ARRAY_RANGE_continue		/* continue? */
	b	common_exceptionThrown		/* no, handle exception */



/* ------------------------------ */
    .balign 128
.L_OP_FILL_ARRAY_DATA: /* 0x26 */
/* File: powerpc/OP_FILL_ARRAY_DATA.S */
	/* fill-array-data vAA, +BBBBBBBB */
	rlwinm	r6,rINST,26,6,29		/* r6<- AA << 2 */
	FETCH(r3, 1)				/* r3<- bbbb (lo) */
	FETCH(r4, 2)				/* r4<- BBBB (hi) */
	rotlwi	r4, r4, 16			/* rotate */
	or	r4, r3, r4			/* r4<- BBBBbbbb */
	GET_VREG_S(r3, r6)			/* r3<- vAA (array object) */
	slwi	r5, r4, 1			/* r5<- BBBBbbbb << 1 */
	add	r4, rPC, r5			/* r4<- PC + BBBBbbbb*2 (array data off.) */
	EXPORT_PC()
	bl	dvmInterpHandleFillArrayData@plt	/*fill the array with predefined data */
	cmpwi	r3, 0				/* exception? */
	beq-	common_exceptionThrown		/* has exception */
	FETCH_ADVANCE_INST(3)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_THROW: /* 0x27 */
/* File: powerpc/OP_THROW.S */
	/*
	 * Throw an exception object in the current thread.
	 */
	/* throw vAA */
	rlwinm  r5,rINST,26,6,29		/* r5<- AA */
	GET_VREG_S(r4, r5)			/* r4<- vAA (exception object) */
	lwz	r3, offGlue_self(rGLUE)		/* r3<- glue->self */
	EXPORT_PC()
	cmpwi	r4, 0				/* null object? */
	beq-	common_errNullObject		/* yes, throw an NPE instead */
	/* bypass dvmSetException, just store it */
	stw	r4, offThread_exception(r3)	/* thread->exception<- obj */
	b	common_exceptionThrown

/* ------------------------------ */
    .balign 128
.L_OP_GOTO: /* 0x28 */
/* File: powerpc/OP_GOTO.S */
	/*
	 * Unconditional branch, 8-bit offset.
	 *
	 * The branch distance is a signed code-unit offset, which we need to
	 * double to get a byte offset.
	 */
	/* goto +AA */
	slwi	r3, rINST, 16			/* r3<- AAxx0000 */
	srawi	r11, r3, 24			/* r11<- ssssssAA (sign-extended) */
	slwi.	r11, r11, 1			/* r11<- byte offset */
	ble+	common_backwardBranch		/* backward branch, do periodic checks */
	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_GOTO_16: /* 0x29 */
/* File: powerpc/OP_GOTO_16.S */
	/*
	* Unconditional branch, 16-bit offset.
	*
	* The branch distance is a signed code-unit offset, which we need to
	* double to get a byte offset.
	*/
	/* goto/16 +AAAA */
	FETCH_S(r3, 1)				/* r3<- ssssAAAA (sign-extended) */
	slwi.	r11, r3, 1			/* r11<- byte offset, check sign */
	blt+	common_backwardBranch		/* backward branch, do periodic checks */
	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_GOTO_32: /* 0x2a */
/* File: powerpc/OP_GOTO_32.S */
	/*
	 * Unconditional branch, 32-bit offset.
	 *
	 * The branch distance is a signed code-unit offset, which we need to
	 * double to get a byte offset.
	 *
	 * Unlike most opcodes, this one is allowed to branch to itself, so
	 * our "backward branch" test must be "<=0" instead of "<0".
	 * explicitly.
	 */
	/* goto/32 +AAAAAAAA */
	FETCH(r3, 1)				/* r3<- aaaa (lo) */
	FETCH(r4, 2)				/* r4<- AAAA (hi) */
	rotlwi	r4, r4, 16			/* rotate */
	or	r3, r3, r4			/* r3<- AAAAaaaa */
	slwi.	r11, r3, 1			/* r11<- byte offset, check sign */
	ble-	common_backwardBranch		/* backward branch, do periodic checks */
	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_PACKED_SWITCH: /* 0x2b */
/* File: powerpc/OP_PACKED_SWITCH.S */
	/*
	 * Handle a packed-switch or sparse-switch instruction.  In both cases
	 * we decode it and hand it off to a helper function.
	 *
	 * We don't really expect backward branches in a switch statement, but
	 * they're perfectly legal, so we check for them here.
	 *
	 * for: packed-switch, sparse-switch
	 */
	/* op vAA, +BBBB */
	FETCH(r3, 1)				/* r3<- bbbb (lo) */
	FETCH(r4, 2)				/* r4<- BBBB (hi) */
	rlwinm	r6,rINST,26,6,29		/* r7<- AA << 2 */
	rotlwi	r4, r4, 16			/* rotate */
	or	r3, r3, r4			/* r3<- BBBBbbbb */
	slwi	r3, r3, 1			/* r3<- BBBBbbbb* 2 */
	GET_VREG_S(r4, r6)			/* r4<- vAA */
	add     r3, rPC, r3			/* r3<- PC + BBBBbbbb*2 */
	bl      dvmInterpHandlePackedSwitch				/* r3<- code-unit branch offset */
	slwi	r11, r3, 1			/* r11<- branch byte offset, check sign */
	cmpwi	r3, 0				/* compare sign */
	ble-	common_backwardBranch		/* backward branch, do periodic checks */
	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_SPARSE_SWITCH: /* 0x2c */
/* File: powerpc/OP_SPARSE_SWITCH.S */
/* File: powerpc/OP_PACKED_SWITCH.S */
	/*
	 * Handle a packed-switch or sparse-switch instruction.  In both cases
	 * we decode it and hand it off to a helper function.
	 *
	 * We don't really expect backward branches in a switch statement, but
	 * they're perfectly legal, so we check for them here.
	 *
	 * for: packed-switch, sparse-switch
	 */
	/* op vAA, +BBBB */
	FETCH(r3, 1)				/* r3<- bbbb (lo) */
	FETCH(r4, 2)				/* r4<- BBBB (hi) */
	rlwinm	r6,rINST,26,6,29		/* r7<- AA << 2 */
	rotlwi	r4, r4, 16			/* rotate */
	or	r3, r3, r4			/* r3<- BBBBbbbb */
	slwi	r3, r3, 1			/* r3<- BBBBbbbb* 2 */
	GET_VREG_S(r4, r6)			/* r4<- vAA */
	add     r3, rPC, r3			/* r3<- PC + BBBBbbbb*2 */
	bl      dvmInterpHandleSparseSwitch				/* r3<- code-unit branch offset */
	slwi	r11, r3, 1			/* r11<- branch byte offset, check sign */
	cmpwi	r3, 0				/* compare sign */
	ble-	common_backwardBranch		/* backward branch, do periodic checks */
	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_CMPL_FLOAT: /* 0x2d */
/* File: powerpc/OP_CMPL_FLOAT.S */
	/*
	 * Compare two floating-point values.  Puts 0, 1, or -1 into the
	 * destination register based on the results of the comparison.
	 *
	 * Provide a "naninst" instruction that puts 1 or -1 into r3 depending
	 * on what value we'd like to return when one of the operands is NaN.
	 *
	 * The operation we're implementing is:
	 *   if (x == y)
	 *     return 0;
	 *   else if (x < y)
	 *     return -1;
	 *   else if (x > y)
	 *     return 1;
	 *   else
	 *     return {-1,1};  // one or both operands was NaN
	 *
	 * for: cmpl-float, cmpg-float
	 */
	/* op vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_F_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_F_S(f1, r5)			/* f1<- vBB+1 */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	fcmpu	cr7, f1, f2			/* compare f1, f2 */
	li	r3, -1				/* set result if following comparison true */
	blt-	cr7, 0f				/* branch on f1 < f2 */
	li	r3, 1				/* set result if following comparison true */
	bgt-	cr7, 0f				/* branch on f1 > f2 */
	li	r3, 0				/* set result if following comparison true */
	beq-	cr7, 0f				/* branch on f1 == f2 */
	li	r3, -1				/* either f1 or f2 is a NaN */
0:
	SET_VREG_S(r3, r19)			/* vAA<- e3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* ------------------------------ */
    .balign 128
.L_OP_CMPG_FLOAT: /* 0x2e */
/* File: powerpc/OP_CMPG_FLOAT.S */
/* File: powerpc/OP_CMPL_FLOAT.S */
	/*
	 * Compare two floating-point values.  Puts 0, 1, or -1 into the
	 * destination register based on the results of the comparison.
	 *
	 * Provide a "naninst" instruction that puts 1 or -1 into r3 depending
	 * on what value we'd like to return when one of the operands is NaN.
	 *
	 * The operation we're implementing is:
	 *   if (x == y)
	 *     return 0;
	 *   else if (x < y)
	 *     return -1;
	 *   else if (x > y)
	 *     return 1;
	 *   else
	 *     return {-1,1};  // one or both operands was NaN
	 *
	 * for: cmpl-float, cmpg-float
	 */
	/* op vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_F_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_F_S(f1, r5)			/* f1<- vBB+1 */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	fcmpu	cr7, f1, f2			/* compare f1, f2 */
	li	r3, -1				/* set result if following comparison true */
	blt-	cr7, 0f				/* branch on f1 < f2 */
	li	r3, 1				/* set result if following comparison true */
	bgt-	cr7, 0f				/* branch on f1 > f2 */
	li	r3, 0				/* set result if following comparison true */
	beq-	cr7, 0f				/* branch on f1 == f2 */
	li	r3, 1				/* either f1 or f2 is a NaN */
0:
	SET_VREG_S(r3, r19)			/* vAA<- e3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_CMPL_DOUBLE: /* 0x2f */
/* File: powerpc/OP_CMPL_DOUBLE.S */
	/*
	 * Compare two floating-point values.  Puts 0, 1, or -1 into the
	 * destination register based on the results of the comparison.
	 *
	 * Provide a "naninst" instruction that puts 1 or -1 into r3 depending
	 * on what value we'd like to return when one of the operands is NaN.
	 *
	 * The operation we're implementing is:
	 *   if (x == y)
	 *     return 0;
	 *   else if (x < y)
	 *     return -1;
	 *   else if (x > y)
	 *     return 1;
	 *   else
	 *     return {-1,1};  // one or both operands was NaN
	 *
	 * for: cmpl-double, cmpg-double
	 */
	/* op vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_D_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_D_S(f1, r5)			/* f1<- vBB+1 */

	b .LOP_CMPL_DOUBLE_split


/* ------------------------------ */
    .balign 128
.L_OP_CMPG_DOUBLE: /* 0x30 */
/* File: powerpc/OP_CMPG_DOUBLE.S */
/* File: powerpc/OP_CMPL_DOUBLE.S */
	/*
	 * Compare two floating-point values.  Puts 0, 1, or -1 into the
	 * destination register based on the results of the comparison.
	 *
	 * Provide a "naninst" instruction that puts 1 or -1 into r3 depending
	 * on what value we'd like to return when one of the operands is NaN.
	 *
	 * The operation we're implementing is:
	 *   if (x == y)
	 *     return 0;
	 *   else if (x < y)
	 *     return -1;
	 *   else if (x > y)
	 *     return 1;
	 *   else
	 *     return {-1,1};  // one or both operands was NaN
	 *
	 * for: cmpl-double, cmpg-double
	 */
	/* op vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_D_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_D_S(f1, r5)			/* f1<- vBB+1 */

	b .LOP_CMPG_DOUBLE_split



/* ------------------------------ */
    .balign 128
.L_OP_CMP_LONG: /* 0x31 */
/* File: powerpc/OP_CMP_LONG.S */
	/*
	 * Compare two 64-bit values.  Puts 0, 1, or -1 into the destination
	 * register based on the results of the comparison.
	 */
	/* cmp-long vAA, vBB, vCC */

	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	lwzux	r5, r6, rFP			/* r5<- vCC, r6<- &fp[CC] */
	lwz	r6, 4(r6)			/* r6<- vCC+1, r5/r6<- vCC/vCC+1 */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	/* comparing high half of the long */
	cmpw	r3,r5
	beq 	0f
	li	r3,1
	bge	1f
	neg	r3,r3
	b	1f				/* done */
	/* perform branch-less (unsigned) r4 > r6 ? 1 : (r4 < r6 ? -1 : 0) */
0:	subf	r5, r6, r4
	subfc	r8, r4, r6 
	subfe	r9, r6, r4 
	subfe	r3, r9, r5 
1:
	SET_VREG_S(r3, r19)			/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_IF_EQ: /* 0x32 */
/* File: powerpc/OP_IF_EQ.S */
/* File: powerpc/bincmp.S */
	/*
	 * Generic two-operand compare-and-branch operation.  Provide a "revcmp"
	 * fragment that specifies the *reverse* comparison to perform, e.g.
	 * for "if-le" you would use "gt".
	 *
	 * For: if-eq, if-ne, if-lt, if-ge, if-gt, if-le
	 */
	/* if-cmp vA, vB, +CCCC */
	rlwinm  r3,rINST,26,26,29		/* r3<- (A+ & 15) << 2 */
	rlwinm  r4,rINST,22,10,29		/* r4<- B << 2 */
	GET_VREG_S(r5, r3)			/* r5<- vA */
	GET_VREG_S(r6, r4)			/* r6<- vB */
	li	r11, 4				/* r11<- BYTE branch dist for not-taken */
	cmpw	r5, r6				/* compare (vA, vB) */
	bne	1f			/* branch to 1 if comparison failed */
	FETCH_S(r11, 1)				/* r11<- branch offset, in code units */
	slwi.	r11, r11, 1			/* convert to bytes, check sign */
 	blt-	common_backwardBranch		/* yes, do periodic checks */
1:	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_IF_NE: /* 0x33 */
/* File: powerpc/OP_IF_NE.S */
/* File: powerpc/bincmp.S */
	/*
	 * Generic two-operand compare-and-branch operation.  Provide a "revcmp"
	 * fragment that specifies the *reverse* comparison to perform, e.g.
	 * for "if-le" you would use "gt".
	 *
	 * For: if-eq, if-ne, if-lt, if-ge, if-gt, if-le
	 */
	/* if-cmp vA, vB, +CCCC */
	rlwinm  r3,rINST,26,26,29		/* r3<- (A+ & 15) << 2 */
	rlwinm  r4,rINST,22,10,29		/* r4<- B << 2 */
	GET_VREG_S(r5, r3)			/* r5<- vA */
	GET_VREG_S(r6, r4)			/* r6<- vB */
	li	r11, 4				/* r11<- BYTE branch dist for not-taken */
	cmpw	r5, r6				/* compare (vA, vB) */
	beq	1f			/* branch to 1 if comparison failed */
	FETCH_S(r11, 1)				/* r11<- branch offset, in code units */
	slwi.	r11, r11, 1			/* convert to bytes, check sign */
 	blt-	common_backwardBranch		/* yes, do periodic checks */
1:	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_IF_LT: /* 0x34 */
/* File: powerpc/OP_IF_LT.S */
/* File: powerpc/bincmp.S */
	/*
	 * Generic two-operand compare-and-branch operation.  Provide a "revcmp"
	 * fragment that specifies the *reverse* comparison to perform, e.g.
	 * for "if-le" you would use "gt".
	 *
	 * For: if-eq, if-ne, if-lt, if-ge, if-gt, if-le
	 */
	/* if-cmp vA, vB, +CCCC */
	rlwinm  r3,rINST,26,26,29		/* r3<- (A+ & 15) << 2 */
	rlwinm  r4,rINST,22,10,29		/* r4<- B << 2 */
	GET_VREG_S(r5, r3)			/* r5<- vA */
	GET_VREG_S(r6, r4)			/* r6<- vB */
	li	r11, 4				/* r11<- BYTE branch dist for not-taken */
	cmpw	r5, r6				/* compare (vA, vB) */
	bge	1f			/* branch to 1 if comparison failed */
	FETCH_S(r11, 1)				/* r11<- branch offset, in code units */
	slwi.	r11, r11, 1			/* convert to bytes, check sign */
 	blt-	common_backwardBranch		/* yes, do periodic checks */
1:	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_IF_GE: /* 0x35 */
/* File: powerpc/OP_IF_GE.S */
/* File: powerpc/bincmp.S */
	/*
	 * Generic two-operand compare-and-branch operation.  Provide a "revcmp"
	 * fragment that specifies the *reverse* comparison to perform, e.g.
	 * for "if-le" you would use "gt".
	 *
	 * For: if-eq, if-ne, if-lt, if-ge, if-gt, if-le
	 */
	/* if-cmp vA, vB, +CCCC */
	rlwinm  r3,rINST,26,26,29		/* r3<- (A+ & 15) << 2 */
	rlwinm  r4,rINST,22,10,29		/* r4<- B << 2 */
	GET_VREG_S(r5, r3)			/* r5<- vA */
	GET_VREG_S(r6, r4)			/* r6<- vB */
	li	r11, 4				/* r11<- BYTE branch dist for not-taken */
	cmpw	r5, r6				/* compare (vA, vB) */
	blt	1f			/* branch to 1 if comparison failed */
	FETCH_S(r11, 1)				/* r11<- branch offset, in code units */
	slwi.	r11, r11, 1			/* convert to bytes, check sign */
 	blt-	common_backwardBranch		/* yes, do periodic checks */
1:	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_IF_GT: /* 0x36 */
/* File: powerpc/OP_IF_GT.S */
/* File: powerpc/bincmp.S */
	/*
	 * Generic two-operand compare-and-branch operation.  Provide a "revcmp"
	 * fragment that specifies the *reverse* comparison to perform, e.g.
	 * for "if-le" you would use "gt".
	 *
	 * For: if-eq, if-ne, if-lt, if-ge, if-gt, if-le
	 */
	/* if-cmp vA, vB, +CCCC */
	rlwinm  r3,rINST,26,26,29		/* r3<- (A+ & 15) << 2 */
	rlwinm  r4,rINST,22,10,29		/* r4<- B << 2 */
	GET_VREG_S(r5, r3)			/* r5<- vA */
	GET_VREG_S(r6, r4)			/* r6<- vB */
	li	r11, 4				/* r11<- BYTE branch dist for not-taken */
	cmpw	r5, r6				/* compare (vA, vB) */
	ble	1f			/* branch to 1 if comparison failed */
	FETCH_S(r11, 1)				/* r11<- branch offset, in code units */
	slwi.	r11, r11, 1			/* convert to bytes, check sign */
 	blt-	common_backwardBranch		/* yes, do periodic checks */
1:	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_IF_LE: /* 0x37 */
/* File: powerpc/OP_IF_LE.S */
/* File: powerpc/bincmp.S */
	/*
	 * Generic two-operand compare-and-branch operation.  Provide a "revcmp"
	 * fragment that specifies the *reverse* comparison to perform, e.g.
	 * for "if-le" you would use "gt".
	 *
	 * For: if-eq, if-ne, if-lt, if-ge, if-gt, if-le
	 */
	/* if-cmp vA, vB, +CCCC */
	rlwinm  r3,rINST,26,26,29		/* r3<- (A+ & 15) << 2 */
	rlwinm  r4,rINST,22,10,29		/* r4<- B << 2 */
	GET_VREG_S(r5, r3)			/* r5<- vA */
	GET_VREG_S(r6, r4)			/* r6<- vB */
	li	r11, 4				/* r11<- BYTE branch dist for not-taken */
	cmpw	r5, r6				/* compare (vA, vB) */
	bgt	1f			/* branch to 1 if comparison failed */
	FETCH_S(r11, 1)				/* r11<- branch offset, in code units */
	slwi.	r11, r11, 1			/* convert to bytes, check sign */
 	blt-	common_backwardBranch		/* yes, do periodic checks */
1:	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_IF_EQZ: /* 0x38 */
/* File: powerpc/OP_IF_EQZ.S */
/* File: powerpc/zcmp.S */
	/*
	 * Generic one-operand compare-and-branch operation.  Provide a "revcmp"
	 * fragment that specifies the *reverse* comparison to perform, e.g.
	 * for "if-le" you would use "gt".
	 *
	 * For: if-eqz, if-nez, if-ltz, if-gez, if-gtz, if-lez
	 */
	/* if-cmp vAA, +BBBB */
	rlwinm	r3,rINST,26,6,29		/* r7<- AA << 2 */
	GET_VREG_S(r5, r3)			/* r5<- vA */
	li	r11, 4				/* r11<- BYTE branch dist for not-taken */
	cmpwi	r5, 0				/* compare (vA, 0) */
	bne	1f			/* branch to 1 if comparison failed */
	FETCH_S(r11, 1)				/* r11<- branch offset, in code units */
	slwi.	r11, r11, 1			/* convert to bytes, check sign */
 	blt-	common_backwardBranch		/* yes, do periodic checks */
1:	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_IF_NEZ: /* 0x39 */
/* File: powerpc/OP_IF_NEZ.S */
/* File: powerpc/zcmp.S */
	/*
	 * Generic one-operand compare-and-branch operation.  Provide a "revcmp"
	 * fragment that specifies the *reverse* comparison to perform, e.g.
	 * for "if-le" you would use "gt".
	 *
	 * For: if-eqz, if-nez, if-ltz, if-gez, if-gtz, if-lez
	 */
	/* if-cmp vAA, +BBBB */
	rlwinm	r3,rINST,26,6,29		/* r7<- AA << 2 */
	GET_VREG_S(r5, r3)			/* r5<- vA */
	li	r11, 4				/* r11<- BYTE branch dist for not-taken */
	cmpwi	r5, 0				/* compare (vA, 0) */
	beq	1f			/* branch to 1 if comparison failed */
	FETCH_S(r11, 1)				/* r11<- branch offset, in code units */
	slwi.	r11, r11, 1			/* convert to bytes, check sign */
 	blt-	common_backwardBranch		/* yes, do periodic checks */
1:	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_IF_LTZ: /* 0x3a */
/* File: powerpc/OP_IF_LTZ.S */
/* File: powerpc/zcmp.S */
	/*
	 * Generic one-operand compare-and-branch operation.  Provide a "revcmp"
	 * fragment that specifies the *reverse* comparison to perform, e.g.
	 * for "if-le" you would use "gt".
	 *
	 * For: if-eqz, if-nez, if-ltz, if-gez, if-gtz, if-lez
	 */
	/* if-cmp vAA, +BBBB */
	rlwinm	r3,rINST,26,6,29		/* r7<- AA << 2 */
	GET_VREG_S(r5, r3)			/* r5<- vA */
	li	r11, 4				/* r11<- BYTE branch dist for not-taken */
	cmpwi	r5, 0				/* compare (vA, 0) */
	bge	1f			/* branch to 1 if comparison failed */
	FETCH_S(r11, 1)				/* r11<- branch offset, in code units */
	slwi.	r11, r11, 1			/* convert to bytes, check sign */
 	blt-	common_backwardBranch		/* yes, do periodic checks */
1:	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_IF_GEZ: /* 0x3b */
/* File: powerpc/OP_IF_GEZ.S */
/* File: powerpc/zcmp.S */
	/*
	 * Generic one-operand compare-and-branch operation.  Provide a "revcmp"
	 * fragment that specifies the *reverse* comparison to perform, e.g.
	 * for "if-le" you would use "gt".
	 *
	 * For: if-eqz, if-nez, if-ltz, if-gez, if-gtz, if-lez
	 */
	/* if-cmp vAA, +BBBB */
	rlwinm	r3,rINST,26,6,29		/* r7<- AA << 2 */
	GET_VREG_S(r5, r3)			/* r5<- vA */
	li	r11, 4				/* r11<- BYTE branch dist for not-taken */
	cmpwi	r5, 0				/* compare (vA, 0) */
	blt	1f			/* branch to 1 if comparison failed */
	FETCH_S(r11, 1)				/* r11<- branch offset, in code units */
	slwi.	r11, r11, 1			/* convert to bytes, check sign */
 	blt-	common_backwardBranch		/* yes, do periodic checks */
1:	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_IF_GTZ: /* 0x3c */
/* File: powerpc/OP_IF_GTZ.S */
/* File: powerpc/zcmp.S */
	/*
	 * Generic one-operand compare-and-branch operation.  Provide a "revcmp"
	 * fragment that specifies the *reverse* comparison to perform, e.g.
	 * for "if-le" you would use "gt".
	 *
	 * For: if-eqz, if-nez, if-ltz, if-gez, if-gtz, if-lez
	 */
	/* if-cmp vAA, +BBBB */
	rlwinm	r3,rINST,26,6,29		/* r7<- AA << 2 */
	GET_VREG_S(r5, r3)			/* r5<- vA */
	li	r11, 4				/* r11<- BYTE branch dist for not-taken */
	cmpwi	r5, 0				/* compare (vA, 0) */
	ble	1f			/* branch to 1 if comparison failed */
	FETCH_S(r11, 1)				/* r11<- branch offset, in code units */
	slwi.	r11, r11, 1			/* convert to bytes, check sign */
 	blt-	common_backwardBranch		/* yes, do periodic checks */
1:	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_IF_LEZ: /* 0x3d */
/* File: powerpc/OP_IF_LEZ.S */
/* File: powerpc/zcmp.S */
	/*
	 * Generic one-operand compare-and-branch operation.  Provide a "revcmp"
	 * fragment that specifies the *reverse* comparison to perform, e.g.
	 * for "if-le" you would use "gt".
	 *
	 * For: if-eqz, if-nez, if-ltz, if-gez, if-gtz, if-lez
	 */
	/* if-cmp vAA, +BBBB */
	rlwinm	r3,rINST,26,6,29		/* r7<- AA << 2 */
	GET_VREG_S(r5, r3)			/* r5<- vA */
	li	r11, 4				/* r11<- BYTE branch dist for not-taken */
	cmpwi	r5, 0				/* compare (vA, 0) */
	bgt	1f			/* branch to 1 if comparison failed */
	FETCH_S(r11, 1)				/* r11<- branch offset, in code units */
	slwi.	r11, r11, 1			/* convert to bytes, check sign */
 	blt-	common_backwardBranch		/* yes, do periodic checks */
1:	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_3E: /* 0x3e */
/* File: powerpc/OP_UNUSED_3E.S */
/* File: powerpc/unused.S */
	b	common_abort


/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_3F: /* 0x3f */
/* File: powerpc/OP_UNUSED_3F.S */
/* File: powerpc/unused.S */
	b	common_abort


/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_40: /* 0x40 */
/* File: powerpc/OP_UNUSED_40.S */
/* File: powerpc/unused.S */
	b	common_abort


/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_41: /* 0x41 */
/* File: powerpc/OP_UNUSED_41.S */
/* File: powerpc/unused.S */
	b	common_abort


/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_42: /* 0x42 */
/* File: powerpc/OP_UNUSED_42.S */
/* File: powerpc/unused.S */
	b	common_abort


/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_43: /* 0x43 */
/* File: powerpc/OP_UNUSED_43.S */
/* File: powerpc/unused.S */
	b	common_abort


/* ------------------------------ */
    .balign 128
.L_OP_AGET: /* 0x44 */
/* File: powerpc/OP_AGET.S */
	/*
	 * Array get, 32 bits or less.  vAA <- vBB[vCC].
	 *
	 * for: aget, aget-object, aget-boolean, aget-byte, aget-char, aget-short
	 */
	/* op vAA, vBB, vCC */

	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC (requested index) */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r3, 0				/* null array object? */
	beq-	common_errNullObject		/* yes, bail */
	lwz	r6, offArrayObject_length(r3)	/* r6<- arrayObj->length */
	cmplw	r4, r6				/* compare unsigned index, length */
	bge-	common_errArrayIndex		/* index >= length, bail */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	.if 2 > 0
	slwi	r4, r4, 2			/* r4<- index*width */
	.endif
	add     r3, r3, r4			/* r3<- arrayObj + index*width */
	lwz   r5, offArrayObject_contents(r3)	/* r5<- vBB[vCC] */
	.ifnb 
		r5, r5				/* extend sign if requested */
	.endif

	SET_VREG_S(r5, r19)			/* vAA<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* ------------------------------ */
    .balign 128
.L_OP_AGET_WIDE: /* 0x45 */
/* File: powerpc/OP_AGET_WIDE.S */
	/*
	 * Array get, 64 bits.  vAA <- vBB[vCC].
	 */
	/* op vAA, vBB, vCC */

	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC (requested index) */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r3, 0				/* null array object? */
	beq-	common_errNullObject		/* yes, bail */
	lwz	r6, offArrayObject_length(r3)	/* r6<- arrayObj->length */
	cmplw	r4, r6				/* compare unsigned index, length */
	bge-	common_errArrayIndex		/* index >= length, bail */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	slwi	r4, r4, 3			/* r4<- index*width */
	add     r3, r3, r4			/* r3<- arrayObj + index*width */
	lwz	r5, offArrayObject_contents(r3)	/* r5<- vBB[vCC] (hi) */
	lwz	r6, offArrayObject_contents+4(r3)	/* r6<- vBB[vCC] (lo) */

	stwux	r5, r19, rFP			/* vAA<- r5, r19<- &fp[AA] */
	stw	r6, 4(r19)			/* vAA+1<- r6 */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* ------------------------------ */
    .balign 128
.L_OP_AGET_OBJECT: /* 0x46 */
/* File: powerpc/OP_AGET_OBJECT.S */
/* File: powerpc/OP_AGET.S */
	/*
	 * Array get, 32 bits or less.  vAA <- vBB[vCC].
	 *
	 * for: aget, aget-object, aget-boolean, aget-byte, aget-char, aget-short
	 */
	/* op vAA, vBB, vCC */

	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC (requested index) */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r3, 0				/* null array object? */
	beq-	common_errNullObject		/* yes, bail */
	lwz	r6, offArrayObject_length(r3)	/* r6<- arrayObj->length */
	cmplw	r4, r6				/* compare unsigned index, length */
	bge-	common_errArrayIndex		/* index >= length, bail */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	.if 2 > 0
	slwi	r4, r4, 2			/* r4<- index*width */
	.endif
	add     r3, r3, r4			/* r3<- arrayObj + index*width */
	lwz   r5, offArrayObject_contents(r3)	/* r5<- vBB[vCC] */
	.ifnb 
		r5, r5				/* extend sign if requested */
	.endif

	SET_VREG_S(r5, r19)			/* vAA<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_AGET_BOOLEAN: /* 0x47 */
/* File: powerpc/OP_AGET_BOOLEAN.S */
/* File: powerpc/OP_AGET.S */
	/*
	 * Array get, 32 bits or less.  vAA <- vBB[vCC].
	 *
	 * for: aget, aget-object, aget-boolean, aget-byte, aget-char, aget-short
	 */
	/* op vAA, vBB, vCC */

	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC (requested index) */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r3, 0				/* null array object? */
	beq-	common_errNullObject		/* yes, bail */
	lwz	r6, offArrayObject_length(r3)	/* r6<- arrayObj->length */
	cmplw	r4, r6				/* compare unsigned index, length */
	bge-	common_errArrayIndex		/* index >= length, bail */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	.if 0 > 0
	slwi	r4, r4, 0			/* r4<- index*width */
	.endif
	add     r3, r3, r4			/* r3<- arrayObj + index*width */
	lbz   r5, offArrayObject_contents(r3)	/* r5<- vBB[vCC] */
	.ifnb 
		r5, r5				/* extend sign if requested */
	.endif

	SET_VREG_S(r5, r19)			/* vAA<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_AGET_BYTE: /* 0x48 */
/* File: powerpc/OP_AGET_BYTE.S */
/* File: powerpc/OP_AGET.S */
	/*
	 * Array get, 32 bits or less.  vAA <- vBB[vCC].
	 *
	 * for: aget, aget-object, aget-boolean, aget-byte, aget-char, aget-short
	 */
	/* op vAA, vBB, vCC */

	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC (requested index) */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r3, 0				/* null array object? */
	beq-	common_errNullObject		/* yes, bail */
	lwz	r6, offArrayObject_length(r3)	/* r6<- arrayObj->length */
	cmplw	r4, r6				/* compare unsigned index, length */
	bge-	common_errArrayIndex		/* index >= length, bail */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	.if 0 > 0
	slwi	r4, r4, 0			/* r4<- index*width */
	.endif
	add     r3, r3, r4			/* r3<- arrayObj + index*width */
	lbz   r5, offArrayObject_contents(r3)	/* r5<- vBB[vCC] */
	.ifnb extsb
	extsb	r5, r5				/* extend sign if requested */
	.endif

	SET_VREG_S(r5, r19)			/* vAA<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_AGET_CHAR: /* 0x49 */
/* File: powerpc/OP_AGET_CHAR.S */
/* File: powerpc/OP_AGET.S */
	/*
	 * Array get, 32 bits or less.  vAA <- vBB[vCC].
	 *
	 * for: aget, aget-object, aget-boolean, aget-byte, aget-char, aget-short
	 */
	/* op vAA, vBB, vCC */

	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC (requested index) */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r3, 0				/* null array object? */
	beq-	common_errNullObject		/* yes, bail */
	lwz	r6, offArrayObject_length(r3)	/* r6<- arrayObj->length */
	cmplw	r4, r6				/* compare unsigned index, length */
	bge-	common_errArrayIndex		/* index >= length, bail */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	.if 1 > 0
	slwi	r4, r4, 1			/* r4<- index*width */
	.endif
	add     r3, r3, r4			/* r3<- arrayObj + index*width */
	lhz   r5, offArrayObject_contents(r3)	/* r5<- vBB[vCC] */
	.ifnb 
		r5, r5				/* extend sign if requested */
	.endif

	SET_VREG_S(r5, r19)			/* vAA<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_AGET_SHORT: /* 0x4a */
/* File: powerpc/OP_AGET_SHORT.S */
/* File: powerpc/OP_AGET.S */
	/*
	 * Array get, 32 bits or less.  vAA <- vBB[vCC].
	 *
	 * for: aget, aget-object, aget-boolean, aget-byte, aget-char, aget-short
	 */
	/* op vAA, vBB, vCC */

	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC (requested index) */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r3, 0				/* null array object? */
	beq-	common_errNullObject		/* yes, bail */
	lwz	r6, offArrayObject_length(r3)	/* r6<- arrayObj->length */
	cmplw	r4, r6				/* compare unsigned index, length */
	bge-	common_errArrayIndex		/* index >= length, bail */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	.if 1 > 0
	slwi	r4, r4, 1			/* r4<- index*width */
	.endif
	add     r3, r3, r4			/* r3<- arrayObj + index*width */
	lha   r5, offArrayObject_contents(r3)	/* r5<- vBB[vCC] */
	.ifnb 
		r5, r5				/* extend sign if requested */
	.endif

	SET_VREG_S(r5, r19)			/* vAA<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_APUT: /* 0x4b */
/* File: powerpc/OP_APUT.S */
	/*
	 * Array put, 32 bits or less.  vBB[vCC] <- vAA.
	 *
	 * for: aput, aput-boolean, aput-byte, aput-char, aput-short
	 */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC (requested index) */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r3, 0				/* null array object? */
	beq-	common_errNullObject		/* yes, bail */
	lwz	r6, offArrayObject_length(r3)	/* r6<- arrayObj->length */
	cmplw	r4, r6				/* compare unsigned index, length */
	bge-	common_errArrayIndex		/* index >= length, bail */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	.if 2 > 0
	slwi	r4, r4, 2			/* r4<- index*width */
	.endif
	add     r3, r3, r4			/* r3<- arrayObj + index*width */
	GET_VREG_S(r5, r19)			/* vAA<- r5 */
	stw   r5, offArrayObject_contents(r3) /* r5<- vBB[vCC] */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* ------------------------------ */
    .balign 128
.L_OP_APUT_WIDE: /* 0x4c */
/* File: powerpc/OP_APUT_WIDE.S */
	/*
	 * Array put, 64 bits.  vBB[vCC] <- vAA.
	 */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC (requested index) */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r3, 0				/* null array object? */
	beq-	common_errNullObject		/* yes, bail */
	lwz	r6, offArrayObject_length(r3)	/* r6<- arrayObj->length */
	cmplw	r4, r6				/* compare unsigned index, length */
	bge-	common_errArrayIndex		/* index >= length, bail */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	slwi	r4, r4, 3			/* r4<- index*width */
	add     r3, r3, r4			/* r3<- arrayObj + index*width */
	lwzux	r5, r19, rFP			/* r5<- */
	lwz	r6, 4(r19)			/* vAA<- */
	stw	r5, offArrayObject_contents(r3) /* r5<- vBB[vCC] hi */
	stw	r6, offArrayObject_contents+4(r3)	/* lo */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* ------------------------------ */
    .balign 128
.L_OP_APUT_OBJECT: /* 0x4d */
/* File: powerpc/OP_APUT_OBJECT.S */
	/*
	 * Array put object
	 *
	 */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC (requested index) */
	GET_VREG_S(r21, r5)			/* r21<- vBB */

	cmpwi	r21, 0				/* null array object? */
	beq-	common_errNullObject		/* yes, bail */
	lwz	r6, offArrayObject_length(r21)	/* r6<- arrayObj->length */
	cmplw	r4, r6				/* compare unsigned index, length */
	bge-	common_errArrayIndex		/* index >= length, bail */

	/* r21 = vBB, r4 = vCC, r19 = vAA << 2 */
	slwi	r4, r4, 2			/* r4<- index*width */
	add     r20, r21, r4			/* r20<- arrayObj + index*width */
	GET_VREG_S(r19, r19)			/* vAA<- r19 */

	cmpwi	r19, 0				/* storing null reference? */
	beq-	.LOP_APUT_OBJECT_skip_check		/* yes, skip type checks */
	b .LOP_APUT_OBJECT_finish

/* ------------------------------ */
    .balign 128
.L_OP_APUT_BOOLEAN: /* 0x4e */
/* File: powerpc/OP_APUT_BOOLEAN.S */
/* File: powerpc/OP_APUT.S */
	/*
	 * Array put, 32 bits or less.  vBB[vCC] <- vAA.
	 *
	 * for: aput, aput-boolean, aput-byte, aput-char, aput-short
	 */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC (requested index) */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r3, 0				/* null array object? */
	beq-	common_errNullObject		/* yes, bail */
	lwz	r6, offArrayObject_length(r3)	/* r6<- arrayObj->length */
	cmplw	r4, r6				/* compare unsigned index, length */
	bge-	common_errArrayIndex		/* index >= length, bail */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	.if 0 > 0
	slwi	r4, r4, 0			/* r4<- index*width */
	.endif
	add     r3, r3, r4			/* r3<- arrayObj + index*width */
	GET_VREG_S(r5, r19)			/* vAA<- r5 */
	stb   r5, offArrayObject_contents(r3) /* r5<- vBB[vCC] */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_APUT_BYTE: /* 0x4f */
/* File: powerpc/OP_APUT_BYTE.S */
/* File: powerpc/OP_APUT.S */
	/*
	 * Array put, 32 bits or less.  vBB[vCC] <- vAA.
	 *
	 * for: aput, aput-boolean, aput-byte, aput-char, aput-short
	 */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC (requested index) */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r3, 0				/* null array object? */
	beq-	common_errNullObject		/* yes, bail */
	lwz	r6, offArrayObject_length(r3)	/* r6<- arrayObj->length */
	cmplw	r4, r6				/* compare unsigned index, length */
	bge-	common_errArrayIndex		/* index >= length, bail */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	.if 0 > 0
	slwi	r4, r4, 0			/* r4<- index*width */
	.endif
	add     r3, r3, r4			/* r3<- arrayObj + index*width */
	GET_VREG_S(r5, r19)			/* vAA<- r5 */
	stb   r5, offArrayObject_contents(r3) /* r5<- vBB[vCC] */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_APUT_CHAR: /* 0x50 */
/* File: powerpc/OP_APUT_CHAR.S */
/* File: powerpc/OP_APUT.S */
	/*
	 * Array put, 32 bits or less.  vBB[vCC] <- vAA.
	 *
	 * for: aput, aput-boolean, aput-byte, aput-char, aput-short
	 */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC (requested index) */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r3, 0				/* null array object? */
	beq-	common_errNullObject		/* yes, bail */
	lwz	r6, offArrayObject_length(r3)	/* r6<- arrayObj->length */
	cmplw	r4, r6				/* compare unsigned index, length */
	bge-	common_errArrayIndex		/* index >= length, bail */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	.if 1 > 0
	slwi	r4, r4, 1			/* r4<- index*width */
	.endif
	add     r3, r3, r4			/* r3<- arrayObj + index*width */
	GET_VREG_S(r5, r19)			/* vAA<- r5 */
	sth   r5, offArrayObject_contents(r3) /* r5<- vBB[vCC] */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_APUT_SHORT: /* 0x51 */
/* File: powerpc/OP_APUT_SHORT.S */
/* File: powerpc/OP_APUT.S */
	/*
	 * Array put, 32 bits or less.  vBB[vCC] <- vAA.
	 *
	 * for: aput, aput-boolean, aput-byte, aput-char, aput-short
	 */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC (requested index) */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r3, 0				/* null array object? */
	beq-	common_errNullObject		/* yes, bail */
	lwz	r6, offArrayObject_length(r3)	/* r6<- arrayObj->length */
	cmplw	r4, r6				/* compare unsigned index, length */
	bge-	common_errArrayIndex		/* index >= length, bail */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	.if 1 > 0
	slwi	r4, r4, 1			/* r4<- index*width */
	.endif
	add     r3, r3, r4			/* r3<- arrayObj + index*width */
	GET_VREG_S(r5, r19)			/* vAA<- r5 */
	sth   r5, offArrayObject_contents(r3) /* r5<- vBB[vCC] */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_IGET: /* 0x52 */
/* File: powerpc/OP_IGET.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r3, offInstField_byteOffset(r3)	/* r3<- byte offset of field */
	lwzx	r3, r20, r3			/* r3<- obj.field (8/16/32 bits) */
	/* no-op */				/* acquiring load */
	.ifnb 
						/* perform masking (if requested) */
	.endif
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_IGET_WIDE: /* 0x53 */
/* File: powerpc/OP_IGET_WIDE.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r3, offInstField_byteOffset(r3)	/* r3<- byte offset of field */
	.if	0
	add	r3, r20, r3
	bl	dvmQuasiAtomicRead64@plt
	.else
	lwzux	r3, r20, r3			/* r3<- obj.field (8/16/32 bits) */
	lwz	r4, 4(r20)			/* r4 (lo) */
	.endif
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	stwux	r3, r19, rFP			/* fp[A]<- r3 (hi) */
	stw	r4, 4(r19)			/* <- r4 (lo) */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_IGET_OBJECT: /* 0x54 */
/* File: powerpc/OP_IGET_OBJECT.S */
/* File: powerpc/OP_IGET.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r3, offInstField_byteOffset(r3)	/* r3<- byte offset of field */
	lwzx	r3, r20, r3			/* r3<- obj.field (8/16/32 bits) */
	/* no-op */				/* acquiring load */
	.ifnb 
						/* perform masking (if requested) */
	.endif
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_IGET_BOOLEAN: /* 0x55 */
/* File: powerpc/OP_IGET_BOOLEAN.S */
/* File: powerpc/OP_IGET.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r3, offInstField_byteOffset(r3)	/* r3<- byte offset of field */
	lwzx	r3, r20, r3			/* r3<- obj.field (8/16/32 bits) */
	/* no-op */				/* acquiring load */
	.ifnb clrlwi	r3, r3, 24
	clrlwi	r3, r3, 24					/* perform masking (if requested) */
	.endif
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_IGET_BYTE: /* 0x56 */
/* File: powerpc/OP_IGET_BYTE.S */
/* File: powerpc/OP_IGET.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r3, offInstField_byteOffset(r3)	/* r3<- byte offset of field */
	lwzx	r3, r20, r3			/* r3<- obj.field (8/16/32 bits) */
	/* no-op */				/* acquiring load */
	.ifnb extsb	r3, r3
	extsb	r3, r3					/* perform masking (if requested) */
	.endif
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_IGET_CHAR: /* 0x57 */
/* File: powerpc/OP_IGET_CHAR.S */
/* File: powerpc/OP_IGET.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r3, offInstField_byteOffset(r3)	/* r3<- byte offset of field */
	lwzx	r3, r20, r3			/* r3<- obj.field (8/16/32 bits) */
	/* no-op */				/* acquiring load */
	.ifnb clrlwi	r3, r3, 16
	clrlwi	r3, r3, 16					/* perform masking (if requested) */
	.endif
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_IGET_SHORT: /* 0x58 */
/* File: powerpc/OP_IGET_SHORT.S */
/* File: powerpc/OP_IGET.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r3, offInstField_byteOffset(r3)	/* r3<- byte offset of field */
	lwzx	r3, r20, r3			/* r3<- obj.field (8/16/32 bits) */
	/* no-op */				/* acquiring load */
	.ifnb extsh	r3, r3
	extsh	r3, r3					/* perform masking (if requested) */
	.endif
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_IPUT: /* 0x59 */
/* File: powerpc/OP_IPUT.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iput, iput-boolean, iput-byte, iput-char, iput-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r4, offInstField_byteOffset(r3)	/* r4<- byte offset of field */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_VREG_S(r3, r19)			/* fp[A]<- r3 */
	.ifnb 
						/* perform masking (if requested) */
	.endif
	/* no-op */				/* releasing store */
	stwx	r3, r20, r4			/* r4<- obj.field (8/16/32 bits) */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_IPUT_WIDE: /* 0x5a */
/* File: powerpc/OP_IPUT_WIDE.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r5, offInstField_byteOffset(r3)	/* r4<- byte offset of field */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	lwzux	r3, r19, rFP			/* r3<-fp[A] (hi) */
	lwz	r4, 4(r19)			/* lo */
	.if 0
	add	r5, r20, r5
	bl	dvmQuasiAtomicSwap64@plt
	.else
	stwux	r3, r20, r5			/* obj.field(64 bits) <- r3 (hi)  */
	stw	r4, 4(r20)			/* lo */
	.endif
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_IPUT_OBJECT: /* 0x5b */
/* File: powerpc/OP_IPUT_OBJECT.S */
	/*
	 * Object field put
	 *
	 * for: iput-object
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r4, offInstField_byteOffset(r3)	/* r4<- byte offset of field */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_VREG_S(r3, r19)			/* fp[A]<- r3 */
	/* no-op */
	stwx	r3, r20, r4			/* obj.field (32 bits) <- r3 */
	lwz	r5, offGlue_cardTable(rGLUE)	/* r5<- card table base */
	rlwinm	r20, r20, 32-GC_CARD_SHIFT, GC_CARD_SHIFT, 31
	cmpwi	r3, 0				/* stored a null reference ? */
	beq- 1f
	stbx	r5, r5, r20			/* mark card if not zero */
1:
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_IPUT_BOOLEAN: /* 0x5c */
/* File: powerpc/OP_IPUT_BOOLEAN.S */
/* File: powerpc/OP_IPUT.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iput, iput-boolean, iput-byte, iput-char, iput-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r4, offInstField_byteOffset(r3)	/* r4<- byte offset of field */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_VREG_S(r3, r19)			/* fp[A]<- r3 */
	.ifnb clrlwi	r3, r3, 24
	clrlwi	r3, r3, 24					/* perform masking (if requested) */
	.endif
	/* no-op */				/* releasing store */
	stwx	r3, r20, r4			/* r4<- obj.field (8/16/32 bits) */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_IPUT_BYTE: /* 0x5d */
/* File: powerpc/OP_IPUT_BYTE.S */
/* File: powerpc/OP_IPUT.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iput, iput-boolean, iput-byte, iput-char, iput-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r4, offInstField_byteOffset(r3)	/* r4<- byte offset of field */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_VREG_S(r3, r19)			/* fp[A]<- r3 */
	.ifnb extsb	r3, r3
	extsb	r3, r3					/* perform masking (if requested) */
	.endif
	/* no-op */				/* releasing store */
	stwx	r3, r20, r4			/* r4<- obj.field (8/16/32 bits) */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_IPUT_CHAR: /* 0x5e */
/* File: powerpc/OP_IPUT_CHAR.S */
/* File: powerpc/OP_IPUT.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iput, iput-boolean, iput-byte, iput-char, iput-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r4, offInstField_byteOffset(r3)	/* r4<- byte offset of field */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_VREG_S(r3, r19)			/* fp[A]<- r3 */
	.ifnb clrlwi	r3, r3, 16
	clrlwi	r3, r3, 16					/* perform masking (if requested) */
	.endif
	/* no-op */				/* releasing store */
	stwx	r3, r20, r4			/* r4<- obj.field (8/16/32 bits) */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_IPUT_SHORT: /* 0x5f */
/* File: powerpc/OP_IPUT_SHORT.S */
/* File: powerpc/OP_IPUT.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iput, iput-boolean, iput-byte, iput-char, iput-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r4, offInstField_byteOffset(r3)	/* r4<- byte offset of field */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_VREG_S(r3, r19)			/* fp[A]<- r3 */
	.ifnb extsh	r3, r3
	extsh	r3, r3					/* perform masking (if requested) */
	.endif
	/* no-op */				/* releasing store */
	stwx	r3, r20, r4			/* r4<- obj.field (8/16/32 bits) */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_SGET: /* 0x60 */
/* File: powerpc/OP_SGET.S */
	/*
	 * General 32-bit SGET handler.
	 *
	 * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwz	r3, offStaticField_value(r3)	/* r3<- byte offset of field */
	/* no-op */				/* acquiring load */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	.ifnb 
	
	.endif
	stwx	r3, r19, rFP			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_SGET_WIDE: /* 0x61 */
/* File: powerpc/OP_SGET_WIDE.S */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved StaticField ptr */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	
	.if	0
	addi	r3, r3, offStaticField_value
	bl	dvmQuasiAtomicRead64@plt
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	stwux	r3, r19, rFP			/* fp[A]<- r3 */
	stw	r4, 4(r19)
	.else
	lwz	r4, offStaticField_value(r3)
	lwz	r5, offStaticField_value+4(r3)
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	stwux	r4, r19, rFP			/* fp[A]<- r3 */
	stw	r5, 4(r19)
	.endif
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_SGET_OBJECT: /* 0x62 */
/* File: powerpc/OP_SGET_OBJECT.S */
/* File: powerpc/OP_SGET.S */
	/*
	 * General 32-bit SGET handler.
	 *
	 * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwz	r3, offStaticField_value(r3)	/* r3<- byte offset of field */
	/* no-op */				/* acquiring load */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	.ifnb 
	
	.endif
	stwx	r3, r19, rFP			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_SGET_BOOLEAN: /* 0x63 */
/* File: powerpc/OP_SGET_BOOLEAN.S */
/* File: powerpc/OP_SGET.S */
	/*
	 * General 32-bit SGET handler.
	 *
	 * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwz	r3, offStaticField_value(r3)	/* r3<- byte offset of field */
	/* no-op */				/* acquiring load */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	.ifnb clrlwi	r3, r3, 24
	clrlwi	r3, r3, 24
	.endif
	stwx	r3, r19, rFP			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_SGET_BYTE: /* 0x64 */
/* File: powerpc/OP_SGET_BYTE.S */
/* File: powerpc/OP_SGET.S */
	/*
	 * General 32-bit SGET handler.
	 *
	 * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwz	r3, offStaticField_value(r3)	/* r3<- byte offset of field */
	/* no-op */				/* acquiring load */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	.ifnb extsb	r3, r3
	extsb	r3, r3
	.endif
	stwx	r3, r19, rFP			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_SGET_CHAR: /* 0x65 */
/* File: powerpc/OP_SGET_CHAR.S */
/* File: powerpc/OP_SGET.S */
	/*
	 * General 32-bit SGET handler.
	 *
	 * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwz	r3, offStaticField_value(r3)	/* r3<- byte offset of field */
	/* no-op */				/* acquiring load */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	.ifnb clrlwi	r3, r3, 16
	clrlwi	r3, r3, 16
	.endif
	stwx	r3, r19, rFP			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_SGET_SHORT: /* 0x66 */
/* File: powerpc/OP_SGET_SHORT.S */
/* File: powerpc/OP_SGET.S */
	/*
	 * General 32-bit SGET handler.
	 *
	 * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwz	r3, offStaticField_value(r3)	/* r3<- byte offset of field */
	/* no-op */				/* acquiring load */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	.ifnb extsh	r3, r3
	extsh	r3, r3
	.endif
	stwx	r3, r19, rFP			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_SPUT: /* 0x67 */
/* File: powerpc/OP_SPUT.S */
	/*
	 * General 32-bit SPUT handler.
	 *
	 * for: sput, sput-boolean, sput-byte, sput-char, sput-short
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved StaticField ptr */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwzx	r4, r19, rFP			/* r3<- fp[A] */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	.ifnb 
	
	.endif
	/* no-op */				/* releasing store */
	stw	r4, offStaticField_value(r3)	/* field<- vAA */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_SPUT_WIDE: /* 0x68 */
/* File: powerpc/OP_SPUT_WIDE.S */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved StaticField ptr */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:
	.if	0
	addi	r5, r3, offStaticField_value
	lwzux	r3, r19, rFP			/* r3<- fp[A] */
	lwz	r4, 4(r19)
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	bl	dvmQuasiAtomicSwap64@plt
	.else
	lwzux	r4, r19, rFP			/* r4<- fp[A] */
	lwz	r5, 4(r19)
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	stw	r4, offStaticField_value(r3)	/* (hi) byte offset of field */
	stw	r5, offStaticField_value+4(r3)	/* (lo)  */
	.endif
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_SPUT_OBJECT: /* 0x69 */
/* File: powerpc/OP_SPUT_OBJECT.S */
	/*
	 * 32-bit SPUT handler for objects
	 *
	 * for: sput-object
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved StaticField ptr */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwzx	r4, r19, rFP			/* r3<- fp[A] */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	stw	r4, offStaticField_value(r3)	/* field<- vAA */
	lwz	r20, offField_clazz(r3)
	lwz	r5, offGlue_cardTable(rGLUE)	/* r5<- card table base */
	rlwinm	r20, r20, 32-GC_CARD_SHIFT, GC_CARD_SHIFT, 31
	cmpwi	r4, 0				/* stored a null reference ? */
	beq- 1f
	stbx	r5, r5, r20			/* mark card if not zero */
1:
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_SPUT_BOOLEAN: /* 0x6a */
/* File: powerpc/OP_SPUT_BOOLEAN.S */
/* File: powerpc/OP_SPUT.S */
	/*
	 * General 32-bit SPUT handler.
	 *
	 * for: sput, sput-boolean, sput-byte, sput-char, sput-short
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved StaticField ptr */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwzx	r4, r19, rFP			/* r3<- fp[A] */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	.ifnb clrlwi	r4, r4, 24
	clrlwi	r4, r4, 24
	.endif
	/* no-op */				/* releasing store */
	stw	r4, offStaticField_value(r3)	/* field<- vAA */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_SPUT_BYTE: /* 0x6b */
/* File: powerpc/OP_SPUT_BYTE.S */
/* File: powerpc/OP_SPUT.S */
	/*
	 * General 32-bit SPUT handler.
	 *
	 * for: sput, sput-boolean, sput-byte, sput-char, sput-short
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved StaticField ptr */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwzx	r4, r19, rFP			/* r3<- fp[A] */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	.ifnb extsb	r4, r4
	extsb	r4, r4
	.endif
	/* no-op */				/* releasing store */
	stw	r4, offStaticField_value(r3)	/* field<- vAA */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_SPUT_CHAR: /* 0x6c */
/* File: powerpc/OP_SPUT_CHAR.S */
/* File: powerpc/OP_SPUT.S */
	/*
	 * General 32-bit SPUT handler.
	 *
	 * for: sput, sput-boolean, sput-byte, sput-char, sput-short
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved StaticField ptr */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwzx	r4, r19, rFP			/* r3<- fp[A] */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	.ifnb clrlwi	r4, r4, 16
	clrlwi	r4, r4, 16
	.endif
	/* no-op */				/* releasing store */
	stw	r4, offStaticField_value(r3)	/* field<- vAA */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_SPUT_SHORT: /* 0x6d */
/* File: powerpc/OP_SPUT_SHORT.S */
/* File: powerpc/OP_SPUT.S */
	/*
	 * General 32-bit SPUT handler.
	 *
	 * for: sput, sput-boolean, sput-byte, sput-char, sput-short
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved StaticField ptr */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwzx	r4, r19, rFP			/* r3<- fp[A] */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	.ifnb extsh	r4, r4
	extsh	r4, r4
	.endif
	/* no-op */				/* releasing store */
	stw	r4, offStaticField_value(r3)	/* field<- vAA */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_VIRTUAL: /* 0x6e */
/* File: powerpc/OP_INVOKE_VIRTUAL.S */
	/*
	 * Handle a virtual method call.
	 *
	 * for: invoke-virtual, invoke-virtual/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op vAA, {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	FETCH(r19, 2)				/* r19<- GFED or CCCC */
	.if	(!0)
	rlwinm  r19,r19,2,26,29			/* r19<- D << 2 */
	.else
	slwi	r19, r19, 2			/* r19<- CCCC << 2 */
	.endif
	slwi	r5, r4, 2			/* r5<- r4 << 2 */
	EXPORT_PC()				/* must export for invoke */
	GET_VREG_S(r20, r19)			/* r20<- "this" ptr */
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r6, offDvmDex_pResMethods(r6)	/* r6<- pDvmDex->pResMethods */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
	cmpwi	r3, 0				/* already resolved? */
	bne+	0f				/* resolved?, yes */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	li	r5, METHOD_VIRTUAL		/* resolver method type */
	bl	dvmResolveMethod@plt		/* r3<- call(clazz, ref, flags) */
	cmpwi	r3, 0				/* got null? */
	beq-	common_exceptionThrown		/* yes, handle exception */
0:	cmpwi	r20, 0				/* null "this" ref? */
	beq- 	common_errNullObject		/* yes, throw exception */
	lwz	r6, offObject_clazz(r20)	/* r6<- thisPtr->clazz */
	lwz	r6, offClassObject_vtable(r6)	/* r6<- thisPtr->clazz->vtable */
	lhz	r5, offMethod_methodIndex(r3)	/* r5<- baseMethod->methodIndex */
	slwi	r5, r5, 2			/* r5<- baseMethod->methodIndex << 2 */
	lwzx	r3, r6, r5			/* r3<- vtable[methodIndex] */
	b	common_invokeMethodNoRange	/* no, continue on */

/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_SUPER: /* 0x6f */
/* File: powerpc/OP_INVOKE_SUPER.S */
	/*
	 * Handle a "super" method call.
	 *
	 * for: invoke-super, invoke-super/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op vAA, {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	FETCH(r19, 2)				/* r19<- GFED or CCCC */
	.if	(!0)
	rlwinm  r19,r19,2,26,29			/* r19<- D << 2 */
	.else
	slwi	r19, r19, 2			/* r19<- CCCC << 2 */
	.endif
	slwi	r5, r4, 2			/* r5<- r4 << 2 */
	GET_VREG_S(r20, r19)			/* r20<- "this" ptr */
	EXPORT_PC()				/* must export for invoke */
	cmpwi	r20, 0				/* null "this"? */
	beq-	common_errNullObject		/* null "this", throw exception */
	lwz	r21, offGlue_method(rGLUE)	/* r21<- glue->method */
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r21, offMethod_clazz(r21)	/* r21<- method->clazz */
	lwz	r6, offDvmDex_pResMethods(r6)	/* r6<- pDvmDex->pResMethods */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
	cmpwi	r3, 0				/* already resolved? */
	bne+	0f				/* resolved?, yes */
	mr	r3, r21				/* r3<- method->clazz */
	li	r5, METHOD_VIRTUAL		/* resolver method type */
	bl	dvmResolveMethod@plt		/* r3<- call(clazz, ref, flags) */
	cmpwi	r3, 0				/* got null? */
	beq-	common_exceptionThrown		/* yes, handle exception */
0:	lwz	r4, offClassObject_super(r20)	/* r4<- method->clazz->super */
	lhz	r5, offMethod_methodIndex(r3)	/* r5<- baseMethod->methodIndex */
	lwz	r6, offClassObject_vtableCount(r4)	/* r6<- super->vtableCount */
	cmplw	r5, r6				/* compare (methodIndex, vTableCount) */
	bge-	.LOP_INVOKE_SUPER_nsm			/* method not present in superclass */
	lwz	r4, offClassObject_vtable(r4)	/* r4<- ...clazz->super->vtable */
	slwi	r5, r5, 2			/* r5<- baseMethod->methodIndex << 2 */
	lwzx	r3, r4, r5			/* r3<- vtable[methodIndex] */
	b	common_invokeMethodNoRange	/* no, continue on */

/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_DIRECT: /* 0x70 */
/* File: powerpc/OP_INVOKE_DIRECT.S */
	/*
	 * Handle a direct method call.
	 *
	 * for: invoke-direct, invoke-direct/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	FETCH(r19, 2)				/* r19<- GFED or CCCC */
	.if	(!0)
	rlwinm  r19,r19,2,26,29			/* r19<- D << 2 */
	.else
	slwi	r19, r19, 2			/* r19<- CCCC << 2 */
	.endif
	slwi	r5, r4, 2			/* r5<- r4 << 2 */
	EXPORT_PC()				/* must export for invoke */
	GET_VREG_S(r20, r19)			/* r20<- "this" ptr */
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r6, offDvmDex_pResMethods(r6)	/* r6<- pDvmDex->pResMethods */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
	cmpwi	r3, 0				/* already resolved? */
	bne+	0f				/* resolved?, yes */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	li	r5, METHOD_DIRECT		/* resolver method type */
	bl	dvmResolveMethod@plt		/* r3<- call(clazz, ref, flags) */
	cmpwi	r3, 0				/* got null? */
	beq-	common_exceptionThrown		/* yes, handle exception */
0:	cmpwi	r20, 0				/* null "this" ref? */
	bne+	common_invokeMethodNoRange	/* no, continue on */
	b	common_errNullObject		/* yes, throw exception */

/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_STATIC: /* 0x71 */
/* File: powerpc/OP_INVOKE_STATIC.S */
	/*
	 * Handle a static method call.
	 *
	 * for: invoke-static, invoke-static/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	FETCH(r4, 1)				/* r4<- BBBB */
	lwz	r6, offDvmDex_pResMethods(r6)	/* r6<- pDvmDex->pResMethods */
	slwi	r5, r4, 2			/* r5<- r4 << 2 */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
	cmpwi	r3, 0				/* already resolved? */
	EXPORT_PC()				/* must export for invoke */
	bne+	common_invokeMethodNoRange	/* yes, calls */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	li	r5, METHOD_STATIC		/* resolver method type */
	bl	dvmResolveMethod@plt		/* r3<- call(clazz, ref, flags) */
	cmpwi	r3, 0				/* got null? */
	bne+	common_invokeMethodNoRange	/* no, call */
	b 	common_exceptionThrown		/* yes, throw exception */

/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_INTERFACE: /* 0x72 */
/* File: powerpc/OP_INVOKE_INTERFACE.S */
	/*
	 * Handle an interface method call.
	 *
	 * for: invoke-interface, invoke-interface/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	FETCH(r6, 2)				/* r6<- GFED or CCCC */
	.if	(!0)
	rlwinm  r6,r6,2,26,29			/* r6<- D << 2 */
	.else
	slwi	r6, r6, 2			/* r6<- CCCC << 2 */
	.endif
	slwi	r5, r4, 2			/* r5<- r4 << 2 */
	GET_VREG_S(r3, r6)			/* r3<- "this" ptr */
	EXPORT_PC()				/* must export for invoke */
	cmpwi	r3, 0				/* null "this" ref? */
	beq-	common_errNullObject		/* yes, fail */
	lwz	r3, offObject_clazz(r3)		/* r3<- thisPtr->clazz */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- method */
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- methodClassDex */
	bl	dvmFindInterfaceMethodInCache@plt	/* r3<- call(class, ref, method, dex) */
	cmpwi	r3, 0				/* got null? */
	bne+	common_invokeMethodNoRange	/* no, continue on */
	b	common_exceptionThrown

/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_73: /* 0x73 */
/* File: powerpc/OP_UNUSED_73.S */
/* File: powerpc/unused.S */
	b	common_abort


/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_VIRTUAL_RANGE: /* 0x74 */
/* File: powerpc/OP_INVOKE_VIRTUAL_RANGE.S */
/* File: powerpc/OP_INVOKE_VIRTUAL.S */
	/*
	 * Handle a virtual method call.
	 *
	 * for: invoke-virtual, invoke-virtual/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op vAA, {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	FETCH(r19, 2)				/* r19<- GFED or CCCC */
	.if	(!1)
	rlwinm  r19,r19,2,26,29			/* r19<- D << 2 */
	.else
	slwi	r19, r19, 2			/* r19<- CCCC << 2 */
	.endif
	slwi	r5, r4, 2			/* r5<- r4 << 2 */
	EXPORT_PC()				/* must export for invoke */
	GET_VREG_S(r20, r19)			/* r20<- "this" ptr */
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r6, offDvmDex_pResMethods(r6)	/* r6<- pDvmDex->pResMethods */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
	cmpwi	r3, 0				/* already resolved? */
	bne+	0f				/* resolved?, yes */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	li	r5, METHOD_VIRTUAL		/* resolver method type */
	bl	dvmResolveMethod@plt		/* r3<- call(clazz, ref, flags) */
	cmpwi	r3, 0				/* got null? */
	beq-	common_exceptionThrown		/* yes, handle exception */
0:	cmpwi	r20, 0				/* null "this" ref? */
	beq- 	common_errNullObject		/* yes, throw exception */
	lwz	r6, offObject_clazz(r20)	/* r6<- thisPtr->clazz */
	lwz	r6, offClassObject_vtable(r6)	/* r6<- thisPtr->clazz->vtable */
	lhz	r5, offMethod_methodIndex(r3)	/* r5<- baseMethod->methodIndex */
	slwi	r5, r5, 2			/* r5<- baseMethod->methodIndex << 2 */
	lwzx	r3, r6, r5			/* r3<- vtable[methodIndex] */
	b	common_invokeMethodRange	/* no, continue on */


/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_SUPER_RANGE: /* 0x75 */
/* File: powerpc/OP_INVOKE_SUPER_RANGE.S */
/* File: powerpc/OP_INVOKE_SUPER.S */
	/*
	 * Handle a "super" method call.
	 *
	 * for: invoke-super, invoke-super/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op vAA, {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	FETCH(r19, 2)				/* r19<- GFED or CCCC */
	.if	(!1)
	rlwinm  r19,r19,2,26,29			/* r19<- D << 2 */
	.else
	slwi	r19, r19, 2			/* r19<- CCCC << 2 */
	.endif
	slwi	r5, r4, 2			/* r5<- r4 << 2 */
	GET_VREG_S(r20, r19)			/* r20<- "this" ptr */
	EXPORT_PC()				/* must export for invoke */
	cmpwi	r20, 0				/* null "this"? */
	beq-	common_errNullObject		/* null "this", throw exception */
	lwz	r21, offGlue_method(rGLUE)	/* r21<- glue->method */
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r21, offMethod_clazz(r21)	/* r21<- method->clazz */
	lwz	r6, offDvmDex_pResMethods(r6)	/* r6<- pDvmDex->pResMethods */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
	cmpwi	r3, 0				/* already resolved? */
	bne+	0f				/* resolved?, yes */
	mr	r3, r21				/* r3<- method->clazz */
	li	r5, METHOD_VIRTUAL		/* resolver method type */
	bl	dvmResolveMethod@plt		/* r3<- call(clazz, ref, flags) */
	cmpwi	r3, 0				/* got null? */
	beq-	common_exceptionThrown		/* yes, handle exception */
0:	lwz	r4, offClassObject_super(r20)	/* r4<- method->clazz->super */
	lhz	r5, offMethod_methodIndex(r3)	/* r5<- baseMethod->methodIndex */
	lwz	r6, offClassObject_vtableCount(r4)	/* r6<- super->vtableCount */
	cmplw	r5, r6				/* compare (methodIndex, vTableCount) */
	bge-	.LOP_INVOKE_SUPER_RANGE_nsm			/* method not present in superclass */
	lwz	r4, offClassObject_vtable(r4)	/* r4<- ...clazz->super->vtable */
	slwi	r5, r5, 2			/* r5<- baseMethod->methodIndex << 2 */
	lwzx	r3, r4, r5			/* r3<- vtable[methodIndex] */
	b	common_invokeMethodRange	/* no, continue on */


/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_DIRECT_RANGE: /* 0x76 */
/* File: powerpc/OP_INVOKE_DIRECT_RANGE.S */
/* File: powerpc/OP_INVOKE_DIRECT.S */
	/*
	 * Handle a direct method call.
	 *
	 * for: invoke-direct, invoke-direct/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	FETCH(r19, 2)				/* r19<- GFED or CCCC */
	.if	(!1)
	rlwinm  r19,r19,2,26,29			/* r19<- D << 2 */
	.else
	slwi	r19, r19, 2			/* r19<- CCCC << 2 */
	.endif
	slwi	r5, r4, 2			/* r5<- r4 << 2 */
	EXPORT_PC()				/* must export for invoke */
	GET_VREG_S(r20, r19)			/* r20<- "this" ptr */
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r6, offDvmDex_pResMethods(r6)	/* r6<- pDvmDex->pResMethods */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
	cmpwi	r3, 0				/* already resolved? */
	bne+	0f				/* resolved?, yes */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	li	r5, METHOD_DIRECT		/* resolver method type */
	bl	dvmResolveMethod@plt		/* r3<- call(clazz, ref, flags) */
	cmpwi	r3, 0				/* got null? */
	beq-	common_exceptionThrown		/* yes, handle exception */
0:	cmpwi	r20, 0				/* null "this" ref? */
	bne+	common_invokeMethodRange	/* no, continue on */
	b	common_errNullObject		/* yes, throw exception */


/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_STATIC_RANGE: /* 0x77 */
/* File: powerpc/OP_INVOKE_STATIC_RANGE.S */
/* File: powerpc/OP_INVOKE_STATIC.S */
	/*
	 * Handle a static method call.
	 *
	 * for: invoke-static, invoke-static/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	FETCH(r4, 1)				/* r4<- BBBB */
	lwz	r6, offDvmDex_pResMethods(r6)	/* r6<- pDvmDex->pResMethods */
	slwi	r5, r4, 2			/* r5<- r4 << 2 */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
	cmpwi	r3, 0				/* already resolved? */
	EXPORT_PC()				/* must export for invoke */
	bne+	common_invokeMethodRange	/* yes, calls */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	li	r5, METHOD_STATIC		/* resolver method type */
	bl	dvmResolveMethod@plt		/* r3<- call(clazz, ref, flags) */
	cmpwi	r3, 0				/* got null? */
	bne+	common_invokeMethodRange	/* no, call */
	b 	common_exceptionThrown		/* yes, throw exception */


/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_INTERFACE_RANGE: /* 0x78 */
/* File: powerpc/OP_INVOKE_INTERFACE_RANGE.S */
/* File: powerpc/OP_INVOKE_INTERFACE.S */
	/*
	 * Handle an interface method call.
	 *
	 * for: invoke-interface, invoke-interface/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	FETCH(r6, 2)				/* r6<- GFED or CCCC */
	.if	(!1)
	rlwinm  r6,r6,2,26,29			/* r6<- D << 2 */
	.else
	slwi	r6, r6, 2			/* r6<- CCCC << 2 */
	.endif
	slwi	r5, r4, 2			/* r5<- r4 << 2 */
	GET_VREG_S(r3, r6)			/* r3<- "this" ptr */
	EXPORT_PC()				/* must export for invoke */
	cmpwi	r3, 0				/* null "this" ref? */
	beq-	common_errNullObject		/* yes, fail */
	lwz	r3, offObject_clazz(r3)		/* r3<- thisPtr->clazz */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- method */
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- methodClassDex */
	bl	dvmFindInterfaceMethodInCache@plt	/* r3<- call(class, ref, method, dex) */
	cmpwi	r3, 0				/* got null? */
	bne+	common_invokeMethodRange	/* no, continue on */
	b	common_exceptionThrown


/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_79: /* 0x79 */
/* File: powerpc/OP_UNUSED_79.S */
/* File: powerpc/unused.S */
	b	common_abort


/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_7A: /* 0x7a */
/* File: powerpc/OP_UNUSED_7A.S */
/* File: powerpc/unused.S */
	b	common_abort


/* ------------------------------ */
    .balign 128
.L_OP_NEG_INT: /* 0x7b */
/* File: powerpc/OP_NEG_INT.S */
/* File: powerpc/unop.S */
	/*
	 * Generic 32-bit unary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = op r0".
	 * This could be an ARM instruction or a function call.
	 *
	 * for: neg-int, not-int, int-to-byte, int-to-char, int-to-short
	 *
	 * missing: neg-float, int-to-float, float-to-int
	 */
	/* unop vA, vB */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	neg	r3, r3					/* r0<- op, r0-r3 changed */
	SET_VREG_S(r3, r19)			/* vAA<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_NOT_INT: /* 0x7c */
/* File: powerpc/OP_NOT_INT.S */
/* File: powerpc/unop.S */
	/*
	 * Generic 32-bit unary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = op r0".
	 * This could be an ARM instruction or a function call.
	 *
	 * for: neg-int, not-int, int-to-byte, int-to-char, int-to-short
	 *
	 * missing: neg-float, int-to-float, float-to-int
	 */
	/* unop vA, vB */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	not	r3, r3					/* r0<- op, r0-r3 changed */
	SET_VREG_S(r3, r19)			/* vAA<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_NEG_LONG: /* 0x7d */
/* File: powerpc/OP_NEG_LONG.S */
/* File: powerpc/unopWide.S */
	/*
	 * Generic 64-bit unary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = op r3/r4".
	 *
	 * For: neg-long, not-long, neg-double, long-to-double, double-to-long
	 */
	/* unop vA, vB */

	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r5<- B << 2 */

	lwzux	r3, r6, rFP			/* r3<- vB, r6<- &fp[B] */
	lwz	r4, 4(r6)			/* r4<- vB+1, r5/r6<- vB/vB+1 */

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	subfic	r4,r4,0				/* optional op; may set condition codes */
	subfze	r3,r3					/* result<- op, r3-r6 changed */
					/* optional op; */

	stwux	r3, r19, rFP			/* vAA<- r3, r19<- &fp[A] */
	stw	r4, 4(r19)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_NOT_LONG: /* 0x7e */
/* File: powerpc/OP_NOT_LONG.S */
/* File: powerpc/unopWide.S */
	/*
	 * Generic 64-bit unary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = op r3/r4".
	 *
	 * For: neg-long, not-long, neg-double, long-to-double, double-to-long
	 */
	/* unop vA, vB */

	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r5<- B << 2 */

	lwzux	r3, r6, rFP			/* r3<- vB, r6<- &fp[B] */
	lwz	r4, 4(r6)			/* r4<- vB+1, r5/r6<- vB/vB+1 */

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	not	r3, r3				/* optional op; may set condition codes */
	not	r4, r4					/* result<- op, r3-r6 changed */
					/* optional op; */

	stwux	r3, r19, rFP			/* vAA<- r3, r19<- &fp[A] */
	stw	r4, 4(r19)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_NEG_FLOAT: /* 0x7f */
/* File: powerpc/OP_NEG_FLOAT.S */
/* File: powerpc/unop-float.S */
	/*
	 * Generic float unary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = op r0".
	 *
	 */
	/* unop vA, vB */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_F_S(f1, r5)			/* f1<- vBB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	fneg f1, f1					/* r0<- op, r0-r3 changed */
	SET_VREG_F_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_NEG_DOUBLE: /* 0x80 */
/* File: powerpc/OP_NEG_DOUBLE.S */
/* File: powerpc/unop-double.S */
	/*
	 * Generic double unary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = op r0".
	 *
	 */
	/* unop vA, vB */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_D_S(f1, r5)			/* f1<- vBB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	fneg f1, f1					/* r0<- op, r0-r3 changed */
	SET_VREG_D_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_INT_TO_LONG: /* 0x81 */
/* File: powerpc/OP_INT_TO_LONG.S */
/* File: powerpc/unopWider.S */
	/*
	 * Generic 32bit-to-64bit unary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = op r0", where
	 * "result" is a 64-bit quantity in r0/r1.
	 *
	 * For: int-to-long, int-to-double, float-to-long, float-to-double
	 */
	/* unop vA, vB */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */

	GET_VREG_S(r3, r6)			/* r3<- vB */

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	mr r4, r3				/* optional op; may set condition codes */
	srawi r3, r3, 31					/* result<- op, r3-r6 changed */
					/* optional op; */

	stwux	r3, r19, rFP			/* vAA<- r3, r19<- &fp[A] */
	stw	r4, 4(r19)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_INT_TO_FLOAT: /* 0x82 */
/* File: powerpc/OP_INT_TO_FLOAT.S */
	/* int-to-float vA, vB */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	addi	r1, r1, -32			/* make workspace on stack (8 words) */
#ifndef KEEP_INT_ADJUST_IN_REG
	lis	r5, 0x5980			/* r5<- new magic value */
	ori	r5, r5, 0x0004
	stw	r5, 4(r1)			/* store magic value */
#endif
	xoris	r4, r3, 0x8000			/* r4<- r3 with toggled sign */
	lis	r3, 0x4330			/* r3<- magic value (0x43300000) */
	stw	r3, 8(r1)			/* store double prefix */
	stw	r4, 12(r1)			/* store constructed double value */
	lfd	f2, 8(r1)			/* f2<- constructed double value */
#ifndef KEEP_INT_ADJUST_IN_REG
	lfs	f0, 4(r1)			/* f0<- constructed const value */
	fsub	f1, f2, f0			/* f1<- constructed double value - adjust */
#else
	fsub	f1, f2, fIntAdj			/* f1<- constructed double value - adjust */
#endif
	frsp	f1, f1				/* single precision */
	addi	r1, r1, 32			/* clean workspace */
	SET_VREG_F_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* ------------------------------ */
    .balign 128
.L_OP_INT_TO_DOUBLE: /* 0x83 */
/* File: powerpc/OP_INT_TO_DOUBLE.S */
	/* int-to-double vA, vB */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	addi	r1, r1, -32			/* make workspace on stack (8 words) */
#ifndef KEEP_INT_ADJUST_IN_REG
	lis	r5, 0x5980			/* r5<- new magic value */
	ori	r5, r5, 0x0004
	stw	r5, 4(r1)			/* store magic value */
#endif
	xoris	r4, r3, 0x8000			/* r4<- r3 with toggled sign */
	lis	r3, 0x4330			/* r3<- magic value */
	stw	r3, 8(r1)			/* store double prefix */
	stw	r4, 12(r1)			/* store constructed double value */
	lfd	f2, 8(r1)			/* f2<- constructed double value */
#ifndef KEEP_INT_ADJUST_IN_REG
	lfs	f0, 4(r1)			/* f0<- constructed const value */
	fsub	f1, f2, f0			/* f1<- constructed double value - adjust */
#else
	fsub	f1, f2, fIntAdj			/* f1<- constructed double value - adjust */
#endif
	addi	r1, r1, 32			/* clean workspace */
	SET_VREG_D_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* ------------------------------ */
    .balign 128
.L_OP_LONG_TO_INT: /* 0x84 */
/* File: powerpc/OP_LONG_TO_INT.S */
/* File: powerpc/unopNarrower.S */
	/*
	 * Generic 64bit-to-32bit unary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = op r0/r1", where
	 * "result" is a 32-bit quantity in r0.
	 *
	 * For: long-to-float, double-to-int, double-to-float
	 */
	/* unop vA, vB */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */

	lwzux	r3, r6, rFP			/* r3<- vB, r6<- &fp[B] */
	lwz	r4, 4(r6)			/* r4<- vB+1, r5/r6<- vB/vB+1 */

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	mr r3, r4					/* r0<- op, r0-r3 changed */
	SET_VREG_S(r3, r19)			/* vAA<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_LONG_TO_FLOAT: /* 0x85 */
/* File: powerpc/OP_LONG_TO_FLOAT.S */
	/* long-to-float vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r5<- B << 2 */
	lwzux	r3, r6, rFP			/* r3<- vB, r6<- &fp[B] */
	lwz	r4, 4(r6)			/* r4<- vB+1, r5/r6<- vB/vB+1 */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	bl	__floatdisf@plt			/* f1<- (float)(r3/r4) */
	SET_VREG_F_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_LONG_TO_DOUBLE: /* 0x86 */
/* File: powerpc/OP_LONG_TO_DOUBLE.S */
	/* long-to-double vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r5<- B << 2 */
	lwzux	r3, r6, rFP			/* r3<- vB, r6<- &fp[B] */
	lwz	r4, 4(r6)			/* r4<- vB+1, r5/r6<- vB/vB+1 */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	bl	__floatdidf@plt			/* f1<- (double)(r3/r4) */
	SET_VREG_D_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_FLOAT_TO_INT: /* 0x87 */
/* File: powerpc/OP_FLOAT_TO_INT.S */
	/* float-to-int vA, vB */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	rlwinm  r7,rINST,26,26,29		/* r7<- (A+ & 15) << 2 */
	GET_VREG_F_S(f1, r6)			/* f1<- vB */
#ifndef KEEP_MAX_MIN_INT_IN_REGS
	lis	r5, .LOP_FLOAT_TO_INT_table@ha	/* r5<- start of constant table */
	addi	r5, r5, .LOP_FLOAT_TO_INT_table@l
	lfs	f0, 0(r5)			/* f0<- max-int in float format */
	lfs	f2, 4(r5)			/* f2<- min-int in float format */
	fcmpu	cr0, f1, f0			/* compare f1 with max int */
	bun-	.LOP_FLOAT_TO_INT_store_zero		/* if f1 is NaN */
	bgt-	.LOP_FLOAT_TO_INT_store_max_int	/* >=, store */
	beq-	.LOP_FLOAT_TO_INT_store_max_int	/* =, store */
	fcmpu	cr0, f1, f2			/* compare f1 with min int */
	blt-	.LOP_FLOAT_TO_INT_store_min_int	/* <=, store */
	beq-	.LOP_FLOAT_TO_INT_store_min_int	/* <=, store */
#else
	fcmpu	cr0, f1, fMaxInt		/* compare f1 with max int */
	bun-	.LOP_FLOAT_TO_INT_store_zero		/* if f1 is NaN */
	bgt-	.LOP_FLOAT_TO_INT_store_max_int	/* >=, store */
	beq-	.LOP_FLOAT_TO_INT_store_max_int	/* =, store */
	fcmpu	cr0, f1, fMinInt		/* compare f1 with min int */
	blt-	.LOP_FLOAT_TO_INT_store_min_int	/* <=, store */
	beq-	.LOP_FLOAT_TO_INT_store_min_int	/* <=, store */
#endif
	fctiwz	f0, f1				/* convert to integer */
	stfiwx	f0, r7, rFP			/* store */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_FLOAT_TO_LONG: /* 0x88 */
/* File: powerpc/OP_FLOAT_TO_LONG.S */
	/* float-to-long vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_F_S(f1, r6)			/* f1<- vB */
#ifndef KEEP_MAX_MIN_LONG_IN_REGS
	lis	r5, .LOP_FLOAT_TO_LONG_table@ha	/* r5<- start of constant table */
	addi	r5, r5, .LOP_FLOAT_TO_LONG_table@l
	lfs	f0, 0(r5)			/* f0<- max-long in float format */
	lfs	f2, 4(r5)			/* f2<- min-long in float format */
	fcmpu	cr0, f1, f0			/* compare f1 with max long */
	bun-	.LOP_FLOAT_TO_LONG_store_zero		/* f1 is NaN */
	bgt-	.LOP_FLOAT_TO_LONG_store_max_int	/* >, store */
	beq-	.LOP_FLOAT_TO_LONG_store_max_int	/* ==, store */
	fcmpu	cr0, f1, f2			/* compare f1 with min long */
	blt-	.LOP_FLOAT_TO_LONG_store_min_int	/* <, store */
	beq-	.LOP_FLOAT_TO_LONG_store_min_int	/* ==, store */
#else
	fcmpu	cr0, f1, fMaxLong		/* compare f1 with max long */
	bun-	.LOP_FLOAT_TO_LONG_store_zero		/* f1 is NaN */
	bgt-	.LOP_FLOAT_TO_LONG_store_max_int	/* >, store */
	beq-	.LOP_FLOAT_TO_LONG_store_max_int	/* ==, store */
	fcmpu	cr0, f1, fMinLong		/* compare f1 with min long */
	blt-	.LOP_FLOAT_TO_LONG_store_min_int	/* <, store */
	beq-	.LOP_FLOAT_TO_LONG_store_min_int	/* ==, store */
#endif
	bl	__fixsfdi@plt			/* pass to std library */
	stwux	r3, r19, rFP			/* store to register (hi) */
	stw	r4, 4(r19)			/* lo */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_FLOAT_TO_DOUBLE: /* 0x89 */
/* File: powerpc/OP_FLOAT_TO_DOUBLE.S */
	/* unop vA, vB */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	rlwinm  r7,rINST,26,26,29		/* r7<- (A+ & 15) << 2 */
	GET_VREG_F_S(f1, r6)			/* f1<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	SET_VREG_D_S(f1, r7)			/* vAA/vAA+1<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_DOUBLE_TO_INT: /* 0x8a */
/* File: powerpc/OP_DOUBLE_TO_INT.S */
	/* double-to-int vA, vB */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	rlwinm  r7,rINST,26,26,29		/* r7<- (A+ & 15) << 2 */
	GET_VREG_D_S(f1, r6)			/* f1<- vB */
#ifndef KEEP_MAX_MIN_INT_IN_REGS
	lis	r5, .LOP_DOUBLE_TO_INT_table@ha	/* r5<- start of constant table */
	addi	r5, r5, .LOP_DOUBLE_TO_INT_table@l
	lfd	f0, 0(r5)			/* f0<- max-int in double format */
	lfd	f2, 8(r5)			/* f2<- min-int in double format */
	fcmpu	cr0, f1, f0			/* compare f1 with max int */
	bun-	.LOP_DOUBLE_TO_INT_store_zero		/* f1 is NaN */
	bgt-	.LOP_DOUBLE_TO_INT_store_max_int	/* >, store */
	beq-	.LOP_DOUBLE_TO_INT_store_max_int	/* ==, store */
	fcmpu	cr0, f1, f2			/* compare f1 with min int */
	blt-	.LOP_DOUBLE_TO_INT_store_min_int	/* <, store */
	beq-	.LOP_DOUBLE_TO_INT_store_min_int	/* ==, store */
#else
	fcmpu	cr0, f1, fMaxInt		/* compare f1 with max int */
	bun-	.LOP_DOUBLE_TO_INT_store_zero		/* f1 is NaN */
	bgt-	.LOP_DOUBLE_TO_INT_store_max_int	/* >, store */
	beq-	.LOP_DOUBLE_TO_INT_store_max_int	/* ==, store */
	fcmpu	cr0, f1, fMinInt		/* compare f1 with min int */
	blt-	.LOP_DOUBLE_TO_INT_store_min_int	/* <, store */
	beq-	.LOP_DOUBLE_TO_INT_store_min_int	/* ==, store */
#endif
	fctiwz	f0, f1				/* convert to integer */
	stfiwx	f0, r7, rFP			/* store */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_DOUBLE_TO_LONG: /* 0x8b */
/* File: powerpc/OP_DOUBLE_TO_LONG.S */
	/* double-to-long vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_D_S(f1, r6)			/* f1<- vB */
#ifndef KEEP_MAX_MIN_LONG_IN_REGS
	lis	r5, .LOP_DOUBLE_TO_LONG_table@ha	/* r5<- start of constant table */
	addi	r5, r5, .LOP_DOUBLE_TO_LONG_table@l
	lfd	f0, 0(r5)			/* f0<- max-long in float format */
	lfd	f2, 8(r5)			/* f2<- min-long in float format */
	fcmpu	cr0, f1, f0			/* compare f1 with max long */
	bun-	.LOP_DOUBLE_TO_LONG_store_zero		/* f1 is NaN */
	bgt-	.LOP_DOUBLE_TO_LONG_store_max_int	/* >, store */
	beq-	.LOP_DOUBLE_TO_LONG_store_max_int	/* ==, store */
	fcmpu	cr0, f1, f2			/* compare f1 with min long */
	blt-	.LOP_DOUBLE_TO_LONG_store_min_int	/* <, store */
	beq-	.LOP_DOUBLE_TO_LONG_store_min_int	/* ==, store */
#else
	fcmpu	cr0, f1, fMaxLong		/* compare f1 with max long */
	bun-	.LOP_DOUBLE_TO_LONG_store_zero		/* f1 is NaN */
	bgt-	.LOP_DOUBLE_TO_LONG_store_max_int	/* >, store */
	beq-	.LOP_DOUBLE_TO_LONG_store_max_int	/* ==, store */
	fcmpu	cr0, f1, fMinLong		/* compare f1 with min long */
	blt-	.LOP_DOUBLE_TO_LONG_store_min_int	/* <, store */
	beq-	.LOP_DOUBLE_TO_LONG_store_min_int	/* ==, store */
#endif
	bl	__fixdfdi@plt			/* pass to std library */
	stwux	r3, r19, rFP			/* store to register (hi) */
	stw	r4, 4(r19)			/* lo */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_DOUBLE_TO_FLOAT: /* 0x8c */
/* File: powerpc/OP_DOUBLE_TO_FLOAT.S */
	/* unop vA, vB */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	rlwinm  r7,rINST,26,26,29		/* r7<- (A+ & 15) << 2 */
	GET_VREG_D_S(f1, r6)			/* f1<- vB/vB+1 */
	frsp f1,f1
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	SET_VREG_F_S(f1, r7)			/* vAA <- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_INT_TO_BYTE: /* 0x8d */
/* File: powerpc/OP_INT_TO_BYTE.S */
/* File: powerpc/unop.S */
	/*
	 * Generic 32-bit unary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = op r0".
	 * This could be an ARM instruction or a function call.
	 *
	 * for: neg-int, not-int, int-to-byte, int-to-char, int-to-short
	 *
	 * missing: neg-float, int-to-float, float-to-int
	 */
	/* unop vA, vB */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	extsb	r3, r3					/* r0<- op, r0-r3 changed */
	SET_VREG_S(r3, r19)			/* vAA<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_INT_TO_CHAR: /* 0x8e */
/* File: powerpc/OP_INT_TO_CHAR.S */
/* File: powerpc/unop.S */
	/*
	 * Generic 32-bit unary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = op r0".
	 * This could be an ARM instruction or a function call.
	 *
	 * for: neg-int, not-int, int-to-byte, int-to-char, int-to-short
	 *
	 * missing: neg-float, int-to-float, float-to-int
	 */
	/* unop vA, vB */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	clrlwi	r3, r3, 16					/* r0<- op, r0-r3 changed */
	SET_VREG_S(r3, r19)			/* vAA<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_INT_TO_SHORT: /* 0x8f */
/* File: powerpc/OP_INT_TO_SHORT.S */
/* File: powerpc/unop.S */
	/*
	 * Generic 32-bit unary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = op r0".
	 * This could be an ARM instruction or a function call.
	 *
	 * for: neg-int, not-int, int-to-byte, int-to-char, int-to-short
	 *
	 * missing: neg-float, int-to-float, float-to-int
	 */
	/* unop vA, vB */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	extsh	r3, r3					/* r0<- op, r0-r3 changed */
	SET_VREG_S(r3, r19)			/* vAA<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_ADD_INT: /* 0x90 */
/* File: powerpc/OP_ADD_INT.S */
/* File: powerpc/binop.S */
	/*
	 * Generic 32-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	add     r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_SUB_INT: /* 0x91 */
/* File: powerpc/OP_SUB_INT.S */
/* File: powerpc/binop.S */
	/*
	 * Generic 32-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	sub	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_MUL_INT: /* 0x92 */
/* File: powerpc/OP_MUL_INT.S */
/* File: powerpc/binop.S */
	/*
	 * Generic 32-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	mullw	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_DIV_INT: /* 0x93 */
/* File: powerpc/OP_DIV_INT.S */
/* File: powerpc/binop-divrem.S */
	/*
	 * For: div-int, rem-int
	 */
	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r4, 0				/* r4 == 0 ? */
	beq-	common_errDivideByZero		/* divide by zero error */
	lis	r5, 0x8000			/* r5<- 0x80000000 */
	cmpw	r3, r5				/* compare with r3 */
	bne+	1f				/* no, normal division */
	cmpwi	r4, -1				/* compare with -1 */
	bne+	1f				/* no, normal division */
	.if 1
	mr	r7, r3				/* division */
	.else
	li	r7, 0				/* remainder, 0 */
	.endif
	b	2f				/* and skip */
1:	divw	r7, r3, r4			/* divide */
	.if (! 1)
	mullw	r7, r7, r4			/* compute remainder */
	subf	r7, r7, r3
	.endif
2:
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	SET_VREG_S(r7, r19)			/* vAA<- r7 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_REM_INT: /* 0x94 */
/* File: powerpc/OP_REM_INT.S */
/* File: powerpc/binop-divrem.S */
	/*
	 * For: div-int, rem-int
	 */
	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r4, 0				/* r4 == 0 ? */
	beq-	common_errDivideByZero		/* divide by zero error */
	lis	r5, 0x8000			/* r5<- 0x80000000 */
	cmpw	r3, r5				/* compare with r3 */
	bne+	1f				/* no, normal division */
	cmpwi	r4, -1				/* compare with -1 */
	bne+	1f				/* no, normal division */
	.if 0
	mr	r7, r3				/* division */
	.else
	li	r7, 0				/* remainder, 0 */
	.endif
	b	2f				/* and skip */
1:	divw	r7, r3, r4			/* divide */
	.if (! 0)
	mullw	r7, r7, r4			/* compute remainder */
	subf	r7, r7, r3
	.endif
2:
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	SET_VREG_S(r7, r19)			/* vAA<- r7 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_AND_INT: /* 0x95 */
/* File: powerpc/OP_AND_INT.S */
/* File: powerpc/binop.S */
	/*
	 * Generic 32-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	and     r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_OR_INT: /* 0x96 */
/* File: powerpc/OP_OR_INT.S */
/* File: powerpc/binop.S */
	/*
	 * Generic 32-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	or	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_XOR_INT: /* 0x97 */
/* File: powerpc/OP_XOR_INT.S */
/* File: powerpc/binop.S */
	/*
	 * Generic 32-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	xor	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_SHL_INT: /* 0x98 */
/* File: powerpc/OP_SHL_INT.S */
/* File: powerpc/binop.S */
	/*
	 * Generic 32-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	andi.	r4, r4, 31				/* optional op; may set condition codes */
	slw	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_SHR_INT: /* 0x99 */
/* File: powerpc/OP_SHR_INT.S */
/* File: powerpc/binop.S */
	/*
	 * Generic 32-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	andi.	r4, r4, 31				/* optional op; may set condition codes */
	sraw	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_USHR_INT: /* 0x9a */
/* File: powerpc/OP_USHR_INT.S */
/* File: powerpc/binop.S */
	/*
	 * Generic 32-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	andi.	r4, r4, 31				/* optional op; may set condition codes */
	srw	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_ADD_LONG: /* 0x9b */
/* File: powerpc/OP_ADD_LONG.S */
/* File: powerpc/binopWide.S */
	/*
	 * Generic 64-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: add-long, sub-long, and-long, or-long, xor-long
	*/
	/* binopWide vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	lwzux	r5, r6, rFP			/* r5<- vCC, r6<- &fp[CC] */
	lwz	r6, 4(r6)			/* r6<- vCC+1, r5/r6<- vCC/vCC+1 */

	.if 0
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	addc	r4, r4, r6				/* optional op; may set condition codes */
	adde	r3, r3, r5					/* result<- op, r3-r6 changed */
					/* optional op; */

	stwux	r3, r19, rFP			/* vAA<- r3, r19<- &fp[AA] */
	stw	r4, 4(r19)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_SUB_LONG: /* 0x9c */
/* File: powerpc/OP_SUB_LONG.S */
/* File: powerpc/binopWide.S */
	/*
	 * Generic 64-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: add-long, sub-long, and-long, or-long, xor-long
	*/
	/* binopWide vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	lwzux	r5, r6, rFP			/* r5<- vCC, r6<- &fp[CC] */
	lwz	r6, 4(r6)			/* r6<- vCC+1, r5/r6<- vCC/vCC+1 */

	.if 0
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	subfc	r4, r6, r4				/* optional op; may set condition codes */
	subfe	r3, r5, r3					/* result<- op, r3-r6 changed */
					/* optional op; */

	stwux	r3, r19, rFP			/* vAA<- r3, r19<- &fp[AA] */
	stw	r4, 4(r19)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_MUL_LONG: /* 0x9d */
/* File: powerpc/OP_MUL_LONG.S */
	/*
	 * Signed 64-bit integer multiply.
	 */
	/* mul-long vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r7,rINST,26,6,29		/* r7<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	lwzux	r5, r6, rFP			/* r5<- vCC, r6<- &fp[CC] */
	lwz	r6, 4(r6)			/* r6<- vCC+1, r5/r6<- vCC/vCC+1 */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	mullw	r8,r5,r4			/* perform 64 bit multiplication */
	mullw	r3,r3,r6
	mulhwu	r9,r6,r4
	mullw	r4,r6,r4
	add	r0,r8,r3
	add	r3,r0,r9

	stwux	r3, r7, rFP			/* vAA<- r3, r7<- &fp[AA] */
	stw	r4, 4(r7)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_DIV_LONG: /* 0x9e */
/* File: powerpc/OP_DIV_LONG.S */
/* File: powerpc/binopWide.S */
	/*
	 * Generic 64-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: add-long, sub-long, and-long, or-long, xor-long
	*/
	/* binopWide vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	lwzux	r5, r6, rFP			/* r5<- vCC, r6<- &fp[CC] */
	lwz	r6, 4(r6)			/* r6<- vCC+1, r5/r6<- vCC/vCC+1 */

	.if 1
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	bl __divdi3@plt					/* result<- op, r3-r6 changed */
					/* optional op; */

	stwux	r3, r19, rFP			/* vAA<- r3, r19<- &fp[AA] */
	stw	r4, 4(r19)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_REM_LONG: /* 0x9f */
/* File: powerpc/OP_REM_LONG.S */
/* File: powerpc/binopWide.S */
	/*
	 * Generic 64-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: add-long, sub-long, and-long, or-long, xor-long
	*/
	/* binopWide vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	lwzux	r5, r6, rFP			/* r5<- vCC, r6<- &fp[CC] */
	lwz	r6, 4(r6)			/* r6<- vCC+1, r5/r6<- vCC/vCC+1 */

	.if 1
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	bl __moddi3@plt					/* result<- op, r3-r6 changed */
					/* optional op; */

	stwux	r3, r19, rFP			/* vAA<- r3, r19<- &fp[AA] */
	stw	r4, 4(r19)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_AND_LONG: /* 0xa0 */
/* File: powerpc/OP_AND_LONG.S */
/* File: powerpc/binopWide.S */
	/*
	 * Generic 64-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: add-long, sub-long, and-long, or-long, xor-long
	*/
	/* binopWide vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	lwzux	r5, r6, rFP			/* r5<- vCC, r6<- &fp[CC] */
	lwz	r6, 4(r6)			/* r6<- vCC+1, r5/r6<- vCC/vCC+1 */

	.if 0
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	and	r4, r4, r6				/* optional op; may set condition codes */
	and	r3, r3, r5					/* result<- op, r3-r6 changed */
					/* optional op; */

	stwux	r3, r19, rFP			/* vAA<- r3, r19<- &fp[AA] */
	stw	r4, 4(r19)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_OR_LONG: /* 0xa1 */
/* File: powerpc/OP_OR_LONG.S */
/* File: powerpc/binopWide.S */
	/*
	 * Generic 64-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: add-long, sub-long, and-long, or-long, xor-long
	*/
	/* binopWide vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	lwzux	r5, r6, rFP			/* r5<- vCC, r6<- &fp[CC] */
	lwz	r6, 4(r6)			/* r6<- vCC+1, r5/r6<- vCC/vCC+1 */

	.if 0
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	or	r4, r4, r6				/* optional op; may set condition codes */
	or	r3, r3, r5					/* result<- op, r3-r6 changed */
					/* optional op; */

	stwux	r3, r19, rFP			/* vAA<- r3, r19<- &fp[AA] */
	stw	r4, 4(r19)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_XOR_LONG: /* 0xa2 */
/* File: powerpc/OP_XOR_LONG.S */
/* File: powerpc/binopWide.S */
	/*
	 * Generic 64-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: add-long, sub-long, and-long, or-long, xor-long
	*/
	/* binopWide vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	lwzux	r5, r6, rFP			/* r5<- vCC, r6<- &fp[CC] */
	lwz	r6, 4(r6)			/* r6<- vCC+1, r5/r6<- vCC/vCC+1 */

	.if 0
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	xor	r4, r4, r6				/* optional op; may set condition codes */
	xor	r3, r3, r5					/* result<- op, r3-r6 changed */
					/* optional op; */

	stwux	r3, r19, rFP			/* vAA<- r3, r19<- &fp[AA] */
	stw	r4, 4(r19)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_SHL_LONG: /* 0xa3 */
/* File: powerpc/OP_SHL_LONG.S */
/* File: powerpc/fragWide-shift-prolog.S */
	/*
	 * Generic 64-bit shift binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: shl-long, shr-long, ushr-long
	*/
	/* binopWide vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r7,rINST,26,6,29		/* r7<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	GET_VREG_S(r5, r6)			/* r5<- vCC */
	clrlwi	r5, r5, 26			/* r5<- r5 & 0x3f */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

/* File: powerpc/fragWide-shift.S */

	addic.	r0,r5,-32
	blt-	0f

	.if 1
	slw	r3,r4,r0
	li	r4,0
	b	1f
0:	rlwinm	r6,r4,31,1,31
	subfic	r9,r5,31
	srw	r0,r6,r9
	slw	r3,r3,r5
	or	r3,r0,r3
	slw	r4,r4,r5
	.endif

	.if 0
	srw	r4,r3,r0
	li	r3,0
	b	1f
0:	rlwinm	r6,r3,1,0,30
	subfic	r9,r5,31
	slw	r0,r6,r9
	srw	r4,r4,r5
	or	r4,r0,r4
	srw	r3,r3,r5
	.endif

	.if 0
	sraw	r4,r3,r0
	srawi	r3,r3,31
	b	1f
0:	rlwinm	r6,r3,1,0,30
	subfic	r9,r5,31
	slw	r0,r6,r9
	srw	r4,r4,r5
	or	r4,r0,r4
	sraw	r3,r3,r5
	.endif
1:

/* File: powerpc/fragWide-shift-epilog.S */
	stwux	r3, r7, rFP			/* vAA<- r3, r7<- &fp[AA] */
	stw	r4, 4(r7)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_SHR_LONG: /* 0xa4 */
/* File: powerpc/OP_SHR_LONG.S */
/* File: powerpc/fragWide-shift-prolog.S */
	/*
	 * Generic 64-bit shift binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: shl-long, shr-long, ushr-long
	*/
	/* binopWide vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r7,rINST,26,6,29		/* r7<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	GET_VREG_S(r5, r6)			/* r5<- vCC */
	clrlwi	r5, r5, 26			/* r5<- r5 & 0x3f */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

/* File: powerpc/fragWide-shift.S */

	addic.	r0,r5,-32
	blt-	0f

	.if 0
	slw	r3,r4,r0
	li	r4,0
	b	1f
0:	rlwinm	r6,r4,31,1,31
	subfic	r9,r5,31
	srw	r0,r6,r9
	slw	r3,r3,r5
	or	r3,r0,r3
	slw	r4,r4,r5
	.endif

	.if 0
	srw	r4,r3,r0
	li	r3,0
	b	1f
0:	rlwinm	r6,r3,1,0,30
	subfic	r9,r5,31
	slw	r0,r6,r9
	srw	r4,r4,r5
	or	r4,r0,r4
	srw	r3,r3,r5
	.endif

	.if 1
	sraw	r4,r3,r0
	srawi	r3,r3,31
	b	1f
0:	rlwinm	r6,r3,1,0,30
	subfic	r9,r5,31
	slw	r0,r6,r9
	srw	r4,r4,r5
	or	r4,r0,r4
	sraw	r3,r3,r5
	.endif
1:

/* File: powerpc/fragWide-shift-epilog.S */
	stwux	r3, r7, rFP			/* vAA<- r3, r7<- &fp[AA] */
	stw	r4, 4(r7)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_USHR_LONG: /* 0xa5 */
/* File: powerpc/OP_USHR_LONG.S */
/* File: powerpc/fragWide-shift-prolog.S */
	/*
	 * Generic 64-bit shift binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: shl-long, shr-long, ushr-long
	*/
	/* binopWide vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r7,rINST,26,6,29		/* r7<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	GET_VREG_S(r5, r6)			/* r5<- vCC */
	clrlwi	r5, r5, 26			/* r5<- r5 & 0x3f */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

/* File: powerpc/fragWide-shift.S */

	addic.	r0,r5,-32
	blt-	0f

	.if 0
	slw	r3,r4,r0
	li	r4,0
	b	1f
0:	rlwinm	r6,r4,31,1,31
	subfic	r9,r5,31
	srw	r0,r6,r9
	slw	r3,r3,r5
	or	r3,r0,r3
	slw	r4,r4,r5
	.endif

	.if 1
	srw	r4,r3,r0
	li	r3,0
	b	1f
0:	rlwinm	r6,r3,1,0,30
	subfic	r9,r5,31
	slw	r0,r6,r9
	srw	r4,r4,r5
	or	r4,r0,r4
	srw	r3,r3,r5
	.endif

	.if 0
	sraw	r4,r3,r0
	srawi	r3,r3,31
	b	1f
0:	rlwinm	r6,r3,1,0,30
	subfic	r9,r5,31
	slw	r0,r6,r9
	srw	r4,r4,r5
	or	r4,r0,r4
	sraw	r3,r3,r5
	.endif
1:

/* File: powerpc/fragWide-shift-epilog.S */
	stwux	r3, r7, rFP			/* vAA<- r3, r7<- &fp[AA] */
	stw	r4, 4(r7)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_ADD_FLOAT: /* 0xa6 */
/* File: powerpc/OP_ADD_FLOAT.S */
/* File: powerpc/binop-float.S */
	/*
	 * Generic float binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = f3 op f4".
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_F_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_F_S(f1, r5)			/* f1<- vBB+1 */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	fadds	f1, f1, f2					/* f3<- op, r3-r6 changed */
					/* optional op; more space */

	SET_VREG_F_S(f1, r19)			/* vAA<- f1 */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_SUB_FLOAT: /* 0xa7 */
/* File: powerpc/OP_SUB_FLOAT.S */
/* File: powerpc/binop-float.S */
	/*
	 * Generic float binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = f3 op f4".
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_F_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_F_S(f1, r5)			/* f1<- vBB+1 */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	fsubs	f1, f1, f2					/* f3<- op, r3-r6 changed */
					/* optional op; more space */

	SET_VREG_F_S(f1, r19)			/* vAA<- f1 */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_MUL_FLOAT: /* 0xa8 */
/* File: powerpc/OP_MUL_FLOAT.S */
/* File: powerpc/binop-float.S */
	/*
	 * Generic float binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = f3 op f4".
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_F_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_F_S(f1, r5)			/* f1<- vBB+1 */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	fmuls	f1, f1, f2					/* f3<- op, r3-r6 changed */
					/* optional op; more space */

	SET_VREG_F_S(f1, r19)			/* vAA<- f1 */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_DIV_FLOAT: /* 0xa9 */
/* File: powerpc/OP_DIV_FLOAT.S */
/* File: powerpc/binop-float.S */
	/*
	 * Generic float binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = f3 op f4".
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_F_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_F_S(f1, r5)			/* f1<- vBB+1 */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	fdivs	f1, f1, f2					/* f3<- op, r3-r6 changed */
					/* optional op; more space */

	SET_VREG_F_S(f1, r19)			/* vAA<- f1 */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_REM_FLOAT: /* 0xaa */
/* File: powerpc/OP_REM_FLOAT.S */
/* File: powerpc/binop-float.S */
	/*
	 * Generic float binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = f3 op f4".
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_F_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_F_S(f1, r5)			/* f1<- vBB+1 */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	bl fmodf@plt					/* f3<- op, r3-r6 changed */
					/* optional op; more space */

	SET_VREG_F_S(f1, r19)			/* vAA<- f1 */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_ADD_DOUBLE: /* 0xab */
/* File: powerpc/OP_ADD_DOUBLE.S */
/* File: powerpc/binop-double.S */
	/*
	 * Generic double binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = f3 op f4".
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_D_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_D_S(f1, r5)			/* f1<- vBB+1 */

	b .LOP_ADD_DOUBLE_split



/* ------------------------------ */
    .balign 128
.L_OP_SUB_DOUBLE: /* 0xac */
/* File: powerpc/OP_SUB_DOUBLE.S */
/* File: powerpc/binop-double.S */
	/*
	 * Generic double binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = f3 op f4".
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_D_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_D_S(f1, r5)			/* f1<- vBB+1 */

	b .LOP_SUB_DOUBLE_split



/* ------------------------------ */
    .balign 128
.L_OP_MUL_DOUBLE: /* 0xad */
/* File: powerpc/OP_MUL_DOUBLE.S */
/* File: powerpc/binop-double.S */
	/*
	 * Generic double binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = f3 op f4".
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_D_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_D_S(f1, r5)			/* f1<- vBB+1 */

	b .LOP_MUL_DOUBLE_split



/* ------------------------------ */
    .balign 128
.L_OP_DIV_DOUBLE: /* 0xae */
/* File: powerpc/OP_DIV_DOUBLE.S */
/* File: powerpc/binop-double.S */
	/*
	 * Generic double binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = f3 op f4".
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_D_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_D_S(f1, r5)			/* f1<- vBB+1 */

	b .LOP_DIV_DOUBLE_split



/* ------------------------------ */
    .balign 128
.L_OP_REM_DOUBLE: /* 0xaf */
/* File: powerpc/OP_REM_DOUBLE.S */
/* File: powerpc/binop-double.S */
	/*
	 * Generic double binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = f3 op f4".
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_D_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_D_S(f1, r5)			/* f1<- vBB+1 */

	b .LOP_REM_DOUBLE_split



/* ------------------------------ */
    .balign 128
.L_OP_ADD_INT_2ADDR: /* 0xb0 */
/* File: powerpc/OP_ADD_INT_2ADDR.S */
/* File: powerpc/binop2addr.S */
	/*
	 * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int/2addr, sub-int/2addr, and-int/2addr, or-int/2addr,
	 * 	xor-int/2addr, shl-int/2addr, shr-int/2addr, ushr-int/2addr,
	 *	mul-int/2addr,
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r19)			/* r3<- vA */
	GET_VREG_S(r4, r6)			/* r4<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	add	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_SUB_INT_2ADDR: /* 0xb1 */
/* File: powerpc/OP_SUB_INT_2ADDR.S */
/* File: powerpc/binop2addr.S */
	/*
	 * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int/2addr, sub-int/2addr, and-int/2addr, or-int/2addr,
	 * 	xor-int/2addr, shl-int/2addr, shr-int/2addr, ushr-int/2addr,
	 *	mul-int/2addr,
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r19)			/* r3<- vA */
	GET_VREG_S(r4, r6)			/* r4<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	sub	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_MUL_INT_2ADDR: /* 0xb2 */
/* File: powerpc/OP_MUL_INT_2ADDR.S */
/* File: powerpc/binop2addr.S */
	/*
	 * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int/2addr, sub-int/2addr, and-int/2addr, or-int/2addr,
	 * 	xor-int/2addr, shl-int/2addr, shr-int/2addr, ushr-int/2addr,
	 *	mul-int/2addr,
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r19)			/* r3<- vA */
	GET_VREG_S(r4, r6)			/* r4<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	mullw	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_DIV_INT_2ADDR: /* 0xb3 */
/* File: powerpc/OP_DIV_INT_2ADDR.S */
/* File: powerpc/binop2addr-divrem.S */
	/*
	 * For: div-int, rem-int
	 */

	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r19)			/* r3<- vA */
	GET_VREG_S(r4, r6)			/* r4<- vB */

	cmpwi	r4, 0				/* r4 == 0 ? */
	beq-	common_errDivideByZero		/* divide by zero error */
	lis	r5, 0x8000			/* r5<- 0x80000000 */
	cmpw	r3, r5				/* compare with r3 */
	bne+	1f				/* no, normal division */
	cmpwi	r4, -1				/* compare with -1 */
	bne+	1f				/* no, normal division */
	.if 1
	mr	r7, r3				/* division */
	.else
	li	r7, 0				/* remainder, 0 */
	.endif
	b	2f				/* and skip */

1:	divw	r7, r3, r4			/* divide */
	.if (! 1)
	mullw	r7, r7, r4			/* compute remainder */
	subf	r7, r7, r3
	.endif
2:
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	SET_VREG_S(r7, r19)			/* vAA<- r7 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_REM_INT_2ADDR: /* 0xb4 */
/* File: powerpc/OP_REM_INT_2ADDR.S */
/* File: powerpc/binop2addr-divrem.S */
	/*
	 * For: div-int, rem-int
	 */

	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r19)			/* r3<- vA */
	GET_VREG_S(r4, r6)			/* r4<- vB */

	cmpwi	r4, 0				/* r4 == 0 ? */
	beq-	common_errDivideByZero		/* divide by zero error */
	lis	r5, 0x8000			/* r5<- 0x80000000 */
	cmpw	r3, r5				/* compare with r3 */
	bne+	1f				/* no, normal division */
	cmpwi	r4, -1				/* compare with -1 */
	bne+	1f				/* no, normal division */
	.if 0
	mr	r7, r3				/* division */
	.else
	li	r7, 0				/* remainder, 0 */
	.endif
	b	2f				/* and skip */

1:	divw	r7, r3, r4			/* divide */
	.if (! 0)
	mullw	r7, r7, r4			/* compute remainder */
	subf	r7, r7, r3
	.endif
2:
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	SET_VREG_S(r7, r19)			/* vAA<- r7 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_AND_INT_2ADDR: /* 0xb5 */
/* File: powerpc/OP_AND_INT_2ADDR.S */
/* File: powerpc/binop2addr.S */
	/*
	 * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int/2addr, sub-int/2addr, and-int/2addr, or-int/2addr,
	 * 	xor-int/2addr, shl-int/2addr, shr-int/2addr, ushr-int/2addr,
	 *	mul-int/2addr,
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r19)			/* r3<- vA */
	GET_VREG_S(r4, r6)			/* r4<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	and	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_OR_INT_2ADDR: /* 0xb6 */
/* File: powerpc/OP_OR_INT_2ADDR.S */
/* File: powerpc/binop2addr.S */
	/*
	 * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int/2addr, sub-int/2addr, and-int/2addr, or-int/2addr,
	 * 	xor-int/2addr, shl-int/2addr, shr-int/2addr, ushr-int/2addr,
	 *	mul-int/2addr,
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r19)			/* r3<- vA */
	GET_VREG_S(r4, r6)			/* r4<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	or	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_XOR_INT_2ADDR: /* 0xb7 */
/* File: powerpc/OP_XOR_INT_2ADDR.S */
/* File: powerpc/binop2addr.S */
	/*
	 * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int/2addr, sub-int/2addr, and-int/2addr, or-int/2addr,
	 * 	xor-int/2addr, shl-int/2addr, shr-int/2addr, ushr-int/2addr,
	 *	mul-int/2addr,
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r19)			/* r3<- vA */
	GET_VREG_S(r4, r6)			/* r4<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	xor	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_SHL_INT_2ADDR: /* 0xb8 */
/* File: powerpc/OP_SHL_INT_2ADDR.S */
/* File: powerpc/binop2addr.S */
	/*
	 * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int/2addr, sub-int/2addr, and-int/2addr, or-int/2addr,
	 * 	xor-int/2addr, shl-int/2addr, shr-int/2addr, ushr-int/2addr,
	 *	mul-int/2addr,
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r19)			/* r3<- vA */
	GET_VREG_S(r4, r6)			/* r4<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	andi.	r4, r4, 31				/* optional op; may set condition codes */
	slw	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_SHR_INT_2ADDR: /* 0xb9 */
/* File: powerpc/OP_SHR_INT_2ADDR.S */
/* File: powerpc/binop2addr.S */
	/*
	 * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int/2addr, sub-int/2addr, and-int/2addr, or-int/2addr,
	 * 	xor-int/2addr, shl-int/2addr, shr-int/2addr, ushr-int/2addr,
	 *	mul-int/2addr,
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r19)			/* r3<- vA */
	GET_VREG_S(r4, r6)			/* r4<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	andi.	r4, r4, 31				/* optional op; may set condition codes */
	sraw	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_USHR_INT_2ADDR: /* 0xba */
/* File: powerpc/OP_USHR_INT_2ADDR.S */
/* File: powerpc/binop2addr.S */
	/*
	 * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int/2addr, sub-int/2addr, and-int/2addr, or-int/2addr,
	 * 	xor-int/2addr, shl-int/2addr, shr-int/2addr, ushr-int/2addr,
	 *	mul-int/2addr,
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r19)			/* r3<- vA */
	GET_VREG_S(r4, r6)			/* r4<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	andi.	r4, r4, 31				/* optional op; may set condition codes */
	srw	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_ADD_LONG_2ADDR: /* 0xbb */
/* File: powerpc/OP_ADD_LONG_2ADDR.S */
/* File: powerpc/binopWide2addr.S */
	/*
	 * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0-r1 op r2-r3".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
	 *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
	 *      sub-double/2addr, mul-double/2addr, div-double/2addr,
	 *      rem-double/2addr
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */

	lwzux	r3, r19, rFP			/* r3<- vA, r19<- &fp[A] */
	lwz	r4, 4(r19)			/* r4<- vA+1, r3/r4<- vA/vA+1 */
	lwzux	r5, r6, rFP			/* r5<- vB, r6<- &fp[B] */
	lwz	r6, 4(r6)			/* r6<- vB+1, r5/r6<- vB/vB+1 */

	.if 0
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	addc	r4, r4, r6				/* optional op; may set condition codes */
	adde	r3, r3, r5					/* result<- op, r3-r6 changed */
					/* optional op; */

	stw	r3, 0(r19)			/* vAA<- r0, r19<- &fp[A] */
	stw	r4, 4(r19)			/* vAA+1<- r1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_SUB_LONG_2ADDR: /* 0xbc */
/* File: powerpc/OP_SUB_LONG_2ADDR.S */
/* File: powerpc/binopWide2addr.S */
	/*
	 * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0-r1 op r2-r3".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
	 *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
	 *      sub-double/2addr, mul-double/2addr, div-double/2addr,
	 *      rem-double/2addr
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */

	lwzux	r3, r19, rFP			/* r3<- vA, r19<- &fp[A] */
	lwz	r4, 4(r19)			/* r4<- vA+1, r3/r4<- vA/vA+1 */
	lwzux	r5, r6, rFP			/* r5<- vB, r6<- &fp[B] */
	lwz	r6, 4(r6)			/* r6<- vB+1, r5/r6<- vB/vB+1 */

	.if 0
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	subfc	r4, r6, r4				/* optional op; may set condition codes */
	subfe	r3, r5, r3					/* result<- op, r3-r6 changed */
					/* optional op; */

	stw	r3, 0(r19)			/* vAA<- r0, r19<- &fp[A] */
	stw	r4, 4(r19)			/* vAA+1<- r1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_MUL_LONG_2ADDR: /* 0xbd */
/* File: powerpc/OP_MUL_LONG_2ADDR.S */
	/*
	 * Signed 64-bit integer multiply, "/2addr" version.
	 *
	 * See OP_MUL_LONG for an explanation.
	 *
	 */
	/* binop/2addr vA, vB */
	rlwinm  r7,rINST,26,26,29		/* r7<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */

	lwzux	r3, r7, rFP			/* r3<- vA, r5<- &fp[A] */
	lwz	r4, 4(r7)			/* r4<- vA+1, r3/r4<- vA/vA+1 */
	lwzux	r5, r6, rFP			/* r5<- vB, r6<- &fp[B] */
	lwz	r6, 4(r6)			/* r6<- vB+1, r5/r6<- vB/vB+1 */

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	mullw	r8,r5,r4			/* perform 64 bit multiplication */
	mullw	r3,r3,r6
	mulhwu	r9,r6,r4
	mullw	r4,r6,r4
	add	r0,r8,r3
	add	r3,r0,r9

	stw	r3, 0(r7)			/* vAA<- r3, r7<- &fp[A] */
	stw	r4, 4(r7)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* ------------------------------ */
    .balign 128
.L_OP_DIV_LONG_2ADDR: /* 0xbe */
/* File: powerpc/OP_DIV_LONG_2ADDR.S */
/* File: powerpc/binopWide2addr.S */
	/*
	 * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0-r1 op r2-r3".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
	 *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
	 *      sub-double/2addr, mul-double/2addr, div-double/2addr,
	 *      rem-double/2addr
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */

	lwzux	r3, r19, rFP			/* r3<- vA, r19<- &fp[A] */
	lwz	r4, 4(r19)			/* r4<- vA+1, r3/r4<- vA/vA+1 */
	lwzux	r5, r6, rFP			/* r5<- vB, r6<- &fp[B] */
	lwz	r6, 4(r6)			/* r6<- vB+1, r5/r6<- vB/vB+1 */

	.if 1
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	bl __divdi3@plt					/* result<- op, r3-r6 changed */
					/* optional op; */

	stw	r3, 0(r19)			/* vAA<- r0, r19<- &fp[A] */
	stw	r4, 4(r19)			/* vAA+1<- r1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_REM_LONG_2ADDR: /* 0xbf */
/* File: powerpc/OP_REM_LONG_2ADDR.S */
/* File: powerpc/binopWide2addr.S */
	/*
	 * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0-r1 op r2-r3".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
	 *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
	 *      sub-double/2addr, mul-double/2addr, div-double/2addr,
	 *      rem-double/2addr
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */

	lwzux	r3, r19, rFP			/* r3<- vA, r19<- &fp[A] */
	lwz	r4, 4(r19)			/* r4<- vA+1, r3/r4<- vA/vA+1 */
	lwzux	r5, r6, rFP			/* r5<- vB, r6<- &fp[B] */
	lwz	r6, 4(r6)			/* r6<- vB+1, r5/r6<- vB/vB+1 */

	.if 1
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	bl __moddi3@plt					/* result<- op, r3-r6 changed */
					/* optional op; */

	stw	r3, 0(r19)			/* vAA<- r0, r19<- &fp[A] */
	stw	r4, 4(r19)			/* vAA+1<- r1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_AND_LONG_2ADDR: /* 0xc0 */
/* File: powerpc/OP_AND_LONG_2ADDR.S */
/* File: powerpc/binopWide2addr.S */
	/*
	 * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0-r1 op r2-r3".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
	 *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
	 *      sub-double/2addr, mul-double/2addr, div-double/2addr,
	 *      rem-double/2addr
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */

	lwzux	r3, r19, rFP			/* r3<- vA, r19<- &fp[A] */
	lwz	r4, 4(r19)			/* r4<- vA+1, r3/r4<- vA/vA+1 */
	lwzux	r5, r6, rFP			/* r5<- vB, r6<- &fp[B] */
	lwz	r6, 4(r6)			/* r6<- vB+1, r5/r6<- vB/vB+1 */

	.if 0
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	and	r4, r4, r6				/* optional op; may set condition codes */
	and	r3, r3, r5					/* result<- op, r3-r6 changed */
					/* optional op; */

	stw	r3, 0(r19)			/* vAA<- r0, r19<- &fp[A] */
	stw	r4, 4(r19)			/* vAA+1<- r1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_OR_LONG_2ADDR: /* 0xc1 */
/* File: powerpc/OP_OR_LONG_2ADDR.S */
/* File: powerpc/binopWide2addr.S */
	/*
	 * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0-r1 op r2-r3".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
	 *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
	 *      sub-double/2addr, mul-double/2addr, div-double/2addr,
	 *      rem-double/2addr
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */

	lwzux	r3, r19, rFP			/* r3<- vA, r19<- &fp[A] */
	lwz	r4, 4(r19)			/* r4<- vA+1, r3/r4<- vA/vA+1 */
	lwzux	r5, r6, rFP			/* r5<- vB, r6<- &fp[B] */
	lwz	r6, 4(r6)			/* r6<- vB+1, r5/r6<- vB/vB+1 */

	.if 0
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	or		r4, r4, r6				/* optional op; may set condition codes */
	or	r3, r3, r5					/* result<- op, r3-r6 changed */
					/* optional op; */

	stw	r3, 0(r19)			/* vAA<- r0, r19<- &fp[A] */
	stw	r4, 4(r19)			/* vAA+1<- r1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_XOR_LONG_2ADDR: /* 0xc2 */
/* File: powerpc/OP_XOR_LONG_2ADDR.S */
/* File: powerpc/binopWide2addr.S */
	/*
	 * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0-r1 op r2-r3".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
	 *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
	 *      sub-double/2addr, mul-double/2addr, div-double/2addr,
	 *      rem-double/2addr
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */

	lwzux	r3, r19, rFP			/* r3<- vA, r19<- &fp[A] */
	lwz	r4, 4(r19)			/* r4<- vA+1, r3/r4<- vA/vA+1 */
	lwzux	r5, r6, rFP			/* r5<- vB, r6<- &fp[B] */
	lwz	r6, 4(r6)			/* r6<- vB+1, r5/r6<- vB/vB+1 */

	.if 0
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	xor	r4, r4, r6				/* optional op; may set condition codes */
	xor	r3, r5, r3					/* result<- op, r3-r6 changed */
					/* optional op; */

	stw	r3, 0(r19)			/* vAA<- r0, r19<- &fp[A] */
	stw	r4, 4(r19)			/* vAA+1<- r1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_SHL_LONG_2ADDR: /* 0xc3 */
/* File: powerpc/OP_SHL_LONG_2ADDR.S */
/* File: powerpc/fragWide2addr-shift-prolog.S */
	/*
	 * Generic 64-bit shift binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: shl-long, shr-long, ushr-long
	*/
	/* binopWide/2addr vA, vB */
	rlwinm  r7,rINST,26,26,29		/* r7<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */

	lwzux	r3, r7, rFP			/* r3<- vA, r7<- &fp[A] */
	lwz	r4, 4(r7)			/* r4<- vA+1, r3/r4<- vA/vA+1 */
	GET_VREG_S(r5, r6)			/* r5<- vB */
	clrlwi	r5, r5, 26			/* r5<- r5 & 0x3f */

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

/* File: powerpc/fragWide-shift.S */

	addic.	r0,r5,-32
	blt-	0f

	.if 1
	slw	r3,r4,r0
	li	r4,0
	b	1f
0:	rlwinm	r6,r4,31,1,31
	subfic	r9,r5,31
	srw	r0,r6,r9
	slw	r3,r3,r5
	or	r3,r0,r3
	slw	r4,r4,r5
	.endif

	.if 0
	srw	r4,r3,r0
	li	r3,0
	b	1f
0:	rlwinm	r6,r3,1,0,30
	subfic	r9,r5,31
	slw	r0,r6,r9
	srw	r4,r4,r5
	or	r4,r0,r4
	srw	r3,r3,r5
	.endif

	.if 0
	sraw	r4,r3,r0
	srawi	r3,r3,31
	b	1f
0:	rlwinm	r6,r3,1,0,30
	subfic	r9,r5,31
	slw	r0,r6,r9
	srw	r4,r4,r5
	or	r4,r0,r4
	sraw	r3,r3,r5
	.endif
1:

/* File: powerpc/fragWide2addr-shift-epilog.S */
	stw	r3, 0(r7)			/* vA<- r3 */
	stw	r4, 4(r7)			/* vA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_SHR_LONG_2ADDR: /* 0xc4 */
/* File: powerpc/OP_SHR_LONG_2ADDR.S */
/* File: powerpc/fragWide2addr-shift-prolog.S */
	/*
	 * Generic 64-bit shift binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: shl-long, shr-long, ushr-long
	*/
	/* binopWide/2addr vA, vB */
	rlwinm  r7,rINST,26,26,29		/* r7<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */

	lwzux	r3, r7, rFP			/* r3<- vA, r7<- &fp[A] */
	lwz	r4, 4(r7)			/* r4<- vA+1, r3/r4<- vA/vA+1 */
	GET_VREG_S(r5, r6)			/* r5<- vB */
	clrlwi	r5, r5, 26			/* r5<- r5 & 0x3f */

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

/* File: powerpc/fragWide-shift.S */

	addic.	r0,r5,-32
	blt-	0f

	.if 0
	slw	r3,r4,r0
	li	r4,0
	b	1f
0:	rlwinm	r6,r4,31,1,31
	subfic	r9,r5,31
	srw	r0,r6,r9
	slw	r3,r3,r5
	or	r3,r0,r3
	slw	r4,r4,r5
	.endif

	.if 0
	srw	r4,r3,r0
	li	r3,0
	b	1f
0:	rlwinm	r6,r3,1,0,30
	subfic	r9,r5,31
	slw	r0,r6,r9
	srw	r4,r4,r5
	or	r4,r0,r4
	srw	r3,r3,r5
	.endif

	.if 1
	sraw	r4,r3,r0
	srawi	r3,r3,31
	b	1f
0:	rlwinm	r6,r3,1,0,30
	subfic	r9,r5,31
	slw	r0,r6,r9
	srw	r4,r4,r5
	or	r4,r0,r4
	sraw	r3,r3,r5
	.endif
1:

/* File: powerpc/fragWide2addr-shift-epilog.S */
	stw	r3, 0(r7)			/* vA<- r3 */
	stw	r4, 4(r7)			/* vA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_USHR_LONG_2ADDR: /* 0xc5 */
/* File: powerpc/OP_USHR_LONG_2ADDR.S */
/* File: powerpc/fragWide2addr-shift-prolog.S */
	/*
	 * Generic 64-bit shift binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: shl-long, shr-long, ushr-long
	*/
	/* binopWide/2addr vA, vB */
	rlwinm  r7,rINST,26,26,29		/* r7<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */

	lwzux	r3, r7, rFP			/* r3<- vA, r7<- &fp[A] */
	lwz	r4, 4(r7)			/* r4<- vA+1, r3/r4<- vA/vA+1 */
	GET_VREG_S(r5, r6)			/* r5<- vB */
	clrlwi	r5, r5, 26			/* r5<- r5 & 0x3f */

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

/* File: powerpc/fragWide-shift.S */

	addic.	r0,r5,-32
	blt-	0f

	.if 0
	slw	r3,r4,r0
	li	r4,0
	b	1f
0:	rlwinm	r6,r4,31,1,31
	subfic	r9,r5,31
	srw	r0,r6,r9
	slw	r3,r3,r5
	or	r3,r0,r3
	slw	r4,r4,r5
	.endif

	.if 1
	srw	r4,r3,r0
	li	r3,0
	b	1f
0:	rlwinm	r6,r3,1,0,30
	subfic	r9,r5,31
	slw	r0,r6,r9
	srw	r4,r4,r5
	or	r4,r0,r4
	srw	r3,r3,r5
	.endif

	.if 0
	sraw	r4,r3,r0
	srawi	r3,r3,31
	b	1f
0:	rlwinm	r6,r3,1,0,30
	subfic	r9,r5,31
	slw	r0,r6,r9
	srw	r4,r4,r5
	or	r4,r0,r4
	sraw	r3,r3,r5
	.endif
1:

/* File: powerpc/fragWide2addr-shift-epilog.S */
	stw	r3, 0(r7)			/* vA<- r3 */
	stw	r4, 4(r7)			/* vA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


/* ------------------------------ */
    .balign 128
.L_OP_ADD_FLOAT_2ADDR: /* 0xc6 */
/* File: powerpc/OP_ADD_FLOAT_2ADDR.S */
/* File: powerpc/binop2addr-float.S */
	/*
	 * Generic double "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_F_S(f1, r19)			/* f1<- vA */
	GET_VREG_F_S(f2, r6)			/* f2<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	fadds	f1, f1, f2					/* result<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_F_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_SUB_FLOAT_2ADDR: /* 0xc7 */
/* File: powerpc/OP_SUB_FLOAT_2ADDR.S */
/* File: powerpc/binop2addr-float.S */
	/*
	 * Generic double "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_F_S(f1, r19)			/* f1<- vA */
	GET_VREG_F_S(f2, r6)			/* f2<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	fsubs	f1, f1, f2					/* result<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_F_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_MUL_FLOAT_2ADDR: /* 0xc8 */
/* File: powerpc/OP_MUL_FLOAT_2ADDR.S */
/* File: powerpc/binop2addr-float.S */
	/*
	 * Generic double "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_F_S(f1, r19)			/* f1<- vA */
	GET_VREG_F_S(f2, r6)			/* f2<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	fmuls	f1, f1, f2					/* result<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_F_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_DIV_FLOAT_2ADDR: /* 0xc9 */
/* File: powerpc/OP_DIV_FLOAT_2ADDR.S */
/* File: powerpc/binop2addr-float.S */
	/*
	 * Generic double "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_F_S(f1, r19)			/* f1<- vA */
	GET_VREG_F_S(f2, r6)			/* f2<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	fdivs	f1, f1, f2					/* result<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_F_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_REM_FLOAT_2ADDR: /* 0xca */
/* File: powerpc/OP_REM_FLOAT_2ADDR.S */
/* File: powerpc/binop2addr-float.S */
	/*
	 * Generic double "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_F_S(f1, r19)			/* f1<- vA */
	GET_VREG_F_S(f2, r6)			/* f2<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	bl fmodf@plt					/* result<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_F_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


/* ------------------------------ */
    .balign 128
.L_OP_ADD_DOUBLE_2ADDR: /* 0xcb */
/* File: powerpc/OP_ADD_DOUBLE_2ADDR.S */
/* File: powerpc/binop2addr-double.S */
	/*
	 * Generic double "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_D_S(f1, r19)			/* f1<- vA */
	GET_VREG_D_S(f2, r6)			/* f2<- vB */

	b .LOP_ADD_DOUBLE_2ADDR_split



/* ------------------------------ */
    .balign 128
.L_OP_SUB_DOUBLE_2ADDR: /* 0xcc */
/* File: powerpc/OP_SUB_DOUBLE_2ADDR.S */
/* File: powerpc/binop2addr-double.S */
	/*
	 * Generic double "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_D_S(f1, r19)			/* f1<- vA */
	GET_VREG_D_S(f2, r6)			/* f2<- vB */

	b .LOP_SUB_DOUBLE_2ADDR_split



/* ------------------------------ */
    .balign 128
.L_OP_MUL_DOUBLE_2ADDR: /* 0xcd */
/* File: powerpc/OP_MUL_DOUBLE_2ADDR.S */
/* File: powerpc/binop2addr-double.S */
	/*
	 * Generic double "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_D_S(f1, r19)			/* f1<- vA */
	GET_VREG_D_S(f2, r6)			/* f2<- vB */

	b .LOP_MUL_DOUBLE_2ADDR_split



/* ------------------------------ */
    .balign 128
.L_OP_DIV_DOUBLE_2ADDR: /* 0xce */
/* File: powerpc/OP_DIV_DOUBLE_2ADDR.S */
/* File: powerpc/binop2addr-double.S */
	/*
	 * Generic double "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_D_S(f1, r19)			/* f1<- vA */
	GET_VREG_D_S(f2, r6)			/* f2<- vB */

	b .LOP_DIV_DOUBLE_2ADDR_split



/* ------------------------------ */
    .balign 128
.L_OP_REM_DOUBLE_2ADDR: /* 0xcf */
/* File: powerpc/OP_REM_DOUBLE_2ADDR.S */
/* File: powerpc/binop2addr-double.S */
	/*
	 * Generic double "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_D_S(f1, r19)			/* f1<- vA */
	GET_VREG_D_S(f2, r6)			/* f2<- vB */

	b .LOP_REM_DOUBLE_2ADDR_split



/* ------------------------------ */
    .balign 128
.L_OP_ADD_INT_LIT16: /* 0xd0 */
/* File: powerpc/OP_ADD_INT_LIT16.S */
/* File: powerpc/binopLit16.S */
	/*
	 * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit16, rsub-int, mul-int/lit16, and-int/lit16, or-int/lit16,
	 *	xor-int/lit16
	 *
	 */
	/* binop/lit16 vA, vB, #+CCCC */
	FETCH_S(r4, 1)				/* r6<- ssssCCCC (sign-extended) */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	add	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_RSUB_INT: /* 0xd1 */
/* File: powerpc/OP_RSUB_INT.S */
/* this op is "rsub-int", but can be thought of as "rsub-int/lit16" */
/* File: powerpc/binopLit16.S */
	/*
	 * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit16, rsub-int, mul-int/lit16, and-int/lit16, or-int/lit16,
	 *	xor-int/lit16
	 *
	 */
	/* binop/lit16 vA, vB, #+CCCC */
	FETCH_S(r4, 1)				/* r6<- ssssCCCC (sign-extended) */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	sub     r3, r4, r3					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_MUL_INT_LIT16: /* 0xd2 */
/* File: powerpc/OP_MUL_INT_LIT16.S */
/* File: powerpc/binopLit16.S */
	/*
	 * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit16, rsub-int, mul-int/lit16, and-int/lit16, or-int/lit16,
	 *	xor-int/lit16
	 *
	 */
	/* binop/lit16 vA, vB, #+CCCC */
	FETCH_S(r4, 1)				/* r6<- ssssCCCC (sign-extended) */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	mullw	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_DIV_INT_LIT16: /* 0xd3 */
/* File: powerpc/OP_DIV_INT_LIT16.S */
/* File: powerpc/binopLit16-divrem.S */
	/*
	 * For: div-int/lit16, rem-int/lit16
	 */
	/* binop/lit16 vA, vB, #+CCCC */
	FETCH_S(r4, 1)				/* r6<- ssssCCCC (sign-extended) */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r4, 0				/* r4 == 0 ? */
	beq-	common_errDivideByZero		/* divide by zero error */
	lis	r5, 0x8000			/* r5<- 0x80000000 */
	cmpw	r3, r5				/* compare with r3 */
	bne+	1f				/* no, normal division */
	cmpwi	r4, -1				/* compare with -1 */
	bne+	1f				/* no, normal division */
	.if 1
	mr	r7, r3				/* division */
	.else
	li	r7, 0				/* remainder, 0 */
	.endif
	b	2f				/* and skip */
1:	divw	r7, r3, r4			/* divide */
	.if (! 1)
	mullw	r7, r7, r4			/* compute remainder */
	subf	r7, r7, r3
	.endif
2:
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	SET_VREG_S(r7, r19)			/* vAA<- r7 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_REM_INT_LIT16: /* 0xd4 */
/* File: powerpc/OP_REM_INT_LIT16.S */
/* File: powerpc/binopLit16-divrem.S */
	/*
	 * For: div-int/lit16, rem-int/lit16
	 */
	/* binop/lit16 vA, vB, #+CCCC */
	FETCH_S(r4, 1)				/* r6<- ssssCCCC (sign-extended) */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r4, 0				/* r4 == 0 ? */
	beq-	common_errDivideByZero		/* divide by zero error */
	lis	r5, 0x8000			/* r5<- 0x80000000 */
	cmpw	r3, r5				/* compare with r3 */
	bne+	1f				/* no, normal division */
	cmpwi	r4, -1				/* compare with -1 */
	bne+	1f				/* no, normal division */
	.if 0
	mr	r7, r3				/* division */
	.else
	li	r7, 0				/* remainder, 0 */
	.endif
	b	2f				/* and skip */
1:	divw	r7, r3, r4			/* divide */
	.if (! 0)
	mullw	r7, r7, r4			/* compute remainder */
	subf	r7, r7, r3
	.endif
2:
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	SET_VREG_S(r7, r19)			/* vAA<- r7 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_AND_INT_LIT16: /* 0xd5 */
/* File: powerpc/OP_AND_INT_LIT16.S */
/* File: powerpc/binopLit16.S */
	/*
	 * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit16, rsub-int, mul-int/lit16, and-int/lit16, or-int/lit16,
	 *	xor-int/lit16
	 *
	 */
	/* binop/lit16 vA, vB, #+CCCC */
	FETCH_S(r4, 1)				/* r6<- ssssCCCC (sign-extended) */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	and	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_OR_INT_LIT16: /* 0xd6 */
/* File: powerpc/OP_OR_INT_LIT16.S */
/* File: powerpc/binopLit16.S */
	/*
	 * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit16, rsub-int, mul-int/lit16, and-int/lit16, or-int/lit16,
	 *	xor-int/lit16
	 *
	 */
	/* binop/lit16 vA, vB, #+CCCC */
	FETCH_S(r4, 1)				/* r6<- ssssCCCC (sign-extended) */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	or	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_XOR_INT_LIT16: /* 0xd7 */
/* File: powerpc/OP_XOR_INT_LIT16.S */
/* File: powerpc/binopLit16.S */
	/*
	 * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit16, rsub-int, mul-int/lit16, and-int/lit16, or-int/lit16,
	 *	xor-int/lit16
	 *
	 */
	/* binop/lit16 vA, vB, #+CCCC */
	FETCH_S(r4, 1)				/* r6<- ssssCCCC (sign-extended) */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	xor	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_ADD_INT_LIT8: /* 0xd8 */
/* File: powerpc/OP_ADD_INT_LIT8.S */
/* File: powerpc/binopLit8.S */
	/*
	 * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, and-int/lit8,
	 *	or-int/lit8, xor-int/lit8, shl-int/lit8, shr-int/lit8,
	 *	ushr-int/lit8
	 *
	 */
	/* binop/lit8 vAA, vBB, #+CC */
	FETCH_S(r6, 1)				/* r6<- ssssCCBB (sign-extended for CC) */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm  r5,r6,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	srawi	r4, r6, 8			/* r4<- ssssssCC (sign extended) */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	add	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_RSUB_INT_LIT8: /* 0xd9 */
/* File: powerpc/OP_RSUB_INT_LIT8.S */
/* File: powerpc/binopLit8.S */
	/*
	 * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, and-int/lit8,
	 *	or-int/lit8, xor-int/lit8, shl-int/lit8, shr-int/lit8,
	 *	ushr-int/lit8
	 *
	 */
	/* binop/lit8 vAA, vBB, #+CC */
	FETCH_S(r6, 1)				/* r6<- ssssCCBB (sign-extended for CC) */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm  r5,r6,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	srawi	r4, r6, 8			/* r4<- ssssssCC (sign extended) */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	sub	r3, r4, r3					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_MUL_INT_LIT8: /* 0xda */
/* File: powerpc/OP_MUL_INT_LIT8.S */
/* File: powerpc/binopLit8.S */
	/*
	 * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, and-int/lit8,
	 *	or-int/lit8, xor-int/lit8, shl-int/lit8, shr-int/lit8,
	 *	ushr-int/lit8
	 *
	 */
	/* binop/lit8 vAA, vBB, #+CC */
	FETCH_S(r6, 1)				/* r6<- ssssCCBB (sign-extended for CC) */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm  r5,r6,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	srawi	r4, r6, 8			/* r4<- ssssssCC (sign extended) */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	mullw	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_DIV_INT_LIT8: /* 0xdb */
/* File: powerpc/OP_DIV_INT_LIT8.S */
/* File: powerpc/binopLit8-divrem.S */
	/*
	 * For: div-int/lit8, rem-int/lit8
	 */
	/* binop/lit8 vAA, vBB, #+CC */
	FETCH_S(r6, 1)				/* r6<- ssssCCBB (sign-extended for CC) */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm  r5,r6,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	srawi	r4, r6, 8			/* r4<- ssssssCC (sign extended) */

	cmpwi	r4, 0				/* r4 == 0 ? */
	beq-	common_errDivideByZero		/* divide by zero error */
	lis	r5, 0x8000			/* r5<- 0x80000000 */
	cmpw	r3, r5				/* compare with r3 */
	bne+	1f				/* no, normal division */
	cmpwi	r4, -1				/* compare with -1 */
	bne+	1f				/* no, normal division */
	.if 1
	mr	r7, r3				/* division */
	.else
	li	r7, 0				/* remainder, 0 */
	.endif
	b	2f				/* and skip */
1:	divw	r7, r3, r4			/* divide */
	.if (! 1)
	mullw	r7, r7, r4			/* compute remainder */
	subf	r7, r7, r3
	.endif
2:
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	SET_VREG_S(r7, r19)			/* vAA<- r7 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_REM_INT_LIT8: /* 0xdc */
/* File: powerpc/OP_REM_INT_LIT8.S */
/* File: powerpc/binopLit8-divrem.S */
	/*
	 * For: div-int/lit8, rem-int/lit8
	 */
	/* binop/lit8 vAA, vBB, #+CC */
	FETCH_S(r6, 1)				/* r6<- ssssCCBB (sign-extended for CC) */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm  r5,r6,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	srawi	r4, r6, 8			/* r4<- ssssssCC (sign extended) */

	cmpwi	r4, 0				/* r4 == 0 ? */
	beq-	common_errDivideByZero		/* divide by zero error */
	lis	r5, 0x8000			/* r5<- 0x80000000 */
	cmpw	r3, r5				/* compare with r3 */
	bne+	1f				/* no, normal division */
	cmpwi	r4, -1				/* compare with -1 */
	bne+	1f				/* no, normal division */
	.if 0
	mr	r7, r3				/* division */
	.else
	li	r7, 0				/* remainder, 0 */
	.endif
	b	2f				/* and skip */
1:	divw	r7, r3, r4			/* divide */
	.if (! 0)
	mullw	r7, r7, r4			/* compute remainder */
	subf	r7, r7, r3
	.endif
2:
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	SET_VREG_S(r7, r19)			/* vAA<- r7 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_AND_INT_LIT8: /* 0xdd */
/* File: powerpc/OP_AND_INT_LIT8.S */
/* File: powerpc/binopLit8.S */
	/*
	 * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, and-int/lit8,
	 *	or-int/lit8, xor-int/lit8, shl-int/lit8, shr-int/lit8,
	 *	ushr-int/lit8
	 *
	 */
	/* binop/lit8 vAA, vBB, #+CC */
	FETCH_S(r6, 1)				/* r6<- ssssCCBB (sign-extended for CC) */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm  r5,r6,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	srawi	r4, r6, 8			/* r4<- ssssssCC (sign extended) */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	and	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_OR_INT_LIT8: /* 0xde */
/* File: powerpc/OP_OR_INT_LIT8.S */
/* File: powerpc/binopLit8.S */
	/*
	 * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, and-int/lit8,
	 *	or-int/lit8, xor-int/lit8, shl-int/lit8, shr-int/lit8,
	 *	ushr-int/lit8
	 *
	 */
	/* binop/lit8 vAA, vBB, #+CC */
	FETCH_S(r6, 1)				/* r6<- ssssCCBB (sign-extended for CC) */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm  r5,r6,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	srawi	r4, r6, 8			/* r4<- ssssssCC (sign extended) */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	or		r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_XOR_INT_LIT8: /* 0xdf */
/* File: powerpc/OP_XOR_INT_LIT8.S */
/* File: powerpc/binopLit8.S */
	/*
	 * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, and-int/lit8,
	 *	or-int/lit8, xor-int/lit8, shl-int/lit8, shr-int/lit8,
	 *	ushr-int/lit8
	 *
	 */
	/* binop/lit8 vAA, vBB, #+CC */
	FETCH_S(r6, 1)				/* r6<- ssssCCBB (sign-extended for CC) */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm  r5,r6,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	srawi	r4, r6, 8			/* r4<- ssssssCC (sign extended) */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	xor	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_SHL_INT_LIT8: /* 0xe0 */
/* File: powerpc/OP_SHL_INT_LIT8.S */
/* File: powerpc/binopLit8.S */
	/*
	 * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, and-int/lit8,
	 *	or-int/lit8, xor-int/lit8, shl-int/lit8, shr-int/lit8,
	 *	ushr-int/lit8
	 *
	 */
	/* binop/lit8 vAA, vBB, #+CC */
	FETCH_S(r6, 1)				/* r6<- ssssCCBB (sign-extended for CC) */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm  r5,r6,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	srawi	r4, r6, 8			/* r4<- ssssssCC (sign extended) */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	andi.	r4, r4, 31				/* optional op; may set condition codes */
	slw	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_SHR_INT_LIT8: /* 0xe1 */
/* File: powerpc/OP_SHR_INT_LIT8.S */
/* File: powerpc/binopLit8.S */
	/*
	 * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, and-int/lit8,
	 *	or-int/lit8, xor-int/lit8, shl-int/lit8, shr-int/lit8,
	 *	ushr-int/lit8
	 *
	 */
	/* binop/lit8 vAA, vBB, #+CC */
	FETCH_S(r6, 1)				/* r6<- ssssCCBB (sign-extended for CC) */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm  r5,r6,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	srawi	r4, r6, 8			/* r4<- ssssssCC (sign extended) */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	andi.	r4, r4, 31				/* optional op; may set condition codes */
	sraw	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_USHR_INT_LIT8: /* 0xe2 */
/* File: powerpc/OP_USHR_INT_LIT8.S */
/* File: powerpc/binopLit8.S */
	/*
	 * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, and-int/lit8,
	 *	or-int/lit8, xor-int/lit8, shl-int/lit8, shr-int/lit8,
	 *	ushr-int/lit8
	 *
	 */
	/* binop/lit8 vAA, vBB, #+CC */
	FETCH_S(r6, 1)				/* r6<- ssssCCBB (sign-extended for CC) */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm  r5,r6,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	srawi	r4, r6, 8			/* r4<- ssssssCC (sign extended) */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	andi.	r4, r4, 31				/* optional op; may set condition codes */
	srw	r3, r3, r4					/* r3<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_S(r3, r19)		/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */



/* ------------------------------ */
    .balign 128
.L_OP_IGET_VOLATILE: /* 0xe3 */
/* File: powerpc/OP_IGET_VOLATILE.S */
/* File: powerpc/OP_IGET.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r3, offInstField_byteOffset(r3)	/* r3<- byte offset of field */
	lwzx	r3, r20, r3			/* r3<- obj.field (8/16/32 bits) */
	msync				/* acquiring load */
	.ifnb 
						/* perform masking (if requested) */
	.endif
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_IPUT_VOLATILE: /* 0xe4 */
/* File: powerpc/OP_IPUT_VOLATILE.S */
/* File: powerpc/OP_IPUT.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iput, iput-boolean, iput-byte, iput-char, iput-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r4, offInstField_byteOffset(r3)	/* r4<- byte offset of field */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_VREG_S(r3, r19)			/* fp[A]<- r3 */
	.ifnb 
						/* perform masking (if requested) */
	.endif
	msync				/* releasing store */
	stwx	r3, r20, r4			/* r4<- obj.field (8/16/32 bits) */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_SGET_VOLATILE: /* 0xe5 */
/* File: powerpc/OP_SGET_VOLATILE.S */
/* File: powerpc/OP_SGET.S */
	/*
	 * General 32-bit SGET handler.
	 *
	 * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwz	r3, offStaticField_value(r3)	/* r3<- byte offset of field */
	msync				/* acquiring load */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	.ifnb 
	
	.endif
	stwx	r3, r19, rFP			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_SPUT_VOLATILE: /* 0xe6 */
/* File: powerpc/OP_SPUT_VOLATILE.S */
/* File: powerpc/OP_SPUT.S */
	/*
	 * General 32-bit SPUT handler.
	 *
	 * for: sput, sput-boolean, sput-byte, sput-char, sput-short
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved StaticField ptr */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwzx	r4, r19, rFP			/* r3<- fp[A] */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	.ifnb 
	
	.endif
	msync				/* releasing store */
	stw	r4, offStaticField_value(r3)	/* field<- vAA */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_IGET_OBJECT_VOLATILE: /* 0xe7 */
/* File: powerpc/OP_IGET_OBJECT_VOLATILE.S */
/* File: powerpc/OP_IGET.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r3, offInstField_byteOffset(r3)	/* r3<- byte offset of field */
	lwzx	r3, r20, r3			/* r3<- obj.field (8/16/32 bits) */
	msync				/* acquiring load */
	.ifnb 
						/* perform masking (if requested) */
	.endif
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_IGET_WIDE_VOLATILE: /* 0xe8 */
/* File: powerpc/OP_IGET_WIDE_VOLATILE.S */
/* File: powerpc/OP_IGET_WIDE.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r3, offInstField_byteOffset(r3)	/* r3<- byte offset of field */
	.if	1
	add	r3, r20, r3
	bl	dvmQuasiAtomicRead64@plt
	.else
	lwzux	r3, r20, r3			/* r3<- obj.field (8/16/32 bits) */
	lwz	r4, 4(r20)			/* r4 (lo) */
	.endif
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	stwux	r3, r19, rFP			/* fp[A]<- r3 (hi) */
	stw	r4, 4(r19)			/* <- r4 (lo) */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_IPUT_WIDE_VOLATILE: /* 0xe9 */
/* File: powerpc/OP_IPUT_WIDE_VOLATILE.S */
/* File: powerpc/OP_IPUT_WIDE.S */
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r5, offInstField_byteOffset(r3)	/* r4<- byte offset of field */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	lwzux	r3, r19, rFP			/* r3<-fp[A] (hi) */
	lwz	r4, 4(r19)			/* lo */
	.if 1
	add	r5, r20, r5
	bl	dvmQuasiAtomicSwap64@plt
	.else
	stwux	r3, r20, r5			/* obj.field(64 bits) <- r3 (hi)  */
	stw	r4, 4(r20)			/* lo */
	.endif
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_SGET_WIDE_VOLATILE: /* 0xea */
/* File: powerpc/OP_SGET_WIDE_VOLATILE.S */
/* File: powerpc/OP_SGET_WIDE.S */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved StaticField ptr */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	
	.if	1
	addi	r3, r3, offStaticField_value
	bl	dvmQuasiAtomicRead64@plt
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	stwux	r3, r19, rFP			/* fp[A]<- r3 */
	stw	r4, 4(r19)
	.else
	lwz	r4, offStaticField_value(r3)
	lwz	r5, offStaticField_value+4(r3)
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	stwux	r4, r19, rFP			/* fp[A]<- r3 */
	stw	r5, 4(r19)
	.endif
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_SPUT_WIDE_VOLATILE: /* 0xeb */
/* File: powerpc/OP_SPUT_WIDE_VOLATILE.S */
/* File: powerpc/OP_SPUT_WIDE.S */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved StaticField ptr */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:
	.if	1
	addi	r5, r3, offStaticField_value
	lwzux	r3, r19, rFP			/* r3<- fp[A] */
	lwz	r4, 4(r19)
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	bl	dvmQuasiAtomicSwap64@plt
	.else
	lwzux	r4, r19, rFP			/* r4<- fp[A] */
	lwz	r5, 4(r19)
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	stw	r4, offStaticField_value(r3)	/* (hi) byte offset of field */
	stw	r5, offStaticField_value+4(r3)	/* (lo)  */
	.endif
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_BREAKPOINT: /* 0xec */
/* File: powerpc/OP_BREAKPOINT.S */
/* File: powerpc/unused.S */
	b	common_abort


/* ------------------------------ */
    .balign 128
.L_OP_THROW_VERIFICATION_ERROR: /* 0xed */
/* File: powerpc/OP_THROW_VERIFICATION_ERROR.S */
	/*
	 * Handle a throw-verification-error instruction.  This throws an
	 * exception for an error discovered during verification.  The
	 * exception is indicated by AA, with some detail provided by BBBB.
	 */
	/* throw-verification-error AA, ref@BBBB */
	rlwinm  r4,rINST,24,24,31		/* r4<- AA */
	lwz	r3, offGlue_method(rGLUE)	/* r3<- glue->method */
	FETCH(r5, 1)				/* r5<- BBBB */
	EXPORT_PC()				/* export the PC */
	bl	dvmThrowVerificationError@plt	/* always throws */
	b	common_exceptionThrown		/* handle exception */

/* ------------------------------ */
    .balign 128
.L_OP_EXECUTE_INLINE: /* 0xee */
/* File: powerpc/OP_EXECUTE_INLINE.S */
	/*
	 * Execute a "native inline" instruction.
	 *
	 * We need to call:
	 *  bool (func)(u4 arg0, u4 arg1, u4 arg2, u4 arg3, JValue* pResult)
	 */
	/* [opt] execute-inline vAA, {vC, vD, vE, vF}, inline@BBBB */
	FETCH(r19, 1)				/* r19<- BBBB */
	FETCH(r20, 2)				/* r20<- FEDC */
	EXPORT_PC()				/* can throw */
	srwi	r3, rINST, 12			/* r3<- B */
	subfic	r3, r3, 4			/* r3<- 4-r3 */
	lis	r6, .LOP_EXECUTE_INLINE_continue@ha	/* r6<- start of insn block */
	addi	r6, r6, .LOP_EXECUTE_INLINE_continue@l
	slwi	r3, r3, 3			/* 2 insn  */
	add	r0, r6, r3			/* point to first insn of switch */
	mtctr	r0
	bctrl					/* branch & link */
	cmpwi	r3, 0				/* test boolean result of inline */
	beq-	common_exceptionThrown		/* returned false, handle exception */
	FETCH_ADVANCE_INST(3)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_EXECUTE_INLINE_RANGE: /* 0xef */
/* File: powerpc/OP_EXECUTE_INLINE_RANGE.S */
	/*
	 * Execute a "native inline" instruction, using "/range" semantics.
	 * Same idea as execute-inline, but we get the args differently.
	 *
	 * We need to call:
	 *  bool (func)(u4 arg0, u4 arg1, u4 arg2, u4 arg3, JValue* pResult)
	 */
	/* [opt] execute-inline/range {vCCCC..v(CCCC+AA-1)}, inline@BBBB */
	FETCH(r19, 1)				/* r19<- BBBB */
	FETCH(r20, 2)				/* r20<- CCCC */
	EXPORT_PC()				/* can throw */
	srwi	r3, rINST, 8			/* r3<- AA */
	subfic	r3, r3, 4			/* r3<- 4-r3 */
	slwi	r20, r20, 2			/* r20<- CCCC << 2 = vBase */
	lis	r6, .LOP_EXECUTE_INLINE_RANGE_continue@ha	/* r6<- start of insn block */
	addi	r6, r6, .LOP_EXECUTE_INLINE_RANGE_continue@l
	slwi	r3, r3, 3			/* 2 insn  */
	add	r0, r6, r3			/* point to first insn of switch */
	mtctr	r0
	bctrl					/* branch & link */
	cmpwi	r3, 0				/* test boolean result of inline */
	beq-	common_exceptionThrown		/* returned false, handle exception */
	FETCH_ADVANCE_INST(3)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_DIRECT_EMPTY: /* 0xf0 */
/* File: powerpc/OP_INVOKE_DIRECT_EMPTY.S */
	/*
	 * invoke-direct-empty is a no-op in a "standard" interpreter.
	 */
	FETCH_ADVANCE_INST(3)			/* advance to next instr, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* ip<- opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_F1: /* 0xf1 */
/* File: powerpc/OP_UNUSED_F1.S */
/* File: powerpc/unused.S */
	b	common_abort


/* ------------------------------ */
    .balign 128
.L_OP_IGET_QUICK: /* 0xf2 */
/* File: powerpc/OP_IGET_QUICK.S */
	/* For: iget-quick, iget-object-quick */
	/* op vA, vB, offset@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r5,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field byte offset */
	GET_VREG_S(r6, r5)			/* r6<- object we're operating on */
	cmpwi	r6, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	lwzx	r3, r6, r4			/* r3<- obj.field (always 32 bits)*/
	SET_VREG_S(r3, r19)			/* fp[A]<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_IGET_WIDE_QUICK: /* 0xf3 */
/* File: powerpc/OP_IGET_WIDE_QUICK.S */
	/* For: iget-wide-quick */
	/* op vA, vB, offset@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r5,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field byte offset */
	GET_VREG_S(r6, r5)			/* r6<- object we're operating on */
	cmpwi	r6, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	lwzux	r3, r6, r4			/* r3<- obj.field (always 32 bits)*/
	lwz	r4, 4(r6)
	stwux	r3, r19, rFP			/* fp[A]<- r3 */
	stw	r4, 4(r19)
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_IGET_OBJECT_QUICK: /* 0xf4 */
/* File: powerpc/OP_IGET_OBJECT_QUICK.S */
/* File: powerpc/OP_IGET_QUICK.S */
	/* For: iget-quick, iget-object-quick */
	/* op vA, vB, offset@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r5,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field byte offset */
	GET_VREG_S(r6, r5)			/* r6<- object we're operating on */
	cmpwi	r6, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	lwzx	r3, r6, r4			/* r3<- obj.field (always 32 bits)*/
	SET_VREG_S(r3, r19)			/* fp[A]<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_IPUT_QUICK: /* 0xf5 */
/* File: powerpc/OP_IPUT_QUICK.S */
	/* For: iput-quick */
	/* op vA, vB, offset@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r5,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field byte offset */
	GET_VREG_S(r6, r5)			/* r6<- object we're operating on */
	cmpwi	r6, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_VREG_S(r3, r19)			/* fp[A]<- r3 */
	stwx	r3, r6, r4			/* r3<- obj.field (always 32 bits)*/
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_IPUT_WIDE_QUICK: /* 0xf6 */
/* File: powerpc/OP_IPUT_WIDE_QUICK.S */
	/* For: iput-wide-quick */
	/* op vA, vB, offset@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r5,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field byte offset */
	GET_VREG_S(r6, r5)			/* r6<- object we're operating on */
	cmpwi	r6, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	lwzux	r3, r19, rFP			/* fp[A]<- r3 */
	lwz	r5, 4(r19)
	stwux	r3, r6, r4			/* r3<- obj.field (always 32 bits)*/
	stw	r5, 4(r6)
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_IPUT_OBJECT_QUICK: /* 0xf7 */
/* File: powerpc/OP_IPUT_OBJECT_QUICK.S */
	/* For: iput-object-quick */
	/* op vA, vB, offset@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r5,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field byte offset */
	GET_VREG_S(r6, r5)			/* r6<- object we're operating on */
	cmpwi	r6, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_VREG_S(r3, r19)			/* fp[A]<- r3 */
	stwx	r3, r6, r4			/* obj.field (always 32 bits) <- r3 */
	lwz	r5, offGlue_cardTable(rGLUE)	/* r5<- card table base */
	rlwinm	r6, r6, 32-GC_CARD_SHIFT, GC_CARD_SHIFT, 31
	cmpwi	r3, 0				/* stored a null reference ? */
	beq- 1f
	stbx	r5, r5, r6			/* mark card if not zero */
1:
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_VIRTUAL_QUICK: /* 0xf8 */
/* File: powerpc/OP_INVOKE_VIRTUAL_QUICK.S */
	/*
	 * Handle a virtual method call.
	 *
	 * for: invoke-virtual, invoke-virtual/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op vAA, {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	FETCH(r19, 2)				/* r19<- GFED or CCCC */
	.if	(!0)
	rlwinm  r19,r19,2,26,29			/* r19<- D << 2 */
	.else
	slwi	r19, r19, 2			/* r19<- CCCC << 2 */
	.endif
	GET_VREG_S(r20, r19)			/* r20<- "this" ptr */
	cmpwi	r20, 0				/* null "this" ref? */
	beq- 	common_errNullObject		/* yes, throw exception */
	lwz	r6, offObject_clazz(r20)	/* r6<- thisPtr->clazz */
	lwz	r6, offClassObject_vtable(r6)	/* r6<- thisPtr->clazz->vtable */
	slwi	r5, r4, 2			/* r5<- BBBB << 2 */
	EXPORT_PC()				/* invoke must export */
	lwzx	r3, r6, r5			/* r3<- vtable[methodIndex] */
	b	common_invokeMethodNoRange

/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_VIRTUAL_QUICK_RANGE: /* 0xf9 */
/* File: powerpc/OP_INVOKE_VIRTUAL_QUICK_RANGE.S */
/* File: powerpc/OP_INVOKE_VIRTUAL_QUICK.S */
	/*
	 * Handle a virtual method call.
	 *
	 * for: invoke-virtual, invoke-virtual/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op vAA, {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	FETCH(r19, 2)				/* r19<- GFED or CCCC */
	.if	(!1)
	rlwinm  r19,r19,2,26,29			/* r19<- D << 2 */
	.else
	slwi	r19, r19, 2			/* r19<- CCCC << 2 */
	.endif
	GET_VREG_S(r20, r19)			/* r20<- "this" ptr */
	cmpwi	r20, 0				/* null "this" ref? */
	beq- 	common_errNullObject		/* yes, throw exception */
	lwz	r6, offObject_clazz(r20)	/* r6<- thisPtr->clazz */
	lwz	r6, offClassObject_vtable(r6)	/* r6<- thisPtr->clazz->vtable */
	slwi	r5, r4, 2			/* r5<- BBBB << 2 */
	EXPORT_PC()				/* invoke must export */
	lwzx	r3, r6, r5			/* r3<- vtable[methodIndex] */
	b	common_invokeMethodRange


/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_SUPER_QUICK: /* 0xfa */
/* File: powerpc/OP_INVOKE_SUPER_QUICK.S */
	/*
	 * Handle an optimized "super" method call.
	 *
	 * for: [opt] invoke-super-quick, invoke-super-quick/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op vAA, {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	FETCH(r19, 2)				/* r19<- GFED or CCCC */
	.if	(!0)
	rlwinm  r19,r19,2,26,29			/* r19<- D << 2 */
	.else
	slwi	r19, r19, 2			/* r19<- CCCC << 2 */
	.endif
	GET_VREG_S(r20, r19)			/* r20<- "this" ptr */
	EXPORT_PC()				/* invoke must export */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	cmpwi	r20, 0				/* null "this" ref? */
	lwz	r5, offMethod_clazz(r5)		/* r5<- method->clazz */
	beq- 	common_errNullObject		/* yes, throw exception */
	lwz	r5, offClassObject_super(r5)	/* r5<- method->clazz->super */
	lwz	r6, offClassObject_vtable(r5)	/* r6<- super->vtable[BBBB] */
	slwi	r5, r4, 2			/* r5<- BBBB << 2 */
	lwzx	r3, r6, r5			/* r3<- vtable[methodIndex] */
	b	common_invokeMethodNoRange

/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_SUPER_QUICK_RANGE: /* 0xfb */
/* File: powerpc/OP_INVOKE_SUPER_QUICK_RANGE.S */
/* File: powerpc/OP_INVOKE_SUPER_QUICK.S */
	/*
	 * Handle an optimized "super" method call.
	 *
	 * for: [opt] invoke-super-quick, invoke-super-quick/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op vAA, {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	FETCH(r19, 2)				/* r19<- GFED or CCCC */
	.if	(!1)
	rlwinm  r19,r19,2,26,29			/* r19<- D << 2 */
	.else
	slwi	r19, r19, 2			/* r19<- CCCC << 2 */
	.endif
	GET_VREG_S(r20, r19)			/* r20<- "this" ptr */
	EXPORT_PC()				/* invoke must export */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	cmpwi	r20, 0				/* null "this" ref? */
	lwz	r5, offMethod_clazz(r5)		/* r5<- method->clazz */
	beq- 	common_errNullObject		/* yes, throw exception */
	lwz	r5, offClassObject_super(r5)	/* r5<- method->clazz->super */
	lwz	r6, offClassObject_vtable(r5)	/* r6<- super->vtable[BBBB] */
	slwi	r5, r4, 2			/* r5<- BBBB << 2 */
	lwzx	r3, r6, r5			/* r3<- vtable[methodIndex] */
	b	common_invokeMethodRange


/* ------------------------------ */
    .balign 128
.L_OP_IPUT_OBJECT_VOLATILE: /* 0xfc */
/* File: powerpc/OP_IPUT_OBJECT_VOLATILE.S */
/* File: powerpc/OP_IPUT_OBJECT.S */
	/*
	 * Object field put
	 *
	 * for: iput-object
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r4, offInstField_byteOffset(r3)	/* r4<- byte offset of field */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_VREG_S(r3, r19)			/* fp[A]<- r3 */
	msync
	stwx	r3, r20, r4			/* obj.field (32 bits) <- r3 */
	lwz	r5, offGlue_cardTable(rGLUE)	/* r5<- card table base */
	rlwinm	r20, r20, 32-GC_CARD_SHIFT, GC_CARD_SHIFT, 31
	cmpwi	r3, 0				/* stored a null reference ? */
	beq- 1f
	stbx	r5, r5, r20			/* mark card if not zero */
1:
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_SGET_OBJECT_VOLATILE: /* 0xfd */
/* File: powerpc/OP_SGET_OBJECT_VOLATILE.S */
/* File: powerpc/OP_SGET.S */
	/*
	 * General 32-bit SGET handler.
	 *
	 * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwz	r3, offStaticField_value(r3)	/* r3<- byte offset of field */
	msync				/* acquiring load */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	.ifnb 
	
	.endif
	stwx	r3, r19, rFP			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_SPUT_OBJECT_VOLATILE: /* 0xfe */
/* File: powerpc/OP_SPUT_OBJECT_VOLATILE.S */
/* File: powerpc/OP_SPUT_OBJECT.S */
	/*
	 * 32-bit SPUT handler for objects
	 *
	 * for: sput-object
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved StaticField ptr */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	lwzx	r4, r19, rFP			/* r3<- fp[A] */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	stw	r4, offStaticField_value(r3)	/* field<- vAA */
	lwz	r20, offField_clazz(r3)
	lwz	r5, offGlue_cardTable(rGLUE)	/* r5<- card table base */
	rlwinm	r20, r20, 32-GC_CARD_SHIFT, GC_CARD_SHIFT, 31
	cmpwi	r4, 0				/* stored a null reference ? */
	beq- 1f
	stbx	r5, r5, r20			/* mark card if not zero */
1:
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_FF: /* 0xff */
/* File: powerpc/OP_UNUSED_FF.S */
/* File: powerpc/unused.S */
	b	common_abort



    .balign 128
    .size   dvmAsmInstructionStart, .-dvmAsmInstructionStart
    .global dvmAsmInstructionEnd
dvmAsmInstructionEnd:

/*
 * ===========================================================================
 *  Sister implementations
 * ===========================================================================
 */
    .global dvmAsmSisterStart
    .type   dvmAsmSisterStart, %function
    .text
    .balign 4
dvmAsmSisterStart:

/* continuation for OP_CHECK_CAST */

.LOP_CHECK_CAST_throw:
	/* A cast has failed.  We need to throw a ClassCastException with the */
	/* class of the object that failed to be cast. */
	EXPORT_PC()				/* about to throw */
	lis	r3, .LstrClassCastException@ha	/* r3<- string message */
	addi	r3, r3, .LstrClassCastException@l
	lwz	r6, offObject_clazz(r19)	/* r6<- obj->clazz */
	lwz	r4, offClassObject_descriptor(r6)	/* r4<- obj->clazz->descriptor */
	bl	dvmThrowExceptionWithClassMessage@plt
	b       common_exceptionThrown

	/*
	 * Resolution required.  This is the least-likely path.
	 *
	 *  r5 holds BBBB << 2
	 *  r19 holds object
	 */
.LOP_CHECK_CAST_resolve:
	EXPORT_PC()				/* resolve() could throw */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	srwi	r4, r5, 2			/* r4<- BBBB */
	li	r5, 0				/* r5<- false */
	bl	dvmResolveClass@plt		/* r3<- resolved ClassObject ptr */
	cmpwi	r3, 0				/* got null? */
	beq-	common_exceptionThrown		/* yes, handle exception */
	mr	r4, r3				/* r4<- class resolved from BBBB */
	b	.LOP_CHECK_CAST_resolved		/* pick up where we left off */

/* continuation for OP_INSTANCE_OF */

	/*
	 * Resolution required.  This is the least-likely path.
	 *
	 *  r5 holds CCCC << 2
	 *  r19 holds A
	 */
.LOP_INSTANCE_OF_resolve:
	EXPORT_PC()				/* resolve() could throw */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	srwi	r4, r5, 2			/* r4<- CCCC */
	li	r5, 0				/* r5<- true */
	bl	dvmResolveClass@plt		/* r3<- resolved ClassObject ptr */
	cmpwi	r3, 0				/* got null? */
	beq-	common_exceptionThrown		/* yes, handle exception */
	mr	r4, r3				/* r4<- class resolved from CCCC */
	rlwinm	r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r6)			/* r3<- vB (object) */
	lwz	r3, offObject_clazz(r3)		/* r3<- obj->clazz */
	b	.LOP_INSTANCE_OF_resolved		/* pick up where we left off */

/* continuation for OP_NEW_INSTANCE */

    /*
     * Class initialization required.
     *
     *  r3 holds class object
     */
.LOP_NEW_INSTANCE_needinit:
	mr	r19, r3				/* save r3 */
	bl	dvmInitClass@plt		/* initialize class */
	cmpwi	r3, 0				/* check boolean result */
	mr	r3, r19				/* restore r3 */
	bne+	.LOP_NEW_INSTANCE_initialized		/* success, continue */
	b	common_exceptionThrown		/* failed, deal with init exception */

/* continuation for OP_NEW_ARRAY */


    /*
     * Resolve class.  (This is an uncommon case.)
     *
     *  r4 holds array length
     *  r5 holds class ref CCCC
     */
.LOP_NEW_ARRAY_resolve:
	mr	r20, r4				/* r20<- length (save) */
	lwz	r6, offGlue_method(rGLUE)	/* r3<- glue->method */
	lwz     r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	mr	r4, r5				/* r4<- CCCC */
	li	r5, 0				/* r5<- false */
	bl	dvmResolveClass@plt		/* r3<- call(clazz, ref) */
	cmpwi	r3, 0				/* got null? */
	mr	r4, r20				/* r4<- length (restore) */
	bne+	.LOP_NEW_ARRAY_finish		/* OK */
	b	common_exceptionThrown		/* handle exception */

/* continuation for OP_FILLED_NEW_ARRAY */

	/*
	 * On entry:
	 *  r3 holds array class
	 *  r19 holds A << 2 (!range)
	 *  r20 holds B(!range) or length(range)
	 */
.LOP_FILLED_NEW_ARRAY_continue:
	lwz	r6, offClassObject_descriptor(r3)	/* r6<- arrayClass->descriptor */
	lbz	r21, 1(r6)			/* r6<- descriptor[1] */

	cmpwi	r21, 'I'				/* array of ints? */
	beq+	0f
	cmpwi	r21, 'L'				/* array of objects? */
	beq	0f
	cmpwi	r21, '['				/* array of arrays? */
	beq	0f
	b	.LOP_FILLED_NEW_ARRAY_notimpl		/* no, not handled yet */
0:	mr	r4, r20				/* r4<- r20 (length) */
	li	r5, ALLOC_DONT_TRACK		/* r5<- alloc flags */
	bl	dvmAllocArrayByClass@plt	/* r3<- call(arClass, length, flags) */
	cmpwi	r3, 0				/* null return? */
	beq-	common_exceptionThrown		/* alloc failed, handle exception */

	FETCH(r4, 2)				/* r4<- FEDC or CCCC */
	FETCH_ADVANCE_INST(3)			/* advance to next instr, load rINST */
	stw     r3, offGlue_retval(rGLUE)	/* retval.l <- new array */
	stw     r21, offGlue_retval+4(rGLUE)	/* retval.h <- type */
	addi	r3, r3, offArrayObject_contents	/* r3<- newArray->contents */

	/* r3=array, r4=FEDC, r19<- A << 2, r20 = B */
	/* r3=array, r4=CCCC, r20=AA */
	/* copy values from registers into the array */
	cmpwi	r20, 0				/* length was initially <= 0 */
	ble-	2f				/* yes, bail */
	.if	0
	mtctr	r20				/* ctr<- r20 */
	slwi	r6, r4, 2			/* r6<- r4 << 2 */
	add     r5, rFP, r6			/* r5<- &fp[CCCC] */
	addi	r3, r3, -4			/* point one back for pre-inc */
	addi	r5, r5, -4			/* point one back for pre-inc */
1:	lwzu	r6, 4(r5)			/* r6<- *++r5 */
	stwu	r6, 4(r3)			/* *++contents = vX */
	bdnz+	1b				/* loop while ctr > 0 */
	.else
	cmpwi	r20, 5				/* length was initially 5? */
	bne+	3f				/* <= 4 args, branch */
	li	r20, 4				/* r20<- dec = 4 */
	GET_VREG_S(r6, r19)			/* r6<- vA */
	stw	r6, 16(r3)			/* contents[4] = vA */
3:	mtctr	r20				/* loop counter */
	addi	r3, r3, -4			/* point one back for pre-inc */
1:	rlwinm  r5,r4,2,26,29			/* r5<- (F/E/D/C & 15) << 2 */
	srwi	r4, r4, 4			/* r4<- r4 >> 4 */
	GET_VREG_S(r6, r5)			/* r6<- vF/vE/vD/vC */
	stwu	r6, 4(r3)			/* *++contents = vX */
	bdnz+	1b				/* loop while ctr > 0 */
	.endif

2:
	lwz	r3, offGlue_retval(rGLUE)	/* r3<- object */
	lwz	r4, offGlue_retval+4(rGLUE)	/* r4<- type */
	lwz	r5, offGlue_cardTable(rGLUE)	/* r5<- card table base */
	rlwinm	r3, r3, 32-GC_CARD_SHIFT, GC_CARD_SHIFT, 31
	cmpwi	r4, 'I'				/* array of ints? */
	beq-	4f
	stbx	r5, r5, r3
4:

	GET_INST_OPCODE_GOTO(r0)		/* r0<- opcode from rINST */

	/*
	 * Throw an exception indicating that we have not implemented this
	 * mode of filled-new-array.
	 */
.LOP_FILLED_NEW_ARRAY_notimpl:
	lis	r3, .LstrInternalError@ha
	addi	r3, r3, .LstrInternalError@l
	lis	r4, .LstrFilledNewArrayNotImpl@ha
	addi	r4, r4, .LstrFilledNewArrayNotImpl@l
	bl      dvmThrowException@plt
	b       common_exceptionThrown

/* continuation for OP_FILLED_NEW_ARRAY_RANGE */

	/*
	 * On entry:
	 *  r3 holds array class
	 *  r19 holds A << 2 (!range)
	 *  r20 holds B(!range) or length(range)
	 */
.LOP_FILLED_NEW_ARRAY_RANGE_continue:
	lwz	r6, offClassObject_descriptor(r3)	/* r6<- arrayClass->descriptor */
	lbz	r21, 1(r6)			/* r6<- descriptor[1] */

	cmpwi	r21, 'I'				/* array of ints? */
	beq+	0f
	cmpwi	r21, 'L'				/* array of objects? */
	beq	0f
	cmpwi	r21, '['				/* array of arrays? */
	beq	0f
	b	.LOP_FILLED_NEW_ARRAY_RANGE_notimpl		/* no, not handled yet */
0:	mr	r4, r20				/* r4<- r20 (length) */
	li	r5, ALLOC_DONT_TRACK		/* r5<- alloc flags */
	bl	dvmAllocArrayByClass@plt	/* r3<- call(arClass, length, flags) */
	cmpwi	r3, 0				/* null return? */
	beq-	common_exceptionThrown		/* alloc failed, handle exception */

	FETCH(r4, 2)				/* r4<- FEDC or CCCC */
	FETCH_ADVANCE_INST(3)			/* advance to next instr, load rINST */
	stw     r3, offGlue_retval(rGLUE)	/* retval.l <- new array */
	stw     r21, offGlue_retval+4(rGLUE)	/* retval.h <- type */
	addi	r3, r3, offArrayObject_contents	/* r3<- newArray->contents */

	/* r3=array, r4=FEDC, r19<- A << 2, r20 = B */
	/* r3=array, r4=CCCC, r20=AA */
	/* copy values from registers into the array */
	cmpwi	r20, 0				/* length was initially <= 0 */
	ble-	2f				/* yes, bail */
	.if	1
	mtctr	r20				/* ctr<- r20 */
	slwi	r6, r4, 2			/* r6<- r4 << 2 */
	add     r5, rFP, r6			/* r5<- &fp[CCCC] */
	addi	r3, r3, -4			/* point one back for pre-inc */
	addi	r5, r5, -4			/* point one back for pre-inc */
1:	lwzu	r6, 4(r5)			/* r6<- *++r5 */
	stwu	r6, 4(r3)			/* *++contents = vX */
	bdnz+	1b				/* loop while ctr > 0 */
	.else
	cmpwi	r20, 5				/* length was initially 5? */
	bne+	3f				/* <= 4 args, branch */
	li	r20, 4				/* r20<- dec = 4 */
	GET_VREG_S(r6, r19)			/* r6<- vA */
	stw	r6, 16(r3)			/* contents[4] = vA */
3:	mtctr	r20				/* loop counter */
	addi	r3, r3, -4			/* point one back for pre-inc */
1:	rlwinm  r5,r4,2,26,29			/* r5<- (F/E/D/C & 15) << 2 */
	srwi	r4, r4, 4			/* r4<- r4 >> 4 */
	GET_VREG_S(r6, r5)			/* r6<- vF/vE/vD/vC */
	stwu	r6, 4(r3)			/* *++contents = vX */
	bdnz+	1b				/* loop while ctr > 0 */
	.endif

2:
	lwz	r3, offGlue_retval(rGLUE)	/* r3<- object */
	lwz	r4, offGlue_retval+4(rGLUE)	/* r4<- type */
	lwz	r5, offGlue_cardTable(rGLUE)	/* r5<- card table base */
	rlwinm	r3, r3, 32-GC_CARD_SHIFT, GC_CARD_SHIFT, 31
	cmpwi	r4, 'I'				/* array of ints? */
	beq-	4f
	stbx	r5, r5, r3
4:

	GET_INST_OPCODE_GOTO(r0)		/* r0<- opcode from rINST */

	/*
	 * Throw an exception indicating that we have not implemented this
	 * mode of filled-new-array.
	 */
.LOP_FILLED_NEW_ARRAY_RANGE_notimpl:
	lis	r3, .LstrInternalError@ha
	addi	r3, r3, .LstrInternalError@l
	lis	r4, .LstrFilledNewArrayNotImpl@ha
	addi	r4, r4, .LstrFilledNewArrayNotImpl@l
	bl      dvmThrowException@plt
	b       common_exceptionThrown

/* continuation for OP_CMPL_DOUBLE */

.LOP_CMPL_DOUBLE_split:

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	fcmpu	cr7, f1, f2			/* compare f1, f2 */
	li	r3, -1				/* set result if following comparison true */
	blt-	cr7, 0f				/* branch on f1 < f2 */
	li	r3, 1				/* set result if following comparison true */
	bgt-	cr7, 0f				/* branch on f1 > f2 */
	li	r3, 0				/* set result if following comparison true */
	beq-	cr7, 0f				/* branch on f1 == f2 */
	li	r3, -1				/* either f1 or f2 is a NaN */
0:
	SET_VREG_S(r3, r19)			/* vAA<- e3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* continuation for OP_CMPG_DOUBLE */

.LOP_CMPG_DOUBLE_split:

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	fcmpu	cr7, f1, f2			/* compare f1, f2 */
	li	r3, -1				/* set result if following comparison true */
	blt-	cr7, 0f				/* branch on f1 < f2 */
	li	r3, 1				/* set result if following comparison true */
	bgt-	cr7, 0f				/* branch on f1 > f2 */
	li	r3, 0				/* set result if following comparison true */
	beq-	cr7, 0f				/* branch on f1 == f2 */
	li		r3, 1				/* either f1 or f2 is a NaN */
0:
	SET_VREG_S(r3, r19)			/* vAA<- e3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* continuation for OP_APUT_OBJECT */

.LOP_APUT_OBJECT_finish:
	lwz	r4, offObject_clazz(r21)	/* r4<- arrayObj->clazz */
	lwz	r3, offObject_clazz(r19)	/* r3<- obj->clazz */
	bl	dvmCanPutArrayElement@plt	/* test object type vs. array type */
	cmpwi	r3, 0				/* okay? */
	beq-	common_errArrayStore		/* no */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	stw	r19, offArrayObject_contents(r20) /* vBB[vCC] <- r19*/
	lwz	r5, offGlue_cardTable(rGLUE)	/* r5<- card table base */
	rlwinm	r21, r21, 32-GC_CARD_SHIFT, GC_CARD_SHIFT, 31
	cmpwi	r19, 0				/* stored a null reference ? */
	beq- 1f
	stbx	r5, r5, r21			/* mark card if not zero */
1:

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */
.LOP_APUT_OBJECT_skip_check:
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	stw	r19, offArrayObject_contents(r20) /* r19<- vBB[vCC] */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* continuation for OP_INVOKE_SUPER */
.LOP_INVOKE_SUPER_nsm:
	lwz	r4, offMethod_name(r3)		/* r4<- method name */
	b	common_errNoSuchMethod

/* continuation for OP_INVOKE_SUPER_RANGE */
.LOP_INVOKE_SUPER_RANGE_nsm:
	lwz	r4, offMethod_name(r3)		/* r4<- method name */
	b	common_errNoSuchMethod

/* continuation for OP_FLOAT_TO_INT */

#ifndef KEEP_MAX_MIN_INT_IN_REGS
.LOP_FLOAT_TO_INT_table:
	.float	 2147483647	/* max-int */
	.float	-2147483648	/* min-int */
#endif

.LOP_FLOAT_TO_INT_store_zero:
	li	r3, 0				/* r3<- 0 */
	b	0f
.LOP_FLOAT_TO_INT_store_min_int:
	lis	r3, 0x8000			/* r3<- min-int */
	b	0f
.LOP_FLOAT_TO_INT_store_max_int:
	lis	r3, 0x7fff			/* r3<- max-int */
	ori	r3, r3, 0xffff
	/* fallthrough */
0:
	SET_VREG_S(r3, r7)			/* store to register */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* continuation for OP_FLOAT_TO_LONG */

#ifndef KEEP_MAX_MIN_LONG_IN_REGS
	.align	4
.LOP_FLOAT_TO_LONG_table:
	.float	9223372036854775807	/* max-long */
	.float -9223372036854775808	/* min-long */
#endif

.LOP_FLOAT_TO_LONG_store_zero:
	li	r3, 0				/* r3/r4<- 0 */
	li	r4, 0
	b	.LOP_FLOAT_TO_LONG_store_int
.LOP_FLOAT_TO_LONG_store_min_int:
	lis	r3, 0x8000			/* r3/r4<- min-long */
	li	r4, 0
	b	.LOP_FLOAT_TO_LONG_store_int
.LOP_FLOAT_TO_LONG_store_max_int:
	lis	r3, 0x7fff			/* r3/r4<- max-long */
	ori	r3, r3, 0xffff
	li	r4, -1
	/* fallthrough */
.LOP_FLOAT_TO_LONG_store_int:
	stwux	r3, r19, rFP			/* store to register (hi) */
	stw	r4, 4(r19)			/* lo */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* continuation for OP_DOUBLE_TO_INT */

#ifndef KEEP_MAX_MIN_INT_IN_REGS
	.align 8
.LOP_DOUBLE_TO_INT_table:
	.double	 2147483647	/* max-int */
	.double	-2147483648	/* min-int */
#endif

.LOP_DOUBLE_TO_INT_store_zero:
	li	r3, 0				/* r3<- 0 */
	b	0f
.LOP_DOUBLE_TO_INT_store_min_int:
	lis	r3, 0x8000			/* r3<- min-int */
	b	0f
.LOP_DOUBLE_TO_INT_store_max_int:
	lis	r3, 0x7fff			/* r3<- max-int */
	ori	r3, r3, 0xffff
	/* fallthrough */
0:
	SET_VREG_S(r3, r7)			/* store to register */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* continuation for OP_DOUBLE_TO_LONG */

#ifndef KEEP_MAX_MIN_LONG_IN_REGS
	.align	8
.LOP_DOUBLE_TO_LONG_table:
	.double	9223372036854775807	/* max-long */
	.double -9223372036854775808	/* min-long */
#endif

.LOP_DOUBLE_TO_LONG_store_zero:
	li	r3, 0				/* r3/r4<- 0 */
	li	r4, 0
	b	.LOP_DOUBLE_TO_LONG_store_int
.LOP_DOUBLE_TO_LONG_store_min_int:
	lis	r3, 0x8000			/* r3/r4<- min-long */
	li	r4, 0
	b	.LOP_DOUBLE_TO_LONG_store_int
.LOP_DOUBLE_TO_LONG_store_max_int:
	lis	r3, 0x7fff			/* r3/r4<- max-long */
	ori	r3, r3, 0xffff
	li	r4, -1
	/* fallthrough */
.LOP_DOUBLE_TO_LONG_store_int:
	stwux	r3, r19, rFP			/* store to register (hi) */
	stw	r4, 4(r19)			/* lo */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

/* continuation for OP_ADD_DOUBLE */

.LOP_ADD_DOUBLE_split:

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	fadd	f1, f1, f2					/* f3<- op, r3-r6 changed */
					/* optional op; more space */

	SET_VREG_D_S(f1, r19)			/* vAA/vAA+1<- f1 */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* continuation for OP_SUB_DOUBLE */

.LOP_SUB_DOUBLE_split:

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	fsub	f1, f1, f2					/* f3<- op, r3-r6 changed */
					/* optional op; more space */

	SET_VREG_D_S(f1, r19)			/* vAA/vAA+1<- f1 */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* continuation for OP_MUL_DOUBLE */

.LOP_MUL_DOUBLE_split:

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	fmul	f1, f1, f2					/* f3<- op, r3-r6 changed */
					/* optional op; more space */

	SET_VREG_D_S(f1, r19)			/* vAA/vAA+1<- f1 */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* continuation for OP_DIV_DOUBLE */

.LOP_DIV_DOUBLE_split:

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	fdiv	f1, f1, f2					/* f3<- op, r3-r6 changed */
					/* optional op; more space */

	SET_VREG_D_S(f1, r19)			/* vAA/vAA+1<- f1 */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* continuation for OP_REM_DOUBLE */

.LOP_REM_DOUBLE_split:

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
					/* optional op; may set condition codes */
	bl	fmod@plt					/* f3<- op, r3-r6 changed */
					/* optional op; more space */

	SET_VREG_D_S(f1, r19)			/* vAA/vAA+1<- f1 */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* continuation for OP_ADD_DOUBLE_2ADDR */

.LOP_ADD_DOUBLE_2ADDR_split:

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	fadd	f1, f1, f2					/* result<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_D_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* continuation for OP_SUB_DOUBLE_2ADDR */

.LOP_SUB_DOUBLE_2ADDR_split:

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	fsub	f1, f1, f2					/* result<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_D_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* continuation for OP_MUL_DOUBLE_2ADDR */

.LOP_MUL_DOUBLE_2ADDR_split:

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	fmul	f1, f1, f2					/* result<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_D_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* continuation for OP_DIV_DOUBLE_2ADDR */

.LOP_DIV_DOUBLE_2ADDR_split:

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	fdiv	f1, f1, f2					/* result<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_D_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* continuation for OP_REM_DOUBLE_2ADDR */

.LOP_REM_DOUBLE_2ADDR_split:

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

					/* optional op; may set condition codes */
	bl fmod@plt					/* result<- op, r3-r6 changed */
					/* optional op; more space */
	SET_VREG_D_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

/* continuation for OP_EXECUTE_INLINE */

.LOP_EXECUTE_INLINE_continue:
4:	rlwinm	r6, r20, 22, 26, 29		/* r6 = (FEDC & 0xf000) >> 10 */
	lwzx	r6, rFP, r6			/* r6<- vF (shift right 12, left 2) */
3:	rlwinm	r5, r20, 26, 26, 29		/* r6 = (FEDC & 0x0f00) >> 6) */
	lwzx	r5, rFP, r5			/* r6<- vE (shift right 8, left 2) */
2:	rlwinm	r4, r20, 30, 26, 29		/* r6 = (FEDC & 0x00f0) >> 2) */
	lwzx	r4, rFP, r4			/* r6<- vD (shift right 4, left 2) */
1:	rlwinm	r3, r20, 2, 26, 29		/* r6 = (FEDC & 0x000f) << 2) */
	lwzx	r3, rFP, r3			/* r6<- vC (shift right 0, left 2) */

	lis	r8, gDvmInlineOpsTable@ha	/* point to Inline OpsTable */
	addi	r8, r8, gDvmInlineOpsTable@l
	slwi	r9, r19, 4			/* convert * 16 */
	lwzx	r0, r8, r9			/* load func */
	addi	r7, rGLUE, offGlue_retval  	/* r7<- &glue->retval */
	mtctr	r0
	bctr					/* exec */

/* continuation for OP_EXECUTE_INLINE_RANGE */

.LOP_EXECUTE_INLINE_RANGE_continue:
4:	addi	r7, r20, 12			/* base + 3 << 2 */
	lwzx	r6, rFP, r7			/* r6<- vBase[3] */
3:	addi	r7, r20, 8			/* base + 2 << 2 */
	lwzx	r4, rFP, r7			/* r5<- vBase[2] */
2:	addi	r7, r20, 4			/* base + 1 << 2 */
	lwzx	r4, rFP, r7			/* r4<- vBase[1] */
1:	addi	r7, r20, 0			/* base + 0 << 2 */
	lwzx	r3, rFP, r7			/* r3<- vBase[0] */

	lis	r8, gDvmInlineOpsTable@ha	/* point to Inline OpsTable */
	addi	r8, r8, gDvmInlineOpsTable@l
	slwi	r9, r19, 4			/* convert * 16 */
	lwzx	r0, r8, r9			/* load func */
	addi	r7, rGLUE, offGlue_retval  	/* r7<- &glue->retval */
	mtctr	r0
	bctr					/* exec */

    .size   dvmAsmSisterStart, .-dvmAsmSisterStart
    .global dvmAsmSisterEnd
dvmAsmSisterEnd:

/* File: powerpc/footer.S */
/*
 * ===========================================================================
 *  Common subroutines and data
 * ===========================================================================
 */

	.text
	.align  2

/*
 * Common code when a backward branch is taken.
 *
 * On entry:
 *  r11 is PC adjustment *in bytes*
 */
common_backwardBranch:
	li	r3, kInterpEntryInstr
	bl	common_periodicChecks
	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */


/*
 * Need to see if the thread needs to be suspended or debugger/profiler
 * activity has begun.  If so, we suspend the thread or side-exit to
 * the debug interpreter as appropriate.
 *
 * The common case is no activity on any of these, so we want to figure
 * that out quickly.  If something is up, we can then sort out what.
 *
 * We want to be fast if the VM was built without debugger or profiler
 * support, but we also need to recognize that the system is usually
 * shipped with both of these enabled.
 *
 * TODO: reduce this so we're just checking a single location.
 *
 * On entry:
 *  r3 is reentry type, e.g. kInterpEntryInstr (for debugger/profiling)
 *  r11 is trampoline PC adjustment *in bytes*
 */
common_periodicChecks:
	lwz	r10, offGlue_pSelfSuspendCount(rGLUE)	/* r10<- &suspendCount */
	lwz	r9, offGlue_pDebuggerActive(rGLUE)	/* r9<- &debuggerActive */
	lwz	r8, offGlue_pActiveProfilers(rGLUE)	/* r8<- &activeProfilers */

	lwz	r7, 0(r10)				/* r7<- suspendCount (int) */
	cmpwi	r7, 0
	bne	3f

2:
	cmpwi	r9, 0					/* debugger enabled ? */
	beq	0f
	lbz	r9, 0(r9)				/* r9<- debuggerActive (boolean) */
	cmpwi	r9, 0
	bne	1f

0:	lwz     r8, 0(r8)				/* r8<- activeProfilers (int) */
	cmpwi	r8, 0
	bne	1f

	blr						/*  nothing to do, return */

	/*
	 * One or more interesting events have happened.  Figure out what.
	 *
	 * If debugging or profiling are compiled in, we need to disambiguate.
	 *
	 * r3 still holds the reentry type.
	 */
3:
	/* preserve r3, r11 and lr */
	mflr	r19
	mr	r20, r3
	mr	r21, r11
	lwz	r3, offGlue_self(rGLUE)			/* check suspend */
	EXPORT_PC()					/* needed for precise GC */
	bl	dvmCheckSuspendPending@plt		/* do full check, suspend if necessary */
	mr	r11, r21
	mr	r3, r20
	mtlr	r19

	/*
	 * Reload the debugger/profiler enable flags.  We're checking to see
	 * if either of these got set while we were suspended.
	 *
	 * We can't really avoid the #ifdefs here, because the fields don't
	 * exist when the feature is disabled.
	 */
	lwz	r9, offGlue_pDebuggerActive(rGLUE)	/* r9<- &debuggerActive */
	lwz	r8, offGlue_pActiveProfilers(rGLUE)	/* r8<- &activeProfilers */

	b 2b

1:	add	rPC, rPC, r11				/* debugger/profiler enabled, bail out */
	stw	r3, offGlue_entryPoint(rGLUE)		/* store r3, need for debug/prof */
	li      r4, 1                      		/* "want switch" = true */
	b       common_gotoBail				/* side exit */

/*
 * The equivalent of "goto bail", this calls through the "bail handler".
 *
 * State registers will be saved to the "glue" area before bailing.
 *
 * On entry:
 *  r4 is "bool changeInterp", indicating if we want to switch to the
 *     other interpreter or just bail all the way out
 */
common_gotoBail:
	SAVE_PC_FP_TO_GLUE()                		/* export state to "glue" */
	mr	r3, rGLUE
	b	dvmMterpStdBail@plt

/*
 * Common code for method invocation with range.
 *
 * On entry:
 *  r3 is "Method* methodToCall", the method we're trying to call
 */
common_invokeMethodRange:
.LinvokeNewRange:
	/* prepare to copy args to "outs" area of current frame */
	srwi.	r5, rINST, 8
	SAVEAREA_FROM_FP(r11, rFP)		/* r11<- stack save area */
	FETCH(r4, 2)				/* r4<- CCCC, (load here to hide latency) */
	lhz	r7, offMethod_registersSize(r3)		/* r7<- methodToCall->regsSize */
	lhz	r8, offMethod_outsSize(r3)		/* r8<- methodToCall->outsSize */
	beq	.LinvokeArgsDone                /* if no args, skip the rest */

	/* r3=methodToCall, r4=CCCC, r5=count, r11=outs */
	/* (very few methods have > 10 args; could unroll for common cases) */
	mtctr	r5				/* ctr<- r5 */
	slwi	r4, r4, 2			/* r4<- CCCC << 2 */
	slwi	r5, r5, 2			/* r5<- count * 2 */
	add	r6, rFP, r4			/* r6<- &fp[CCCC] */
	sub	r11, r11, r5			/* r11<- "outs" area, for call args */
	addi	r6, r6, -4			/* r6<- -- adjust for loop */
	addi	r11, r11, -4			/* r11<- -- adjust for loop */
1:	lwzu	r4, 4(r6)			/* val = *++fp */
	stwu	r4, 4(r11)			/* *++outs = val */
	bdnz+	1b				/* loop */
	b	.LinvokeArgsDone

/*
 * Common code for method invocation without range.
 *
 * On entry:
 *  r3 is "Method* methodToCall", the method we're trying to call
 */
common_invokeMethodNoRange:
.LinvokeNewNoRange:
	/* prepare to copy args to "outs" area of current frame */
	SAVEAREA_FROM_FP(r11, rFP)		/* r11<- stack save area */
	srwi.	r5, rINST, 12			/* r5<- B (arg count) -- test for zero */
	FETCH(r4, 2)				/* r4<- GFED, (load here to hide latency) */
	lhz	r7, offMethod_registersSize(r3)		/* r5<- methodToCall->regsSize */
	lhz	r8, offMethod_outsSize(r3)		/* r6<- methodToCall->outsSize */
	beq	.LinvokeArgsDone

	/* r3=methodToCall, r4=GFED, r5=count, r7=regSize, r8=outSize, r11=outs */
.LinvokeNonRange:
	subfic	r5, r5, 5			/* r5<- 5-r5 */
	lis	r6, 5f@ha			/* r6<- start of insn block */
	addi	r6, r6, 5f@l
	slwi	r5, r5, 4			/* 4 insn  */
	add	r9, r6, r5			/* r9 first insn of case */
	mtctr	r9				/* move r9 to ctr */
	bctr					/* perform computed goto */

5:	rlwinm	r6, rINST, 26, 26, 29		/* r6 = (rINST & 0x0f00) >> 6 */
	lwzx	r6, rFP, r6			/* r6<- vA (shift right 8, left 2) */
	nop
	stwu	r6, -4(r11)			/* *--outs = vA */

4:	rlwinm	r6,r4,22,26,29			/* r6 = (GFED & 0xf000) >> 10 */
	lwzx	r6, rFP, r6			/* r6<- vG (shift right 12, left 2) */
	nop
	stwu	r6, -4(r11)			/* *--outs = vG */

3:	rlwinm	r6, r4, 26, 26, 29		/* r6 = (GFED & 0x0f00) >> 6) */
	lwzx	r6, rFP, r6			/* r6<- vF (shift right 8, left 2) */
	nop
	stwu	r6, -4(r11)			/* *--outs = vF */

2:	rlwinm	r6, r4, 30, 26, 29		/* r6 = (GFED & 0x00f0) >> 2) */
	lwzx	r6, rFP, r6			/* r6<- vE (shift right 4, left 2) */
	nop
	stwu	r6, -4(r11)			/* *--outs = vE */

1:	rlwinm	r6, r4, 2, 26, 29		/* r6 = (GFED & 0x000f) << 2) */
	lwzx	r6, rFP, r6			/* r6<- vE (shift right 0, left 2) */
	nop
	stwu	r6, -4(r11)			/* *--outs = vD */

0:	/* fall through to .LinvokeArgsDone */

.LinvokeArgsDone:	/* r3=methodToCall, r7=regsSize, r8=outsSize  */
	lwz	rINST, offMethod_insns(r3)		/* rINST<- method->insns */
	lwz	r9, offMethod_clazz(r3)			/* r9 <- method->clazz */

	/* find space for the new stack frame, check for overflow */
	SAVEAREA_FROM_FP(r4, rFP)			/* r4<- stack save area */
	slwi	r5, r7, 2				/* r5 = regsSize << 2 */
	sub	r4, r4, r5				/* r4<- newFp (old savearea - regsSize) */
	SAVEAREA_FROM_FP(r11, r4)			/* r11<- newSaveArea */
	lwz	r5, offGlue_interpStackEnd(rGLUE)	/* r5<- interpStackEnd */
	slwi	r6, r8, 2				/* r6 = outsSize << 2 */
	sub	r6, r11, r6				/* r6<- bottom (newsave - outsSize) */

	cmplw	r6, r5					/* bottom < interpStackEnd? */
	lwz	r6, offMethod_accessFlags(r3)		/* r6<- methodToCall->accessFlags */
	blt-	.LstackOverflow				/* yes, this frame will overflow stack */

	/* set up newSaveArea */
#ifdef EASY_GDB
	SAVEAREA_FROM_FP(r10, rFP)			/* r10<- stack save area */
	stw	r10, offStackSaveArea_prevSave(r11)
#endif
	stw	rFP, offStackSaveArea_prevFrame(r11)
	stw	rPC, offStackSaveArea_savedPc(r11)
	stw	r3, offStackSaveArea_method(r11)

	andi.	r6, r6, ACC_NATIVE
	bne	.LinvokeNative

	lwz	r6, offClassObject_pDvmDex(r9)		/* r6<- method->clazz->pDvmDex */
	mr	rPC, rINST				/* publish new rPC */
	lwz	r5, offGlue_self(rGLUE)			/* r5<- glue->self */

	/* Update "glue" values for the new method */
	/* r3=methodToCall, r4=newFp, r5=self, r6=newMethodClass */
	stw	r3, offGlue_method(rGLUE)		/* glue->method = methodToCall */
	stw	r6, offGlue_methodClassDex(rGLUE)	/* glue->methodClassDex = ... */
	mr	rFP, r4					/* fp = newFp */
	stw	r4, offThread_curFrame(r5)		/* self->curFrame = newFp */
#ifdef KEEP_RES_FIELDS_IN_REGS
	lwz	rResStr, offGlue_methodClassDex(rGLUE)
	lwz	rResFld, offDvmDex_pResFields(rResStr)
	lwz	rResCls, offDvmDex_pResClasses(rResStr)
	lwz	rResStr, offDvmDex_pResStrings(rResStr)
#endif
	FETCH_INST()					/* load rINST from rPC */
	GET_INST_OPCODE_GOTO(r0)			/* extract opcode from rINST */

.LinvokeNative:
	/* Prep for the native call */
	/* r3=methodToCall, r4=newFp, r11=newSaveArea */
	lwz	r6, offGlue_self(rGLUE)			/* r6<- glue->self */
	lwz	r7, offThread_jniLocal_topCookie(r6)	/* r7<- thread->localRef->... */
	stw	r4, offThread_curFrame(r6)		/* self->curFrame = newFp */
	stw	r7, offStackSaveArea_localRefCookie(r11)	/* newFp->localRefCookie=top */
	mr	r19, r6					/* r19<- glue->self (preserve) */
	mr	r20, r11				/* r20<- newSaveArea (preserve) */

	mr	r5, r3					/* r5<- methodToCall */
	mr	r3, r4					/* r3<- newFp (points to args) */
	addi	r4, rGLUE, offGlue_retval		/* r4<- &retval */

#ifdef ASSIST_DEBUGGER
	/* insert fake function header to help gdb find the stack frame */
	b	.Lskip
	.type	dalvik_mterp, @function
dalvik_mterp:
.Lskip:
#endif
    	lwz	r0, offMethod_nativeFunc(r5)	/* r0<- methodToCall->nativeFunc */
	mtctr	r0				/* ctr<- r0 */
	bctrl					/* call */

	/* native return; r19=self, r20=newSaveArea */
	/* equivalent to dvmPopJniLocals */
	lwz	r3, offStackSaveArea_localRefCookie(r20)	/* r3<- saved top */
	lwz	r4, offThread_exception(r19)		/* check for exception */
	stw	rFP, offThread_curFrame(r19)		/* self->curFrame = fp */
	stw	r3, offThread_jniLocal_topCookie(r19)	/* self->localRef->... <- r3 */
	cmpwi	r4, 0					/* null? */
	bne-	common_exceptionThrown			/* no, handle exception */

	FETCH_ADVANCE_INST(3)				/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)			/* extract opcode from rINST */

.LstackOverflow:
	mr	r4, r3					/* r4<- methodToCall */
	lwz	r3, offGlue_self(rGLUE)			/* r3<- self */
	bl	dvmHandleStackOverflow@plt
	b	common_exceptionThrown
#ifdef ASSIST_DEBUGGER
	.size	dalvik_mterp,.-dalvik_mterp
#endif


/*
 * Common code for handling a return instruction.
 *
 * This does not return.
 */
common_returnFromMethod:
.LreturnNew:
	li	r3, kInterpEntryReturn
	li	r11, 0
	bl      common_periodicChecks

	SAVEAREA_FROM_FP(r3, rFP)			/* r3<- saveArea (old) */
	lwz	rFP, offStackSaveArea_prevFrame(r3)	/* fp = saveArea->prevFrame */
	lwz	r5, (offStackSaveArea_method - sizeofStackSaveArea)(rFP)
							/* r5<- method we're returning to */
	lwz	r6, offGlue_self(rGLUE)			/* r6<- glue->self */
	cmpwi	r5, 0					/* is this a break frame? */
	li	r4, 0					/* "want switch" = false */
	beq-	common_gotoBail				/* break frame, bail out completely */
	lwz	r4, offMethod_clazz(r5)			/* r4<- method->clazz */

	lwz	rPC, offStackSaveArea_savedPc(r3)	/* pc = saveArea->savedPc */
	stw	r5, offGlue_method(rGLUE)		/* glue->method = newSave->method */
	lwz	r4, offClassObject_pDvmDex(r4)		/* r4<- method->clazz->pDvmDex */
	stw	rFP, offThread_curFrame(r6)		/* self->curFrame = fp */
	stw	r4, offGlue_methodClassDex(rGLUE)
#ifdef KEEP_RES_FIELDS_IN_REGS
	lwz	rResStr, offGlue_methodClassDex(rGLUE)
	lwz	rResFld, offDvmDex_pResFields(rResStr)
	lwz	rResCls, offDvmDex_pResClasses(rResStr)
	lwz	rResStr, offDvmDex_pResStrings(rResStr)
#endif
	FETCH_ADVANCE_INST(3)				/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)			/* extract opcode from rINST */

/*
 * Somebody has thrown an exception.  Handle it.
 *
 * If the exception processing code returns to us (instead of falling
 * out of the interpreter), continue with whatever the next instruction
 * now happens to be.
 *
 * This does not return.
 */
common_exceptionThrown:
.LexceptionNew:
	li	r3, kInterpEntryThrow
	li	r11, 0
	bl	common_periodicChecks

	lwz	r20, offGlue_self(rGLUE)		/* r20<- glue->self */
	lwz	r19, offThread_exception(r20)		/* r19<- self->exception */
	mr	r4, r20					/* r4<- self */
	mr	r3, r19					/* r3<- exception */
	bl	dvmAddTrackedAlloc@plt			/* don't let the exception be GCed */
	li	r0, 0					/* r3<- NULL */
	stw	r0, offThread_exception(r20)		/* self->exception = NULL */

	mr	r3, r20					/* r3<- self */
	lwz	r4, offGlue_method(rGLUE)		/* r4<- glue->method */
	lwz	r4, offMethod_insns(r4)			/* r4<- method->insns */
	sub	r4, rPC, r4				/* r4<- pc - method->insns */
	srwi	r4, r4, 1				/* r4<- offset in code units (relPc) */
	mr	r5, r19					/* r5<- exception (exc) */
	li	r6, 0					/* r6<- false (scan?) */
	stwu	r1, -32(r1)				/* create space on stack */
	mflr	r0					/* save lr */
	stw	r0, 36(r1)				/* save it on stack frame */
	mr	r7, r1					/* r7<- stack */
	stwu	rFP, 8(r7)				/* saves rFP and updates r7 <- &fp */

	/* call, r3 gets catchRelPc (a code-unit offset) */
	bl	dvmFindCatchBlock@plt			/* call(self, relPc, exc, scan?, &fp) */

	/* fix earlier stack overflow if necessary; may trash rFP */
	lbz	r4, offThread_stackOverflowed(r20)
	cmpwi	r4, 0					/* did we overflow earlier? */
	beq+	1f					/* no skip ahead */
	mr	rFP, r3					/* save relPc result in rFP */
	mr	r3, r20					/* r3<- self */
	mr	r4, r19					/* r4<- exception */
	bl	dvmCleanupStackOverflow@plt		/* call(self) */
	mr	r3, rFP					/* restore result */

1:
	/* update frame pointer and check result from dvmFindCatchBlock */
	lwz	rFP, 8(r1)				/* retrieve updated rFP */
	lwz	r0, 36(r1)				/* load save lr */
	addi	r1, r1, 32				/* restore stack */
	mtlr	r0					/* restore lr */
	cmpwi	r3, 0					/* is catchRelPc < 0? */
	blt-	.LnotCaughtLocally			/* if < 0 */

	/* adjust locals to match self->curFrame and updated PC */
	SAVEAREA_FROM_FP(r4, rFP)			/* r4<- new save area */
	lwz	r4, offStackSaveArea_method(r4)		/* r4<- new method */
	stw	r4, offGlue_method(rGLUE)		/* glue->method = new method */
	lwz	r5, offMethod_clazz(r4)			/* r5<- method->clazz */
	lwz	r6, offMethod_insns(r4)			/* r6<- method->insns */
	lwz	r5, offClassObject_pDvmDex(r5)		/* r5<- method->clazz->pDvmDex */
	slwi	r7, r3, 1				/* r7<- r3 (cathRelPc) << 1 */
	add	rPC, r6, r7				/* rPC<- method->insns + catchRelPc */
	stw	r5, offGlue_methodClassDex(rGLUE)	/* glue->pDvmDex = meth... */
#ifdef KEEP_RES_FIELDS_IN_REGS
	lwz	rResStr, offGlue_methodClassDex(rGLUE)
	lwz	rResFld, offDvmDex_pResFields(rResStr)
	lwz	rResCls, offDvmDex_pResClasses(rResStr)
	lwz	rResStr, offDvmDex_pResStrings(rResStr)
#endif
	/* release the tracked alloc on the exception */
	mr	r3, r19					/* r3<- exception */
	mr	r4, r20					/* r4<- self */
	bl	dvmReleaseTrackedAlloc@plt		/* release the exception */

	/* restore the exception if the handler wants it */
	FETCH_INST()					/* load rINST from rPC */
	GET_INST_OPCODE(r10)				/* extract opcode from rINST */
	cmpwi	r10, OP_MOVE_EXCEPTION			/* is it "move-exception"? */
	bne-	1f					/* not? continue */ 
	stw	r19, offThread_exception(r20)		/* yes, restore the exception */
1:	GOTO_OPCODE(r10)				/* jump to next instruction */

.LnotCaughtLocally:	/* r19=exception, r20=self */
	/* fix stack overflow if necessary */
	lbz	r4, offThread_stackOverflowed(r20)
	cmpwi	r4, 0					/* did we overflow earlier? */
	beq-	1f					/* yes? */
	mr	r3, r20					/* r3<- self */
	mr	r4, r19					/* r4<- exception */
	bl	dvmCleanupStackOverflow@plt		/* call(self) */
1:
	/* may want to show "not caught locally" debug messages here */
#if DVM_SHOW_EXCEPTION >= 2
	/* call __android_log_print(prio, tag, format, ...) */
	/* "Exception %s from %s:%d not caught locally" */
	/* dvmLineNumFromPC(method, pc - method->insns) */
	lwz	r3, offGlue_method(rGLUE)
	lwz	r4, offMethod_insns(r3)
	sub	r4, rPC, r4
	srwi	r4, r4, #1
	bl	dvmLineNumFromPC@plt
	mr	r21, r3					/* r21<- r3 */

	/* dvmGetMethodSourceFile(method) */
	lwz	r3, offGlue_method(rGLUE)
	bl	dvmGetMethodSourceFile@plt
	mr	r4, r3					/* r4<- r3 */
	mr	r3, r21					/* r3<- r21 */

	/* exception->clazz->descriptor */
	lwz	r5, offObject_clazz(r19)
	lwz	r5, offClassObject_descriptor(r5)

	bl	dvmShowExceptionHelperPPC@plt
#endif
	stw	r19, offThread_exception(r20)	/* restore exception */
	mr	r3, r19					/* r3<- exception */
	mr	r4, r20					/* r4<- self */
	bl	dvmReleaseTrackedAlloc@plt		/* release the exception */
	li	r4, 0					/* "want switch" = false */
	b	common_gotoBail				/* bail out */

/*
 * After returning from a "glued" function, pull out the updated
 * values and start executing at the next instruction.
 */
common_resumeAfterGlueCall:
	LOAD_PC_FP_FROM_GLUE()			/* pull rPC and rFP out of glue */
#ifdef KEEP_RES_FIELDS_IN_REGS
	lwz	rResStr, offGlue_methodClassDex(rGLUE)
	lwz	rResFld, offDvmDex_pResFields(rResStr)
	lwz	rResCls, offDvmDex_pResClasses(rResStr)
	lwz	rResStr, offDvmDex_pResStrings(rResStr)
#endif
	FETCH_INST()				/* load rINST from rPC */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

/*
 * Invalid array index.
 */
common_errArrayIndex:
	EXPORT_PC()
	lis	r3, .LstrArrayIndexException@ha
	addi	r3, r3, .LstrArrayIndexException@l
	li	r4, 0
	bl	dvmThrowException@plt
	b	common_exceptionThrown

/*
 * Invalid array value.
 */
common_errArrayStore:
	EXPORT_PC()
	lis	r3, .LstrArrayStoreException@ha
	addi	r3, r3, .LstrArrayStoreException@l
	li	r4, 0
	bl	dvmThrowException@plt
	b	common_exceptionThrown

/*
 * Integer divide or mod by zero.
 */
common_errDivideByZero:
	EXPORT_PC()
	lis	r3, .LstrArithmeticException@ha
	addi	r3, r3, .LstrArithmeticException@l
	lis	r4, .LstrDivideByZero@ha
	addi	r4, r4, .LstrDivideByZero@l
	bl	dvmThrowException@plt
	b	common_exceptionThrown

/*
 * Attempt to allocate an array with a negative size.
 */
common_errNegativeArraySize:
	EXPORT_PC()
	lis	r3, .LstrNegativeArraySizeException@ha
	addi	r3, r3, .LstrNegativeArraySizeException@l
	li	r4, 0
	bl      dvmThrowException@plt
	b       common_exceptionThrown

/*
 * Invocation of a non-existent method.
 */
common_errNoSuchMethod:
	EXPORT_PC()
	lis	r3, .LstrNoSuchMethodError@ha
	addi	r3, r3, .LstrNoSuchMethodError@l
	li	r4, 0
	bl	dvmThrowException@plt
	b	common_exceptionThrown

/*
 * We encountered a null object when we weren't expecting one.  We
 * export the PC, throw a NullPointerException, and goto the exception
 * processing code.
 */
common_errNullObject:
	EXPORT_PC()
	lis	r3, .LstrNullPointerException@ha
	addi	r3, r3, .LstrNullPointerException@l
	li	r4, 0
	bl	dvmThrowException@plt
	b	common_exceptionThrown

/*
 * For debugging, cause an immediate fault.  The source address will
 * be in lr (use a bl instruction to jump here).
 */
common_abort:
	lis	r0, 0xdeadf00d@ha
	addi	r0, r0, 0xdeadf00d@l
	mtctr	r0
	bctr

/*
 * Zero-terminated ASCII string data.
 *
 */
    .section .rodata.str1.4,"aMS",%progbits,1

.LstrBadEntryPoint:
    .asciz  "Bad entry point %d\n"
.LstrArithmeticException:
    .asciz  "Ljava/lang/ArithmeticException;"
.LstrArrayIndexException:
    .asciz  "Ljava/lang/ArrayIndexOutOfBoundsException;"
.LstrArrayStoreException:
    .asciz  "Ljava/lang/ArrayStoreException;"
.LstrClassCastException:
    .asciz  "Ljava/lang/ClassCastException;"
.LstrDivideByZero:
    .asciz  "divide by zero"
.LstrFilledNewArrayNotImpl:
    .asciz  "filled-new-array only implemented for objects and 'int'"
.LstrInternalError:
    .asciz  "Ljava/lang/InternalError;"
.LstrInstantiationError:
    .asciz  "Ljava/lang/InstantiationError;"
.LstrNegativeArraySizeException:
    .asciz  "Ljava/lang/NegativeArraySizeException;"
.LstrNoSuchMethodError:
    .asciz  "Ljava/lang/NoSuchMethodError;"
.LstrNullPointerException:
    .asciz  "Ljava/lang/NullPointerException;"


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
	slwi	r0, _reg, ${handler_size_bits}; \
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
	rlwinm	_reg, rINST, ${handler_size_bits}, \
		31 - ${handler_size_bits} - 8 + 1, 31 - ${handler_size_bits}; \
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
	add	r20, rFP, _vreg_s; \
	andi.	r0, r20, 4; \
	bne	256f; \
	lfdx	_reg, rFP, _vreg_s; \
	b	255f; \
256:; \
	lwz	r21, 0(r20); \
	lwz	r22, 4(r20); \
	stw	r21, 8(r1); \
	stw	r22, 12(r1); \
	lfd	_reg, 8(r1); \
255: ;

#define SET_VREG_D_S(_reg, _vreg_s) \
	add	r20, rFP, _vreg_s; \
	andi.	r0, r20, 4; \
	bne	256f; \
	stfdx	_reg, rFP, _vreg_s; \
	b	255f; \
256:; \
	stfd	_reg, 8(r1); \
	lwz	r21, 8(r1); \
	lwz	r22, 12(r1); \
	stw	r21, 0(r20); \
	stw	r22, 4(r20); \
255: ;

/*
 * This is a #include, not a %include, because we want the C pre-processor
 * to expand the macros into assembler assignment statements.
 */
#include "../common/asm-constants.h"


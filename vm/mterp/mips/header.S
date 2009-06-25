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
 * MIPS definitions and declarations.
 */

/*
Mterp and MIPS O32 notes:

The following registers have fixed assignments.  They all need to be
saved across function calls.

  reg nick      purpose
  s0  rPC       interpreted program counter, used for fetching instructions
  s1  rFP       interpreted frame pointer, used for accessing locals and args
  s2  rGLUE     MterpGlue pointer
  s3  rIBASE    interpreted instruction base pointer, used for computed goto
  s7  rINST     first 16-bit code unit of current instruction
  s8  gp shadow

Macros are provided for common operations.  Each macro MUST emit only
one instruction to make instruction-counting easier.  They MUST NOT alter
unspecified registers or condition codes.
*/
#include <machine/asm.h>
#include <sys/regdef.h>

/* single-purpose registers, given names for clarity.
 * Sometimes, a C helper function is called, and many need to
 * be saved across that call.
 */
#define rPC     s0
#define rFP     s1
#define rGLUE   s2
#define rIBASE  s3
#define rINST   s7

/* save/restore the PC and/or FP from the glue struct */
#define LOAD_PC_FROM_GLUE()     lw     rPC, offGlue_pc(rGLUE)
#define SAVE_PC_TO_GLUE()       sw     rPC, offGlue_pc(rGLUE)
#define LOAD_FP_FROM_GLUE()     lw     rFP, offGlue_fp(rGLUE)
#define SAVE_FP_TO_GLUE()       sw     rFP, offGlue_fp(rGLUE)
#define LOAD_PC_FP_FROM_GLUE()  LOAD_PC_FROM_GLUE(); \
				LOAD_FP_FROM_GLUE()
#define SAVE_PC_FP_TO_GLUE()    SAVE_PC_TO_GLUE(); \
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
    sw     rPC, (-sizeofStackSaveArea + offStackSaveArea_currentPc)(rFP)

/*
 * Given a frame pointer, find the stack save area.
 *
 * In C this is "((StackSaveArea*)(_fp) -1)".
 */
#define SAVEAREA_FROM_FP(_reg, _fpreg) \
    subu     _reg, _fpreg, sizeofStackSaveArea

/*
 * Fetch the next instruction from rPC into rINST.  Does not advance rPC.
 */
#define FETCH_INST()            lhu    rINST, 0(rPC)

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
#define FETCH_ADVANCE_INST(_count) lhu    rINST, _count*2(rPC); \
				   addiu  rPC, rPC, _count*2

/*
 * Fetch the next instruction from an offset specified by _reg.  Updates
 * rPC to point to the next instruction.  "_reg" must specify the distance
 * in bytes, *not* 16-bit code units, and may be a signed value.
 */
#define FETCH_ADVANCE_INST_RB(_reg) 	add	AT, rPC, _reg; \
					lhu	rINST, 0(AT); \
					add	rPC, rPC, _reg

/*
 * Fetch a half-word code unit from an offset past the current PC.  The
 * "_count" value is in 16-bit code units.  Does not advance rPC.
 *
 * The "_S" variant works the same but treats the value as signed.
 */
#define FETCH(_reg, _count)     lhu    _reg, _count*2(rPC)
#define FETCH_S(_reg, _count)   lh     _reg, _count*2(rPC)

/*
 * Fetch one byte from an offset past the current PC.  Pass in the same
 * "_count" as you would for FETCH, and an additional 0/1 indicating which
 * byte of the halfword you want (lo/hi).
 */
#define FETCH_B(_reg, _count, _byte) lbu     _reg, _count*2+_byte(rPC)

/*
 * Put the instruction's opcode field into the specified register.
 */
#define GET_INST_OPCODE(_reg)   and     _reg, rINST, 255

/*
 * Begin executing the opcode in _reg.  Would be nice to take advantage
 * of that delay slot....
 */
#define GOTO_OPCODE(_reg)       sll	AT, _reg, ${handler_size_bits}; \
				addu	t9, AT, rIBASE; \
				jr	t9; \
				nop

/* When we can take advantage of the delay slot.
*/
#define GOTO_OPCODE_SLOT(_reg)  sll	AT, _reg, ${handler_size_bits}; \
				addu	t9, AT, rIBASE; \
				jr	t9

/*
 * Get/set the 32-bit value from a Dalvik register.
 */
#define GET_VREG(_reg, _vreg)   sll	AT, _vreg, 2; \
				addu	AT, AT, rFP; \
				lw	_reg, 0(AT)
#define SET_VREG(_reg, _vreg)   sll	AT, _vreg, 2; \
				addu	AT, AT, rFP; \
				sw	_reg, 0(AT)

/* We use s8 as the local copy of the gp register so it doesn't
 * have to be reloaded across function calls.  This macro is like
 * the "la" instruction, except uses s8 directly.
 */
#define LA(_reg, __lab)		lw	_reg, %call16(__lab)(s8)

/*
 * This is a #include, not a %include, because we want the C pre-processor
 * to expand the macros into assembler assignment statements.
 */
#include "../common/asm-constants.h"


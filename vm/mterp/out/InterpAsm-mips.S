/*
 * This file was generated automatically by gen-mterp.py for 'mips'.
 *
 * --> DO NOT EDIT <--
 */

/* File: mips/header.S */
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
#define GOTO_OPCODE(_reg)       sll	AT, _reg, 7; \
				addu	t9, AT, rIBASE; \
				jr	t9; \
				nop

/* When we can take advantage of the delay slot.
*/
#define GOTO_OPCODE_SLOT(_reg)  sll	AT, _reg, 7; \
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


/* File: mips/entry.S */
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




    .global dvmAsmInstructionStart
dvmAsmInstructionStart = .L_OP_NOP
    .text

/* ------------------------------ */
    .balign 128
.L_OP_NOP: /* 0x00 */
/* File: mips/OP_NOP.S */
    FETCH_ADVANCE_INST(1)               /* advance to next instr, load rINST */
    GET_INST_OPCODE(t7)                 /* ip<- opcode from rINST */
    GOTO_OPCODE(t7)                     /* execute it */


/* ------------------------------ */
    .balign 128
.L_OP_MOVE: /* 0x01 */
/* File: mips/OP_MOVE.S */
    /* for move, move-object, long-to-int */
    /* op vA, vB */
    srl     a1, rINST, 12               /* a1<- B from 15:12 */
    srl     a0, rINST, 8                /* a0<- A from 11:8 */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    GET_VREG(a2, a1)                    /* a2<- fp[B] */
    andi    a0, a0, 15
    GET_INST_OPCODE(t7)                 /* t7<- opcode from rINST */
    SET_VREG(a2, a0)                    /* fp[A]<- a2 */
    GOTO_OPCODE(t7)                     /* execute next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_MOVE_FROM16: /* 0x02 */
/* File: mips/OP_MOVE_FROM16.S */
    /* for: move/from16, move-object/from16 */
    /* op vAA, vBBBB */
    FETCH(a1, 1)                        /* a1<- BBBB */
    srl     a0, rINST, 8                /* a0<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_VREG(a2, a1)                    /* a2<- fp[BBBB] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a2, a0)                    /* fp[AA]<- a2 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_MOVE_16: /* 0x03 */
/* File: mips/OP_MOVE_16.S */
    /* for: move/16, move-object/16 */
    /* op vAAAA, vBBBB */
    FETCH(a1, 2)                        /* a1<- BBBB */
    FETCH(a0, 1)                        /* a0<- AAAA */
    FETCH_ADVANCE_INST(3)               /* advance rPC, load rINST */
    GET_VREG(a2, a1)                    /* a2<- fp[BBBB] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a2, a0)                    /* fp[AAAA]<- a2 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_MOVE_WIDE: /* 0x04 */
/* File: mips/OP_MOVE_WIDE.S */
    /* move-wide vA, vB */
    srl     a2, rINST, 6                /* a2<- A(+) */
    srl     a3, rINST, 10               /* a3<- B */
    andi    a2, a2, 0x3c
    andi    a3, a3, 0x3c
    addu    a2, rFP, a2                 /* a2<- &fp[A] */
    addu    a3, rFP, a3                 /* a3<- &fp[B] */
    lw      t4, 0(a3)                   /* t4/t5<- fp[B] */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    lw      t5, 4(a3)
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      t4, 0(a2)                   /* fp[A]<- t4/t5 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      t5, 4(a2)


/* ------------------------------ */
    .balign 128
.L_OP_MOVE_WIDE_FROM16: /* 0x05 */
/* File: mips/OP_MOVE_WIDE_FROM16.S */
    /* move-wide/from16 vAA, vBBBB */
    FETCH(a3, 1)                        /* r3<- BBBB */
    srl     a2, rINST, 6                /* a2<- AA */
    andi    a2, a2, 0x3c
    sll     a3, a3, 2
    addu    a2, rFP, a2                 /* a2<- &fp[AA] */
    addu    a3, rFP, a3                 /* r3<- &fp[BBBB] */
    lw      t4, 0(a3)                   /* t4/t5<- fp[BBBB] */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    lw      t5, 4(a3)
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      t4, 0(a2)                   /* fp[AA]<- t4/t5 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      t5, 4(a2)


/* ------------------------------ */
    .balign 128
.L_OP_MOVE_WIDE_16: /* 0x06 */
/* File: mips/OP_MOVE_WIDE_16.S */
    /* move-wide/16 vAAAA, vBBBB */
    FETCH(a3, 2)                        /* r3<- BBBB */
    FETCH(a2, 1)                        /* r2<- AAAA */
    sll     a3, a3, 2
    sll     a2, a2, 2
    addu    a3, rFP, a3                 /* r3<- &fp[BBBB] */
    addu    a2, rFP, a2                 /* r2<- &fp[AAAA] */
    lw      t4, 0(a3)                   /* t4/t5<- fp[BBBB] */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    lw      t5, 4(a3)
    sw      t4, 0(a2)                   /* fp[AAAA]<- t4/t5 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      t5, 4(a2)
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_MOVE_OBJECT: /* 0x07 */
/* File: mips/OP_MOVE_OBJECT.S */
/* File: mips/OP_MOVE.S */
    /* for move, move-object, long-to-int */
    /* op vA, vB */
    srl     a1, rINST, 12               /* a1<- B from 15:12 */
    srl     a0, rINST, 8                /* a0<- A from 11:8 */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    GET_VREG(a2, a1)                    /* a2<- fp[B] */
    andi    a0, a0, 15
    GET_INST_OPCODE(t7)                 /* t7<- opcode from rINST */
    SET_VREG(a2, a0)                    /* fp[A]<- a2 */
    GOTO_OPCODE(t7)                     /* execute next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_MOVE_OBJECT_FROM16: /* 0x08 */
/* File: mips/OP_MOVE_OBJECT_FROM16.S */
/* File: mips/OP_MOVE_FROM16.S */
    /* for: move/from16, move-object/from16 */
    /* op vAA, vBBBB */
    FETCH(a1, 1)                        /* a1<- BBBB */
    srl     a0, rINST, 8                /* a0<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_VREG(a2, a1)                    /* a2<- fp[BBBB] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a2, a0)                    /* fp[AA]<- a2 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_MOVE_OBJECT_16: /* 0x09 */
/* File: mips/OP_MOVE_OBJECT_16.S */
/* File: mips/OP_MOVE_16.S */
    /* for: move/16, move-object/16 */
    /* op vAAAA, vBBBB */
    FETCH(a1, 2)                        /* a1<- BBBB */
    FETCH(a0, 1)                        /* a0<- AAAA */
    FETCH_ADVANCE_INST(3)               /* advance rPC, load rINST */
    GET_VREG(a2, a1)                    /* a2<- fp[BBBB] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a2, a0)                    /* fp[AAAA]<- a2 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_MOVE_RESULT: /* 0x0a */
/* File: mips/OP_MOVE_RESULT.S */
    /* for: move-result, move-result-object */
    /* op vAA */
    srl     a2, rINST, 8                /* r2<- AA */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    lw      a0, offGlue_retval(rGLUE)   /* a0<- glue->retval.i */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a0, a2)                    /* fp[AA]<- a0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_MOVE_RESULT_WIDE: /* 0x0b */
/* File: mips/OP_MOVE_RESULT_WIDE.S */
    /* move-result-wide vAA */
    srl     a2, rINST, 8                /* a2<- AA */
    addiu   a3, rGLUE, offGlue_retval   /* a3<- &glue->retval */
    sll     a2, a2, 2
    addu    a2, rFP, a2                 /* a2<- &fp[AA] */
    lw      t4, 0(a3)                   /* a0/a1<- retval.j */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    lw      t5, 4(a3)
    sw      t4, 0(a2)                   /* fp[AA]<- a0/a1 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      t5, 4(a2)
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_MOVE_RESULT_OBJECT: /* 0x0c */
/* File: mips/OP_MOVE_RESULT_OBJECT.S */
/* File: mips/OP_MOVE_RESULT.S */
    /* for: move-result, move-result-object */
    /* op vAA */
    srl     a2, rINST, 8                /* r2<- AA */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    lw      a0, offGlue_retval(rGLUE)   /* a0<- glue->retval.i */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a0, a2)                    /* fp[AA]<- a0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_MOVE_EXCEPTION: /* 0x0d */
/* File: mips/OP_MOVE_EXCEPTION.S */
    /* move-exception vAA */
    lw      a0, offGlue_self(rGLUE)     /* a0<- glue->self */
    srl     a2, rINST, 8                /* a2<- AA */
    lw      a3, offThread_exception(a0) /* a3<- dvmGetException bypass */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    SET_VREG(a3, a2)                    /* fp[AA]<- exception obj */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      zero, offThread_exception(a0)  /* dvmClearException bypass */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_RETURN_VOID: /* 0x0e */
/* File: mips/OP_RETURN_VOID.S */
    b       common_returnFromMethod
    nop


/* ------------------------------ */
    .balign 128
.L_OP_RETURN: /* 0x0f */
/* File: mips/OP_RETURN.S */
    /*
     * Return a 32-bit value.  Copies the return value into the "glue"
     * structure, then jumps to the return handler.
     *
     * for: return, return-object
     */
    /* op vAA */
    srl     a2, rINST, 8                /* r2<- AA */
    GET_VREG(a0, a2)                    /* a0<- vAA */
    b       common_returnFromMethod
    sw      a0, offGlue_retval(rGLUE)   /* retval.i <- vAA */


/* ------------------------------ */
    .balign 128
.L_OP_RETURN_WIDE: /* 0x10 */
/* File: mips/OP_RETURN_WIDE.S */
    /*
     * Return a 64-bit value.  Copies the return value into the "glue"
     * structure, then jumps to the return handler.
     */
    /* return-wide vAA */
    srl     a2, rINST, 6               /* a2<- AA */
    andi    a2, a2, 0x3c
    add     a2, rFP, a2                /* a2<- &fp[AA] */
    add     a3, rGLUE, offGlue_retval  /* a3<- &glue->retval */
    lw      a0, 0(a2)                  /* a0/a1 <- vAA/vAA+1 */
    lw      a1, 4(a2)
    sw      a0, 0(a3)                  /* retval<- a0/a1 */
    b       common_returnFromMethod
    sw      a1, 4(a3)


/* ------------------------------ */
    .balign 128
.L_OP_RETURN_OBJECT: /* 0x11 */
/* File: mips/OP_RETURN_OBJECT.S */
/* File: mips/OP_RETURN.S */
    /*
     * Return a 32-bit value.  Copies the return value into the "glue"
     * structure, then jumps to the return handler.
     *
     * for: return, return-object
     */
    /* op vAA */
    srl     a2, rINST, 8                /* r2<- AA */
    GET_VREG(a0, a2)                    /* a0<- vAA */
    b       common_returnFromMethod
    sw      a0, offGlue_retval(rGLUE)   /* retval.i <- vAA */



/* ------------------------------ */
    .balign 128
.L_OP_CONST_4: /* 0x12 */
/* File: mips/OP_CONST_4.S */
    /* const/4 vA, #+B */
    sll     a1, rINST, 16               /* a1<- Bxxx0000 shift to get sign */
    srl     a0, rINST, 8                /* a0<- A+ */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    sra     a1, a1, 28                  /* a1<- sssssssB (sign-extended) */
    andi    a0, a0, 15
    GET_INST_OPCODE(t7)                 /* ip<- opcode from rINST */
    SET_VREG(a1, a0)                    /* fp[A]<- a1 */
    GOTO_OPCODE(t7)                     /* execute next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_CONST_16: /* 0x13 */
/* File: mips/OP_CONST_16.S */
    /* const/16 vAA, #+BBBB */
    FETCH_S(a0, 1)                      /* a0<- ssssBBBB (sign-extended) */
    srl     a3, rINST, 8                /* a3<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(a0, a3)                    /* vAA<- a0 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_CONST: /* 0x14 */
/* File: mips/OP_CONST.S */
    /* const vAA, #+BBBBbbbb */
    /* I wanted to use LWL/LWR here to eliminate the shift and or, but
     * they don't even come close to correct on LE.  They could be used for BE.
     */
    srl     a3, rINST, 8                /* a3<- AA */
    FETCH(a1, 2)                        /* a1<- BBBB (high) */
    FETCH(a0, 1)                        /* a0<- bbbb (low) */
    sll     a1, a1, 16			/* a1<- BBBBxxxx */
    FETCH_ADVANCE_INST(3)               /* advance rPC, load rINST */
    or      a0, a0, a1                  /* a0<- BBBBbbbb */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a0, a3)                    /* vAA<- a0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_CONST_HIGH16: /* 0x15 */
/* File: mips/OP_CONST_HIGH16.S */
    /* const/high16 vAA, #+BBBB0000 */
    FETCH(a0, 1)                        /* a0<- 0000BBBB (zero-extended) */
    srl     a3, rINST, 8                /* a3<- AA */
    sll     a0, a0, 16                  /* a0<- BBBB0000 */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(a0, a3)                    /* vAA<- a0 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_CONST_WIDE_16: /* 0x16 */
/* File: mips/OP_CONST_WIDE_16.S */
    /* const-wide/16 vAA, #+BBBB */
    FETCH_S(a0, 1)                      /* a0<- ssssBBBB (sign-extended) */
    srl     a3, rINST, 8                /* a3<- AA */
    move    a1, a0
    sra     a1, a1, 31                  /* a1<- ssssssss */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    sll     a3, a3, 2
    addu    a3, rFP, a3                 /* a3<- &fp[AA] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      a0, 0(a3)                   /* vAA<- a0/a1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, 4(a3)


/* ------------------------------ */
    .balign 128
.L_OP_CONST_WIDE_32: /* 0x17 */
/* File: mips/OP_CONST_WIDE_32.S */
    /* const-wide/32 vAA, #+BBBBbbbb */
    FETCH(a0, 1)                        /* a0<- 0000bbbb (low) */
    srl     a3, rINST, 8                /* a3<- AA */
    FETCH_S(a2, 2)                      /* a2<- ssssBBBB (high) */
    FETCH_ADVANCE_INST(3)               /* advance rPC, load rINST */
    sll     t5, a2, 16
    or      a0, a0, t5                  /* a0<- BBBBbbbb */
    sll     a3, a3, 2
    addu    a3, rFP, a3                 /* a3<- &fp[AA] */
    sra     a1, a2, 16                  /* a1<- ssssssss */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      a0, 0(a3)                   /* vAA<- a0/a1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, 4(a3)


/* ------------------------------ */
    .balign 128
.L_OP_CONST_WIDE: /* 0x18 */
/* File: mips/OP_CONST_WIDE.S */
    /* const-wide vAA, #+HHHHhhhhBBBBbbbb */
    FETCH(a1, 2)                        /* a1<- BBBB (low middle) */
    FETCH(a0, 1)                        /* a0<- bbbb (low) */
    sll     a1, a1, 16
    FETCH(a3, 4)                        /* a3<- HHHH (high) */
    or      a0, a0, a1                  /* a0<- BBBBbbbb (low word) */
    FETCH(a2, 3)                        /* a2<- hhhh (high middle) */
    sll     a3, a3, 16
    srl     t6, rINST, 8                /* t6<- AA */
    or      a1, a2, a3                  /* a1<- HHHHhhhh (high word) */
    FETCH_ADVANCE_INST(5)               /* advance rPC, load rINST */
    sll     t6, t6, 2
    addu    t6, rFP, t6                 /* t6<- &fp[AA] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      a0, 0(t6)                   /* vAA<- a0/a1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, 4(t6)


/* ------------------------------ */
    .balign 128
.L_OP_CONST_WIDE_HIGH16: /* 0x19 */
/* File: mips/OP_CONST_WIDE_HIGH16.S */
    /* const-wide/high16 vAA, #+BBBB000000000000 */
    FETCH(a1, 1)                        /* a1<- 0000BBBB (zero-extended) */
    srl     a3, rINST, 8                /* a3<- AA */
    sll     a1, a1, 16                  /* a1<- BBBB0000 */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    sll     a3, a3, 2
    addu    a3, rFP, a3                 /* a3<- &fp[AA] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      zero, 0(a3)                 /* vAA<- a0/a1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, 4(a3)


/* ------------------------------ */
    .balign 128
.L_OP_CONST_STRING: /* 0x1a */
/* File: mips/OP_CONST_STRING.S */
    /* const/string vAA, String@BBBB */
    FETCH(a1, 1)                               /* a1<- BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)  /* a2<- glue->methodClassDex */
    srl     s4, rINST, 8                       /* s4<- AA */
    lw      a2, offDvmDex_pResStrings(a2)      /* a2<- dvmDex->pResStrings */
    sll     t6, a1, 2
    addu    a2, a2, t6
    lw      v0, 0(a2)                          /* v0<- pResStrings[BBBB] */
    bnez    v0, .LOP_CONST_STRING_resolved           /* Resolved? */
    nop

    EXPORT_PC()
    lw      a0, offGlue_method(rGLUE)   /* a0<- glue->method */
    LA(t9, dvmResolveString)            /* v0<- String reference */
    jalr    t9				/* v0 = call(a0, a1) */
    lw      a0, offMethod_clazz(a0)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if failed, handle exception */
    /* Use of delay slot here in next macro is OK. Hopefully, likely path */

.LOP_CONST_STRING_resolved:
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_CONST_STRING_JUMBO: /* 0x1b */
/* File: mips/OP_CONST_STRING_JUMBO.S */
    /* const/string vAA, String@BBBBBBBB */
    FETCH(a0, 1)                        /* a0<- bbbb (low) */
    FETCH(a1, 2)                        /* a1<- BBBB (high) */
    lw      a2, offGlue_methodClassDex(rGLUE)  /* r2<- glue->methodClassDex */
    srl     s4, rINST, 8                /* s4<- AA */
    lw      a2, offDvmDex_pResStrings(a2)   /* r2<- dvmDex->pResStrings */
    sll     a1, a1, 16
    or      a1, a0, a1                  /* a1<- BBBBbbbb */
    sll     t6, a1, 2
    addu    a2, a2, t6
    lw      v0, 0(a2)                   /* a0<- pResStrings[BBBBbbbb] */
    bnez    v0, .LOP_CONST_STRING_JUMBO_resolved
    nop

    EXPORT_PC()
    lw      a0, offGlue_method(rGLUE)   /* a0<- glue->method */
    LA(t9, dvmResolveString)
    jalr    t9				/* v0 = call(a0, a1) */
    lw      a0, offMethod_clazz(a0)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if failed, handle exception */
    /* Use of delay slot here in next macro is OK. Hopefully, likely path */

.LOP_CONST_STRING_JUMBO_resolved:
    FETCH_ADVANCE_INST(3)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_CONST_CLASS: /* 0x1c */
/* File: mips/OP_CONST_CLASS.S */
    /* const/class vAA, Class@BBBB */
    FETCH(a1, 1)                               /* a1<- BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)  /* a2<- glue->methodClassDex */
    srl     s4, rINST, 8                       /* s4<- AA */
    lw      a2, offDvmDex_pResClasses(a2)      /* a2<- dvmDex->pResClasses */
    sll     t6, a1, 2
    addu    a2, a2, t6
    lw      v0, 0(a2)                          /* v0<- pResClasses[BBBB] */
    bnez    v0, .LOP_CONST_CLASS_resolved           /* Resolved? */
    nop

    EXPORT_PC()
    lw      a0, offGlue_method(rGLUE)   /* a0<- glue->method */
    li      a2, 1                       /* a2<- true */
    LA(t9, dvmResolveClass)             /* v0<- Class reference */
    jalr    t9				/* v0 = call(a0, a1, a2) */
    lw      a0, offMethod_clazz(a0)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if failed, handle exception */
    /* Use of delay slot here in next macro is OK. Hopefully, likely path */

.LOP_CONST_CLASS_resolved:
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_MONITOR_ENTER: /* 0x1d */
    /* stub for OP_MONITOR_ENTER */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_MONITOR_ENTER  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_MONITOR_EXIT: /* 0x1e */
    /* stub for OP_MONITOR_EXIT */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_MONITOR_EXIT  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_CHECK_CAST: /* 0x1f */
/* File: mips/OP_CHECK_CAST.S */
    /*
     * Check to see if a cast from one class to another is allowed.
     */
    /* check-cast vAA, class@BBBB */
    srl     a3, rINST, 8                /* a3<- AA */
    FETCH(a2, 1)                        /* a2<- BBBB */
    GET_VREG(s4, a3)                    /* a9<- object */
    lw      a0, offGlue_methodClassDex(rGLUE)    /* a0<- pDvmDex */
    beqz    s4, .LOP_CHECK_CAST_okay            /* null obj, cast always succeeds */
    lw      a0, offDvmDex_pResClasses(a0)   /* a0<- pDvmDex->pResClasses */
    sll     t6, a2, 2
    addu    t6, t6, a0
    lw      a1, 0(t6)                   /* a1<- resolved class */
    beqz    a1,  .LOP_CHECK_CAST_resolve    /* not resolved, do it now */
    lw      a0, offObject_clazz(s4)     /* a0<- obj->clazz */

.LOP_CHECK_CAST_resolved:
                          /* same class (trivial success)? */
    bne     a0, a1, .LOP_CHECK_CAST_fullcheck       /* no, do full check */
    nop

.LOP_CHECK_CAST_okay:
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */

/* ------------------------------ */
    .balign 128
.L_OP_INSTANCE_OF: /* 0x20 */
/* File: mips/OP_INSTANCE_OF.S */
    /*
     * Check to see if an object reference is an instance of a class.
     *
     * Most common situation is a non-null object, being compared against
     * an already-resolved class.
     */
    /* instance-of vA, vB, class@CCCC */
    srl     a3, rINST, 12          /* a3<- B */
    srl     s4, rINST, 8           /* s4<- A+ */
    GET_VREG(v0, a3)               /* a0<- vB (object) */
    andi    s4, s4, 15             /* s4<- A */
    beqz    v0, .LOP_INSTANCE_OF_store  /* null obj, not an instance, store v0 */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- pDvmDex */

    FETCH(a3, 1)                             /* a3<- CCCC */
    lw      a2, offDvmDex_pResClasses(a2)    /* a2<- pDvmDex->pResClasses */
    sll     t6, a3, 2
    addu    t6, t6, a2
    lw      a1, 0(t6)                        /* a1<- resolved class */
    beqz    a1,  .LOP_INSTANCE_OF_resolve         /* not resolved, do it now */
    lw      a0, offObject_clazz(v0)          /* a0<- obj->clazz */

.LOP_INSTANCE_OF_resolved:       /* a0=obj->clazz, a1=resolved class */
                  /* same class (trivial success)? */
    beq     a0, a1, .LOP_INSTANCE_OF_store  /* yes */
    li      v0, 1

    LA(t9,dvmInstanceofNonTrivial)     /* v0<- boolean result */
    jalr    t9
    /* fall through to OP_INSTANCE_OF_store */
    nop

.LOP_INSTANCE_OF_store:
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(v0, s4)                    /* vA<- v0 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_ARRAY_LENGTH: /* 0x21 */
/* File: mips/OP_ARRAY_LENGTH.S */
    /*
     * Return the length of an array.
     */
    srl     a1, rINST, 12               /* a1<- B */
    srl     a2, rINST, 8                /* a2<- A+ */
    GET_VREG(a0, a1)                    /* a0<- vB (object ref) */
    andi    a2, a2, 15                  /* a2<- A */
    beqz    a0, common_errNullObject    /* if object is null, fail */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    lw      a3, offArrayObject_length(a0)    /* a3<- array length */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a3, a2)                    /* vB<- length */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_NEW_INSTANCE: /* 0x22 */
    /* stub for OP_NEW_INSTANCE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_NEW_INSTANCE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_NEW_ARRAY: /* 0x23 */
    /* stub for OP_NEW_ARRAY */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_NEW_ARRAY  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_FILLED_NEW_ARRAY: /* 0x24 */
    /* stub for OP_FILLED_NEW_ARRAY */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_FILLED_NEW_ARRAY  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_FILLED_NEW_ARRAY_RANGE: /* 0x25 */
    /* stub for OP_FILLED_NEW_ARRAY_RANGE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_FILLED_NEW_ARRAY_RANGE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_FILL_ARRAY_DATA: /* 0x26 */
/* File: mips/OP_FILL_ARRAY_DATA.S */
    /* fill-array-data vAA, +BBBBBBBB */
    FETCH(a0, 1)                        /* a0<- bbbb (lo) */
    FETCH(a1, 2)                        /* a1<- BBBB (hi) */
    srl     a3, rINST, 8                /* a3<- AA */
    sll     a1, a1, 16
    or      a1, a0, a1                  /* a1<- BBBBbbbb */
    GET_VREG(a0, a3)                    /* a0<- vAA (array object) */
    EXPORT_PC()
    sll     a1, a1, 1
    LA(t9, dvmInterpHandleFillArrayData)
    jalr    t9                      /* fill the array with predefined data */
    addu    a1, rPC, a1             /* a1<- PC + BBBBbbbb*2 (array data off.) */
    beqz     v0, common_exceptionThrown /* 0 means have exception */
    FETCH_ADVANCE_INST(3)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_THROW: /* 0x27 */
/* File: mips/OP_THROW.S */
    /*
     * Throw an exception object in the current thread.
     */
    /* throw vAA */
    srl     a2, rINST, 8                /* a2<- AA */
    GET_VREG(a1, a2)                    /* a1<- vAA (exception object) */
    lw      a0, offGlue_self(rGLUE)     /* a0<- glue->self */
    beqz    a1, common_errNullObject    /* yes, throw an NPE instead */
    nop

    /* bypass dvmSetException, just store it */
    b       common_exceptionThrown
    sw      a1, offThread_exception(a0)  /* thread->exception<- obj */


/* ------------------------------ */
    .balign 128
.L_OP_GOTO: /* 0x28 */
/* File: mips/OP_GOTO.S */
    /*
     * Unconditional branch, 8-bit offset.
     *
     * The branch distance is a signed code-unit offset, which we need to
     * double to get a byte offset.
     */
    /* goto +AA */
    sll     a0, rINST, 16              /* a0<- AAxx0000 */
    sra     s4, a0, 23                 /* s4<- ssssssAA. (sign-ext doubled) */
    bltz    s4, common_backwardBranch  /* backward branch, do periodic checks */
    nop
    FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_GOTO_16: /* 0x29 */
/* File: mips/OP_GOTO_16.S */
    /*
     * Unconditional branch, 16-bit offset.
     *
     * The branch distance is a signed code-unit offset, which we need to
     * double to get a byte offset.
     */
    /* goto/16 +AAAA */
    FETCH_S(a0, 1)                     /* a0<- ssssAAAA (sign-extended) */
    sll     s4, a0, 1                  /* s4<- byte offset, check sign */
    bltz    s4, common_backwardBranch  /* backward branch, do periodic checks */
    nop
    FETCH_ADVANCE_INST_RB(s4)           /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_GOTO_32: /* 0x2a */
/* File: mips/OP_GOTO_32.S */
    /*
     * Unconditional branch, 32-bit offset.
     *
     * The branch distance is a signed code-unit offset, which we need to
     * double to get a byte offset.
     *
     * Unlike most opcodes, this one is allowed to branch to itself, so
     * our "backward branch" test must be "<=0" instead of "<0".
     */
    /* goto/32 +AAAAAAAA */
    FETCH(a1, 2)                       /* a1<- AAAA (hi) */
    FETCH(a0, 1)                       /* a0<- aaaa (lo) */
    sll     a1, a1, 16
    or      a0, a0, a1                 /* a0<- AAAAaaaa, check sign */
    sll     s4, a0, 1                  /* s4<- byte offset */
    blez    s4,  common_backwardBranch /* backward branch, do periodic checks */
    FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_PACKED_SWITCH: /* 0x2b */
    /* stub for OP_PACKED_SWITCH */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_PACKED_SWITCH  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_SPARSE_SWITCH: /* 0x2c */
    /* stub for OP_SPARSE_SWITCH */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_SPARSE_SWITCH  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_CMPL_FLOAT: /* 0x2d */
/* File: mips/OP_CMPL_FLOAT.S */
    /*
     * Compare two floating-point values.  Puts 0, 1, or -1 into the
     * destination register based on the results of the comparison.
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
     * I think __eqsf2, gives me what I want, but isn't documented to do so.
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* r0<- CCBB */
    andi    t5, a0, 255                 /* t5<- BB */
    srl     t6, a0, 8                   /* t6<- CC */
    GET_VREG(s4, t5)                    /* s4<- vBB */
    GET_VREG(s5, t6)                    /* s5<- vCC */
    LA(t9, __eqsf2)
    move    a0, s4
    jalr    t9
    move    a1, s5
    beqz    v0, .LOP_CMPL_FLOAT_finish	/* Branch if equal */
    LA(t9, __ltsf2)
    move    a0, s4
    jalr    t9
    move    a1, s5
    bltz    v0, .LOP_CMPL_FLOAT_finish	/* Branch if less than */
    li      v0, -1
    LA(t9, __gtsf2)
    move    a0, s4
    jalr    t9
    move    a1, s5
    blez    v0, .LOP_CMPL_FLOAT_finish	/* Branch if NaN */
    li      v0, -1			/* NaN return */
    b       .LOP_CMPL_FLOAT_finish		/* Branch if greater */
    li      v0, 1			/* Greater than return */


/* ------------------------------ */
    .balign 128
.L_OP_CMPG_FLOAT: /* 0x2e */
/* File: mips/OP_CMPG_FLOAT.S */
    /*
     * Compare two floating-point values.  Puts 0, 1, or -1 into the
     * destination register based on the results of the comparison.
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
    FETCH_B(t5, 1, 0)                   /* t5<- BB */
    FETCH_B(t6, 1, 1)                   /* t6<- CC */
    GET_VREG(s4, t5)                    /* s4<- vBB */
    GET_VREG(s5, t6)                    /* s5<- vCC */
    LA(t9, __eqsf2)
    move    a0, s4
    jalr    t9
    move    a1, s5
    beqz    v0, .LOP_CMPG_FLOAT_finish	/* Branch if equal */
    LA(t9, __ltsf2)
    move    a0, s4
    jalr    t9
    move    a1, s5

    slt     t5, v0, 0
    li      v0, -1			/* Value is less-than */
    li      v1, 1			/* Value is greater-than or NaN */
    movz    v0, v1, t5

.LOP_CMPG_FLOAT_finish:
    srl     s4, rINST, 8                /* s4<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_CMPL_DOUBLE: /* 0x2f */
    /* stub for OP_CMPL_DOUBLE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_CMPL_DOUBLE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_CMPG_DOUBLE: /* 0x30 */
    /* stub for OP_CMPG_DOUBLE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_CMPG_DOUBLE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_CMP_LONG: /* 0x31 */
/* File: mips/OP_CMP_LONG.S */
    /*
     * Compare two 64-bit values.  Puts 0, 1, or -1 into the destination
     * register based on the results of the comparison.
     */
    /* cmp-long vAA, vBB, vCC */
    FETCH_B(a2, 1, 0)                   /* a2<- BB */
    srl     s4, rINST, 8                /* s4<- AA */
    FETCH_B(a3, 1, 1)                   /* a3<- CC */
    sll     a2, a2, 2
    addu    t5, a2, rFP                 /* t5<- &fp[BB] */
    sll     a3, a3, 2
    addu    t6, a3, rFP                 /* t6<- &fp[CC] */
    lw      a1, 4(t5)
    lw      a3, 4(t6)
    lw      a0, 0(t5)                   /* a0/a1<- vBB/vBB+1 */
    subu    t4, a1, a3                  /* compare (vBB+1, vCC+1) */
    lw      a2, 0(t6)                   /* a2/a3<- vCC/vCC+1 */
    bltz    t4, .LOP_CMP_LONG_finish      /* signed compare on high part */
    li      v0, -1			/* a1 < a3 */
    bgtz    t4, .LOP_CMP_LONG_finish
    li      v0, 1			/* a1 > a3 */

    /* High parts are equal, compare low parts */
    subu    t4, a0, a2                  /* t4<- a0 - a2 */
    bltz    t4, .LOP_CMP_LONG_finish      /* unsigned compare on low part */
    li      v0, -1			/* a0 < a2 */
    bgtz    t4, .LOP_CMP_LONG_finish
    li      v0, 1			/* a0 <>a2 */
    move    v0, zero			/* a0/a1 == a2/a3 */

.LOP_CMP_LONG_finish:
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_IF_EQ: /* 0x32 */
/* File: mips/OP_IF_EQ.S */
    /*
     * Generic two-operand compare-and-branch operation.  Provide a "revcmp"
     * fragment that specifies the *reverse* comparison to perform, e.g.
     * for "if-le" you would use "gt".
     *
     * For: if-eq, if-ne, if-lt, if-ge, if-gt, if-le
     */
    /* if-cmp vA, vB, +CCCC */
    srl     a0, rINST, 8               /* a0<- A+ */
    srl     a1, rINST, 12              /* a1<- B */
    andi    a0, a0, 15
    GET_VREG(a3, a1)                   /* a3<- vB */
    GET_VREG(a2, a0)                   /* a2<- vA */
    li      s4, 4                      /* s4<- BYTE branch dist for not-taken */
    bne     a2, a3, 1f                 /* if not equal, just continue */
    nop				       /* if equal, fall through and branch */
    FETCH_S(s4, 1)                     /* s4<- branch offset, in code units */
    sll     s4, s4, 1                  /* convert to bytes, check sign */
    bltz    s4, common_backwardBranch  /* yes, do periodic checks */
    nop
1:  FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_IF_NE: /* 0x33 */
/* File: mips/OP_IF_NE.S */
    /*
     * Generic two-operand compare-and-branch operation.  Provide a "revcmp"
     * fragment that specifies the *reverse* comparison to perform, e.g.
     * for "if-le" you would use "gt".
     *
     * For: if-eq, if-ne, if-lt, if-ge, if-gt, if-le
     */
    /* if-cmp vA, vB, +CCCC */
    srl     a0, rINST, 8               /* a0<- A+ */
    srl     a1, rINST, 12              /* a1<- B */
    andi    a0, a0, 15
    GET_VREG(a3, a1)                   /* a3<- vB */
    GET_VREG(a2, a0)                   /* a2<- vA */
    li      s4, 4                      /* s4<- BYTE branch dist for not-taken */
    beq     a2, a3, 1f                 /* if equal, just continue */
    nop				       /* if not, fall through and branch */
    FETCH_S(s4, 1)                     /* s4<- branch offset, in code units */
    sll     s4, s4, 1                  /* convert to bytes, check sign */
    bltz    s4, common_backwardBranch  /* yes, do periodic checks */
    nop
1:  FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_IF_LT: /* 0x34 */
/* File: mips/OP_IF_LT.S */
/* File: mips/bincmp.S */
    /*
     * Generic two-operand compare-and-branch operation.  Provide a "revcmp"
     * fragment that specifies the *reverse* comparison to perform, e.g.
     * for "if-le" you would use "gt".
     *
     * For: if-eq, if-ne, if-lt, if-ge, if-gt, if-le
     */
    /* if-cmp vA, vB, +CCCC */
    srl     a0, rINST, 8               /* a0<- A+ */
    srl     a1, rINST, 12              /* a1<- B */
    andi    a0, a0, 15
    GET_VREG(a3, a1)                   /* a3<- vB */
    GET_VREG(a2, a0)                   /* a2<- vA */
    li      s4, 4                      /* s4<- BYTE branch dist for not-taken */
    subu    t6, a2, a3                 /* compare (vA, vB) */
    bgez  t6, 1f                 /* branch to 1 if comparison failed */
    nop
    FETCH_S(s4, 1)                     /* s4<- branch offset, in code units */
    sll     s4, s4, 1                  /* convert to bytes, check sign */
    bltz    s4, common_backwardBranch  /* yes, do periodic checks */
    nop
1:  FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_IF_GE: /* 0x35 */
/* File: mips/OP_IF_GE.S */
/* File: mips/bincmp.S */
    /*
     * Generic two-operand compare-and-branch operation.  Provide a "revcmp"
     * fragment that specifies the *reverse* comparison to perform, e.g.
     * for "if-le" you would use "gt".
     *
     * For: if-eq, if-ne, if-lt, if-ge, if-gt, if-le
     */
    /* if-cmp vA, vB, +CCCC */
    srl     a0, rINST, 8               /* a0<- A+ */
    srl     a1, rINST, 12              /* a1<- B */
    andi    a0, a0, 15
    GET_VREG(a3, a1)                   /* a3<- vB */
    GET_VREG(a2, a0)                   /* a2<- vA */
    li      s4, 4                      /* s4<- BYTE branch dist for not-taken */
    subu    t6, a2, a3                 /* compare (vA, vB) */
    bltz  t6, 1f                 /* branch to 1 if comparison failed */
    nop
    FETCH_S(s4, 1)                     /* s4<- branch offset, in code units */
    sll     s4, s4, 1                  /* convert to bytes, check sign */
    bltz    s4, common_backwardBranch  /* yes, do periodic checks */
    nop
1:  FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_IF_GT: /* 0x36 */
/* File: mips/OP_IF_GT.S */
/* File: mips/bincmp.S */
    /*
     * Generic two-operand compare-and-branch operation.  Provide a "revcmp"
     * fragment that specifies the *reverse* comparison to perform, e.g.
     * for "if-le" you would use "gt".
     *
     * For: if-eq, if-ne, if-lt, if-ge, if-gt, if-le
     */
    /* if-cmp vA, vB, +CCCC */
    srl     a0, rINST, 8               /* a0<- A+ */
    srl     a1, rINST, 12              /* a1<- B */
    andi    a0, a0, 15
    GET_VREG(a3, a1)                   /* a3<- vB */
    GET_VREG(a2, a0)                   /* a2<- vA */
    li      s4, 4                      /* s4<- BYTE branch dist for not-taken */
    subu    t6, a2, a3                 /* compare (vA, vB) */
    blez  t6, 1f                 /* branch to 1 if comparison failed */
    nop
    FETCH_S(s4, 1)                     /* s4<- branch offset, in code units */
    sll     s4, s4, 1                  /* convert to bytes, check sign */
    bltz    s4, common_backwardBranch  /* yes, do periodic checks */
    nop
1:  FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_IF_LE: /* 0x37 */
/* File: mips/OP_IF_LE.S */
/* File: mips/bincmp.S */
    /*
     * Generic two-operand compare-and-branch operation.  Provide a "revcmp"
     * fragment that specifies the *reverse* comparison to perform, e.g.
     * for "if-le" you would use "gt".
     *
     * For: if-eq, if-ne, if-lt, if-ge, if-gt, if-le
     */
    /* if-cmp vA, vB, +CCCC */
    srl     a0, rINST, 8               /* a0<- A+ */
    srl     a1, rINST, 12              /* a1<- B */
    andi    a0, a0, 15
    GET_VREG(a3, a1)                   /* a3<- vB */
    GET_VREG(a2, a0)                   /* a2<- vA */
    li      s4, 4                      /* s4<- BYTE branch dist for not-taken */
    subu    t6, a2, a3                 /* compare (vA, vB) */
    bgtz  t6, 1f                 /* branch to 1 if comparison failed */
    nop
    FETCH_S(s4, 1)                     /* s4<- branch offset, in code units */
    sll     s4, s4, 1                  /* convert to bytes, check sign */
    bltz    s4, common_backwardBranch  /* yes, do periodic checks */
    nop
1:  FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_IF_EQZ: /* 0x38 */
/* File: mips/OP_IF_EQZ.S */
/* File: mips/zcmp.S */
    /*
     * Generic one-operand compare-and-branch operation.  Provide a "revcmp"
     * fragment that specifies the *reverse* comparison to perform, e.g.
     * for "if-le" you would use "gt".
     *
     * for: if-eqz, if-nez, if-ltz, if-gez, if-gtz, if-lez
     */
    /* if-cmp vAA, +BBBB */
    srl     a0, rINST, 8               /* a0<- AA */
    GET_VREG(a2, a0)                   /* a2<- vAA */
    li      s4, 4                      /* s4<- BYTE branch dist for not-taken */
    bnez  a2, 1f                 /* compare (vA, 0) */
    nop                                /* branch to 1 if comparison failed */
    FETCH_S(s4, 1)                     /* s4<- branch offset, in code units */
    sll     s4, s4, 1                  /* convert to bytes, check sign */
    bltz    s4, common_backwardBranch  /* backward branch, do periodic checks */
    nop
1:  FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_IF_NEZ: /* 0x39 */
/* File: mips/OP_IF_NEZ.S */
/* File: mips/zcmp.S */
    /*
     * Generic one-operand compare-and-branch operation.  Provide a "revcmp"
     * fragment that specifies the *reverse* comparison to perform, e.g.
     * for "if-le" you would use "gt".
     *
     * for: if-eqz, if-nez, if-ltz, if-gez, if-gtz, if-lez
     */
    /* if-cmp vAA, +BBBB */
    srl     a0, rINST, 8               /* a0<- AA */
    GET_VREG(a2, a0)                   /* a2<- vAA */
    li      s4, 4                      /* s4<- BYTE branch dist for not-taken */
    beqz  a2, 1f                 /* compare (vA, 0) */
    nop                                /* branch to 1 if comparison failed */
    FETCH_S(s4, 1)                     /* s4<- branch offset, in code units */
    sll     s4, s4, 1                  /* convert to bytes, check sign */
    bltz    s4, common_backwardBranch  /* backward branch, do periodic checks */
    nop
1:  FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_IF_LTZ: /* 0x3a */
/* File: mips/OP_IF_LTZ.S */
/* File: mips/zcmp.S */
    /*
     * Generic one-operand compare-and-branch operation.  Provide a "revcmp"
     * fragment that specifies the *reverse* comparison to perform, e.g.
     * for "if-le" you would use "gt".
     *
     * for: if-eqz, if-nez, if-ltz, if-gez, if-gtz, if-lez
     */
    /* if-cmp vAA, +BBBB */
    srl     a0, rINST, 8               /* a0<- AA */
    GET_VREG(a2, a0)                   /* a2<- vAA */
    li      s4, 4                      /* s4<- BYTE branch dist for not-taken */
    bgez  a2, 1f                 /* compare (vA, 0) */
    nop                                /* branch to 1 if comparison failed */
    FETCH_S(s4, 1)                     /* s4<- branch offset, in code units */
    sll     s4, s4, 1                  /* convert to bytes, check sign */
    bltz    s4, common_backwardBranch  /* backward branch, do periodic checks */
    nop
1:  FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_IF_GEZ: /* 0x3b */
/* File: mips/OP_IF_GEZ.S */
/* File: mips/zcmp.S */
    /*
     * Generic one-operand compare-and-branch operation.  Provide a "revcmp"
     * fragment that specifies the *reverse* comparison to perform, e.g.
     * for "if-le" you would use "gt".
     *
     * for: if-eqz, if-nez, if-ltz, if-gez, if-gtz, if-lez
     */
    /* if-cmp vAA, +BBBB */
    srl     a0, rINST, 8               /* a0<- AA */
    GET_VREG(a2, a0)                   /* a2<- vAA */
    li      s4, 4                      /* s4<- BYTE branch dist for not-taken */
    bltz  a2, 1f                 /* compare (vA, 0) */
    nop                                /* branch to 1 if comparison failed */
    FETCH_S(s4, 1)                     /* s4<- branch offset, in code units */
    sll     s4, s4, 1                  /* convert to bytes, check sign */
    bltz    s4, common_backwardBranch  /* backward branch, do periodic checks */
    nop
1:  FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_IF_GTZ: /* 0x3c */
/* File: mips/OP_IF_GTZ.S */
/* File: mips/zcmp.S */
    /*
     * Generic one-operand compare-and-branch operation.  Provide a "revcmp"
     * fragment that specifies the *reverse* comparison to perform, e.g.
     * for "if-le" you would use "gt".
     *
     * for: if-eqz, if-nez, if-ltz, if-gez, if-gtz, if-lez
     */
    /* if-cmp vAA, +BBBB */
    srl     a0, rINST, 8               /* a0<- AA */
    GET_VREG(a2, a0)                   /* a2<- vAA */
    li      s4, 4                      /* s4<- BYTE branch dist for not-taken */
    blez  a2, 1f                 /* compare (vA, 0) */
    nop                                /* branch to 1 if comparison failed */
    FETCH_S(s4, 1)                     /* s4<- branch offset, in code units */
    sll     s4, s4, 1                  /* convert to bytes, check sign */
    bltz    s4, common_backwardBranch  /* backward branch, do periodic checks */
    nop
1:  FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_IF_LEZ: /* 0x3d */
/* File: mips/OP_IF_LEZ.S */
/* File: mips/zcmp.S */
    /*
     * Generic one-operand compare-and-branch operation.  Provide a "revcmp"
     * fragment that specifies the *reverse* comparison to perform, e.g.
     * for "if-le" you would use "gt".
     *
     * for: if-eqz, if-nez, if-ltz, if-gez, if-gtz, if-lez
     */
    /* if-cmp vAA, +BBBB */
    srl     a0, rINST, 8               /* a0<- AA */
    GET_VREG(a2, a0)                   /* a2<- vAA */
    li      s4, 4                      /* s4<- BYTE branch dist for not-taken */
    bgtz  a2, 1f                 /* compare (vA, 0) */
    nop                                /* branch to 1 if comparison failed */
    FETCH_S(s4, 1)                     /* s4<- branch offset, in code units */
    sll     s4, s4, 1                  /* convert to bytes, check sign */
    bltz    s4, common_backwardBranch  /* backward branch, do periodic checks */
    nop
1:  FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_3E: /* 0x3e */
/* File: mips/OP_UNUSED_3E.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_3F: /* 0x3f */
/* File: mips/OP_UNUSED_3F.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_40: /* 0x40 */
/* File: mips/OP_UNUSED_40.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_41: /* 0x41 */
/* File: mips/OP_UNUSED_41.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_42: /* 0x42 */
/* File: mips/OP_UNUSED_42.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_43: /* 0x43 */
/* File: mips/OP_UNUSED_43.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_AGET: /* 0x44 */
/* File: mips/OP_AGET.S */
    /*
     * Array get, 32 bits or less.  vAA <- vBB[vCC].
     *
     * for: aget, aget-object, aget-boolean, aget-byte, aget-char, aget-short
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a0, a2)                    /* a0<- vBB (array object) */
    GET_VREG(a1, a3)                    /* a1<- vCC (requested index) */
    beqz    a0, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a0)    /* a3<- arrayObj->length */
    sll     t6, a1, 2
    addu    a0, a0, t6                  /* a0<- arrayObj + index*width */
    subu    t5, a1, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    lw   a2, offArrayObject_contents(a0)  /* a2<- vBB[vCC] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a2, s4)                    /* vAA<- a2 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_AGET_WIDE: /* 0x45 */
/* File: mips/OP_AGET_WIDE.S */
    /*
     * Array get, 64 bits.  vAA <- vBB[vCC].
     */
    /* aget-wide vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a0, a2)                    /* a0<- vBB (array object) */
    GET_VREG(a1, a3)                    /* a1<- vCC (requested index) */
    beqz    a0, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a0)    /* a3<- arrayObj->length */
    sll     t6, a1, 3
    addu    a0, a0, t6                  /* a0<- arrayObj + index*width */
    subu    t5, a1, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    lw      a2, offArrayObject_contents(a0)  /* a2/a3<- vBB[vCC] */
    sll     s4, s4, 2
    lw      a3, offArrayObject_contents+4(a0)
    add     s4, rFP, s4                 /* s4<- &fp[AA] */
    sw      a2, 0(s4)                   /* vAA/vAA+1<- a2/a3 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      a3, 4(s4)
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_AGET_OBJECT: /* 0x46 */
/* File: mips/OP_AGET_OBJECT.S */
/* File: mips/OP_AGET.S */
    /*
     * Array get, 32 bits or less.  vAA <- vBB[vCC].
     *
     * for: aget, aget-object, aget-boolean, aget-byte, aget-char, aget-short
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a0, a2)                    /* a0<- vBB (array object) */
    GET_VREG(a1, a3)                    /* a1<- vCC (requested index) */
    beqz    a0, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a0)    /* a3<- arrayObj->length */
    sll     t6, a1, 2
    addu    a0, a0, t6                  /* a0<- arrayObj + index*width */
    subu    t5, a1, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    lw   a2, offArrayObject_contents(a0)  /* a2<- vBB[vCC] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a2, s4)                    /* vAA<- a2 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_AGET_BOOLEAN: /* 0x47 */
/* File: mips/OP_AGET_BOOLEAN.S */
/* File: mips/OP_AGET.S */
    /*
     * Array get, 32 bits or less.  vAA <- vBB[vCC].
     *
     * for: aget, aget-object, aget-boolean, aget-byte, aget-char, aget-short
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a0, a2)                    /* a0<- vBB (array object) */
    GET_VREG(a1, a3)                    /* a1<- vCC (requested index) */
    beqz    a0, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a0)    /* a3<- arrayObj->length */
    sll     t6, a1, 0
    addu    a0, a0, t6                  /* a0<- arrayObj + index*width */
    subu    t5, a1, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    lbu   a2, offArrayObject_contents(a0)  /* a2<- vBB[vCC] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a2, s4)                    /* vAA<- a2 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_AGET_BYTE: /* 0x48 */
/* File: mips/OP_AGET_BYTE.S */
/* File: mips/OP_AGET.S */
    /*
     * Array get, 32 bits or less.  vAA <- vBB[vCC].
     *
     * for: aget, aget-object, aget-boolean, aget-byte, aget-char, aget-short
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a0, a2)                    /* a0<- vBB (array object) */
    GET_VREG(a1, a3)                    /* a1<- vCC (requested index) */
    beqz    a0, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a0)    /* a3<- arrayObj->length */
    sll     t6, a1, 0
    addu    a0, a0, t6                  /* a0<- arrayObj + index*width */
    subu    t5, a1, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    lb   a2, offArrayObject_contents(a0)  /* a2<- vBB[vCC] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a2, s4)                    /* vAA<- a2 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_AGET_CHAR: /* 0x49 */
/* File: mips/OP_AGET_CHAR.S */
/* File: mips/OP_AGET.S */
    /*
     * Array get, 32 bits or less.  vAA <- vBB[vCC].
     *
     * for: aget, aget-object, aget-boolean, aget-byte, aget-char, aget-short
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a0, a2)                    /* a0<- vBB (array object) */
    GET_VREG(a1, a3)                    /* a1<- vCC (requested index) */
    beqz    a0, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a0)    /* a3<- arrayObj->length */
    sll     t6, a1, 1
    addu    a0, a0, t6                  /* a0<- arrayObj + index*width */
    subu    t5, a1, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    lhu   a2, offArrayObject_contents(a0)  /* a2<- vBB[vCC] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a2, s4)                    /* vAA<- a2 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_AGET_SHORT: /* 0x4a */
/* File: mips/OP_AGET_SHORT.S */
/* File: mips/OP_AGET.S */
    /*
     * Array get, 32 bits or less.  vAA <- vBB[vCC].
     *
     * for: aget, aget-object, aget-boolean, aget-byte, aget-char, aget-short
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a0, a2)                    /* a0<- vBB (array object) */
    GET_VREG(a1, a3)                    /* a1<- vCC (requested index) */
    beqz    a0, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a0)    /* a3<- arrayObj->length */
    sll     t6, a1, 1
    addu    a0, a0, t6                  /* a0<- arrayObj + index*width */
    subu    t5, a1, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    lh   a2, offArrayObject_contents(a0)  /* a2<- vBB[vCC] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a2, s4)                    /* vAA<- a2 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_APUT: /* 0x4b */
/* File: mips/OP_APUT.S */
    /*
     * Array put, 32 bits or less.  vBB[vCC] <- vAA.
     *
     * for: aput, aput-boolean, aput-byte, aput-char, aput-short
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a0, a2)                    /* a0<- vBB (array object) */
    GET_VREG(a1, a3)                    /* a1<- vCC (requested index) */
    beqz    a0, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a0)    /* a3<- arrayObj->length */
    sll     t6, a1, 2
    addu    a0, a0, t6                  /* a0<- arrayObj + index*width */
    subu    t5, a1, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_VREG(a2, s4)                    /* a2<- vAA */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw   a2, offArrayObject_contents(a0)  /* vBB[vCC]<- a2 */


/* ------------------------------ */
    .balign 128
.L_OP_APUT_WIDE: /* 0x4c */
/* File: mips/OP_APUT_WIDE.S */
    /*
     * Array put, 64 bits.  vBB[vCC] <- vAA.
     */
    /* aget-wide vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a0, a2)                    /* a0<- vBB (array object) */
    GET_VREG(a1, a3)                    /* a1<- vCC (requested index) */
    beqz    a0, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a0)    /* a3<- arrayObj->length */
    sll     t6, a1, 3
    addu    a0, a0, t6                  /* a0<- arrayObj + index*width */
    subu    t5, a1, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    sll     s4, s4, 2

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    addu    s4, rFP, s4                 /* s4<- &fp[AA] */
    lw      a2, 0(s4)                   /* a2/a3<- vAA/vAA+1 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    lw      a3, 4(s4)
    sw      a2, offArrayObject_contents(a0)  /* vBB[vCC]<- a2/a3 */
    GOTO_OPCODE_SLOT(t7)                     /* jump to next instruction */
    sw      a3, offArrayObject_contents+4(a0)


/* ------------------------------ */
    .balign 128
.L_OP_APUT_OBJECT: /* 0x4d */
/* File: mips/OP_APUT_OBJECT.S */
    /*
     * Store an object into an array.  vBB[vCC] <- vAA.
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a1, a2)                    /* a1<- vBB (array object) */
    GET_VREG(a0, a3)                    /* a0<- vCC (requested index) */
    beqz    a1, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a1)    /* a3<- arrayObj->length */
    sll     t6, a0, 2
    addu    s5, a1, t6                  /* s5<- arrayObj + index*width */
    subu    t5, a0, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    GET_VREG(s4, s4)			/* s4<- vAA */

    beqz    s4, .LOP_APUT_OBJECT_skip_check /* if null reference, skip type checks */
    lw      a1, offObject_clazz(a1)    /* r1<- arrayObj->clazz */
    LA(t9, dvmCanPutArrayElement)
    jalr    t9                          /* test object type vs. array type */
    lw      a0, offObject_clazz(s4)     /* a0<- obj->clazz */
    beqz    v0, common_errArrayStore    /* branch on error return */
.LOP_APUT_OBJECT_skip_check:
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      s4, offArrayObject_contents(s5) /* vBB[vCC]<- vAA */


/* ------------------------------ */
    .balign 128
.L_OP_APUT_BOOLEAN: /* 0x4e */
/* File: mips/OP_APUT_BOOLEAN.S */
/* File: mips/OP_APUT.S */
    /*
     * Array put, 32 bits or less.  vBB[vCC] <- vAA.
     *
     * for: aput, aput-boolean, aput-byte, aput-char, aput-short
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a0, a2)                    /* a0<- vBB (array object) */
    GET_VREG(a1, a3)                    /* a1<- vCC (requested index) */
    beqz    a0, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a0)    /* a3<- arrayObj->length */
    sll     t6, a1, 0
    addu    a0, a0, t6                  /* a0<- arrayObj + index*width */
    subu    t5, a1, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_VREG(a2, s4)                    /* a2<- vAA */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sb   a2, offArrayObject_contents(a0)  /* vBB[vCC]<- a2 */



/* ------------------------------ */
    .balign 128
.L_OP_APUT_BYTE: /* 0x4f */
/* File: mips/OP_APUT_BYTE.S */
/* File: mips/OP_APUT.S */
    /*
     * Array put, 32 bits or less.  vBB[vCC] <- vAA.
     *
     * for: aput, aput-boolean, aput-byte, aput-char, aput-short
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a0, a2)                    /* a0<- vBB (array object) */
    GET_VREG(a1, a3)                    /* a1<- vCC (requested index) */
    beqz    a0, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a0)    /* a3<- arrayObj->length */
    sll     t6, a1, 0
    addu    a0, a0, t6                  /* a0<- arrayObj + index*width */
    subu    t5, a1, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_VREG(a2, s4)                    /* a2<- vAA */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sb   a2, offArrayObject_contents(a0)  /* vBB[vCC]<- a2 */



/* ------------------------------ */
    .balign 128
.L_OP_APUT_CHAR: /* 0x50 */
/* File: mips/OP_APUT_CHAR.S */
/* File: mips/OP_APUT.S */
    /*
     * Array put, 32 bits or less.  vBB[vCC] <- vAA.
     *
     * for: aput, aput-boolean, aput-byte, aput-char, aput-short
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a0, a2)                    /* a0<- vBB (array object) */
    GET_VREG(a1, a3)                    /* a1<- vCC (requested index) */
    beqz    a0, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a0)    /* a3<- arrayObj->length */
    sll     t6, a1, 1
    addu    a0, a0, t6                  /* a0<- arrayObj + index*width */
    subu    t5, a1, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_VREG(a2, s4)                    /* a2<- vAA */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sh   a2, offArrayObject_contents(a0)  /* vBB[vCC]<- a2 */



/* ------------------------------ */
    .balign 128
.L_OP_APUT_SHORT: /* 0x51 */
/* File: mips/OP_APUT_SHORT.S */
/* File: mips/OP_APUT.S */
    /*
     * Array put, 32 bits or less.  vBB[vCC] <- vAA.
     *
     * for: aput, aput-boolean, aput-byte, aput-char, aput-short
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a0, a2)                    /* a0<- vBB (array object) */
    GET_VREG(a1, a3)                    /* a1<- vCC (requested index) */
    beqz    a0, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a0)    /* a3<- arrayObj->length */
    sll     t6, a1, 1
    addu    a0, a0, t6                  /* a0<- arrayObj + index*width */
    subu    t5, a1, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_VREG(a2, s4)                    /* a2<- vAA */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sh   a2, offArrayObject_contents(a0)  /* vBB[vCC]<- a2 */



/* ------------------------------ */
    .balign 128
.L_OP_IGET: /* 0x52 */
/* File: mips/OP_IGET.S */
    /*
     * General 32-bit instance field get.
     *
     * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
     */
    /* op vA, vB, field@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref CCCC */
    lw      a2, offDvmDex_pResFields(a3) /* a2<- pDvmDex->pResFields */
    GET_VREG(s4, a0)                    /* s4<- fp[B], the object pointer */
    sll     t6, a1, 2
    addu    t6, a2, t6
    lw      v0, 0(t6)                   /* a0<- resolved InstField ptr */
    bnez    v0, .LOP_IGET_finish      /* if not null, already resolved */
    lw      a2, offGlue_method(rGLUE)   /* a2<- current method */
    EXPORT_PC()                         /* resolve() could throw */
    LA(t9, dvmResolveInstField)
    jalr    t9                          /* v0<- resolved InstField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    bnez    v0, .LOP_IGET_finish      /* if not null, finish up */
    nop
    b       common_exceptionThrown      /* Bail on null pointer */
    nop


/* ------------------------------ */
    .balign 128
.L_OP_IGET_WIDE: /* 0x53 */
/* File: mips/OP_IGET_WIDE.S */
    /*
     *  Wide 32-bit instance field get.
     */
    /* iget-wide vA, vB, field@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref CCCC */
    lw      a2, offDvmDex_pResFields(a3) /* a2<- pDvmDex->pResFields */
    GET_VREG(s4, a0)                    /* s4<- fp[B], the object pointer */
    sll     t6, a1, 2
    addu    t6, a2, t6
    lw      v0, 0(t6)                   /* a0<- resolved InstField ptr */
    bnez    v0, .LOP_IGET_WIDE_finish      /* if not null, already resolved */
    lw      a2, offGlue_method(rGLUE)   /* a2<- current method */
    EXPORT_PC()                         /* resolve() could throw */
    LA(t9, dvmResolveInstField)
    jalr    t9                          /* v0<- resolved InstField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    bnez    v0, .LOP_IGET_WIDE_finish      /* if not null, finish up */
    nop
    b       common_exceptionThrown      /* Bail on null pointer */
    nop


/* ------------------------------ */
    .balign 128
.L_OP_IGET_OBJECT: /* 0x54 */
/* File: mips/OP_IGET_OBJECT.S */
/* File: mips/OP_IGET.S */
    /*
     * General 32-bit instance field get.
     *
     * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
     */
    /* op vA, vB, field@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref CCCC */
    lw      a2, offDvmDex_pResFields(a3) /* a2<- pDvmDex->pResFields */
    GET_VREG(s4, a0)                    /* s4<- fp[B], the object pointer */
    sll     t6, a1, 2
    addu    t6, a2, t6
    lw      v0, 0(t6)                   /* a0<- resolved InstField ptr */
    bnez    v0, .LOP_IGET_OBJECT_finish      /* if not null, already resolved */
    lw      a2, offGlue_method(rGLUE)   /* a2<- current method */
    EXPORT_PC()                         /* resolve() could throw */
    LA(t9, dvmResolveInstField)
    jalr    t9                          /* v0<- resolved InstField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    bnez    v0, .LOP_IGET_OBJECT_finish      /* if not null, finish up */
    nop
    b       common_exceptionThrown      /* Bail on null pointer */
    nop



/* ------------------------------ */
    .balign 128
.L_OP_IGET_BOOLEAN: /* 0x55 */
/* File: mips/OP_IGET_BOOLEAN.S */
/* include "mips/OP_IGET.S" { "load":"lbu" } */
/* File: mips/OP_IGET.S */
    /*
     * General 32-bit instance field get.
     *
     * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
     */
    /* op vA, vB, field@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref CCCC */
    lw      a2, offDvmDex_pResFields(a3) /* a2<- pDvmDex->pResFields */
    GET_VREG(s4, a0)                    /* s4<- fp[B], the object pointer */
    sll     t6, a1, 2
    addu    t6, a2, t6
    lw      v0, 0(t6)                   /* a0<- resolved InstField ptr */
    bnez    v0, .LOP_IGET_BOOLEAN_finish      /* if not null, already resolved */
    lw      a2, offGlue_method(rGLUE)   /* a2<- current method */
    EXPORT_PC()                         /* resolve() could throw */
    LA(t9, dvmResolveInstField)
    jalr    t9                          /* v0<- resolved InstField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    bnez    v0, .LOP_IGET_BOOLEAN_finish      /* if not null, finish up */
    nop
    b       common_exceptionThrown      /* Bail on null pointer */
    nop



/* ------------------------------ */
    .balign 128
.L_OP_IGET_BYTE: /* 0x56 */
/* File: mips/OP_IGET_BYTE.S */
/* include "mips/OP_IGET.S" { "load":"lb", } */
/* File: mips/OP_IGET.S */
    /*
     * General 32-bit instance field get.
     *
     * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
     */
    /* op vA, vB, field@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref CCCC */
    lw      a2, offDvmDex_pResFields(a3) /* a2<- pDvmDex->pResFields */
    GET_VREG(s4, a0)                    /* s4<- fp[B], the object pointer */
    sll     t6, a1, 2
    addu    t6, a2, t6
    lw      v0, 0(t6)                   /* a0<- resolved InstField ptr */
    bnez    v0, .LOP_IGET_BYTE_finish      /* if not null, already resolved */
    lw      a2, offGlue_method(rGLUE)   /* a2<- current method */
    EXPORT_PC()                         /* resolve() could throw */
    LA(t9, dvmResolveInstField)
    jalr    t9                          /* v0<- resolved InstField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    bnez    v0, .LOP_IGET_BYTE_finish      /* if not null, finish up */
    nop
    b       common_exceptionThrown      /* Bail on null pointer */
    nop



/* ------------------------------ */
    .balign 128
.L_OP_IGET_CHAR: /* 0x57 */
/* File: mips/OP_IGET_CHAR.S */
/* include "mips/OP_IGET.S" { "load":"lhu", } */
/* File: mips/OP_IGET.S */
    /*
     * General 32-bit instance field get.
     *
     * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
     */
    /* op vA, vB, field@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref CCCC */
    lw      a2, offDvmDex_pResFields(a3) /* a2<- pDvmDex->pResFields */
    GET_VREG(s4, a0)                    /* s4<- fp[B], the object pointer */
    sll     t6, a1, 2
    addu    t6, a2, t6
    lw      v0, 0(t6)                   /* a0<- resolved InstField ptr */
    bnez    v0, .LOP_IGET_CHAR_finish      /* if not null, already resolved */
    lw      a2, offGlue_method(rGLUE)   /* a2<- current method */
    EXPORT_PC()                         /* resolve() could throw */
    LA(t9, dvmResolveInstField)
    jalr    t9                          /* v0<- resolved InstField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    bnez    v0, .LOP_IGET_CHAR_finish      /* if not null, finish up */
    nop
    b       common_exceptionThrown      /* Bail on null pointer */
    nop



/* ------------------------------ */
    .balign 128
.L_OP_IGET_SHORT: /* 0x58 */
/* File: mips/OP_IGET_SHORT.S */
/* include "mips/OP_IGET.S" { "load":"lh" } */
/* File: mips/OP_IGET.S */
    /*
     * General 32-bit instance field get.
     *
     * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
     */
    /* op vA, vB, field@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref CCCC */
    lw      a2, offDvmDex_pResFields(a3) /* a2<- pDvmDex->pResFields */
    GET_VREG(s4, a0)                    /* s4<- fp[B], the object pointer */
    sll     t6, a1, 2
    addu    t6, a2, t6
    lw      v0, 0(t6)                   /* a0<- resolved InstField ptr */
    bnez    v0, .LOP_IGET_SHORT_finish      /* if not null, already resolved */
    lw      a2, offGlue_method(rGLUE)   /* a2<- current method */
    EXPORT_PC()                         /* resolve() could throw */
    LA(t9, dvmResolveInstField)
    jalr    t9                          /* v0<- resolved InstField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    bnez    v0, .LOP_IGET_SHORT_finish      /* if not null, finish up */
    nop
    b       common_exceptionThrown      /* Bail on null pointer */
    nop



/* ------------------------------ */
    .balign 128
.L_OP_IPUT: /* 0x59 */
/* File: mips/OP_IPUT.S */
    /*
     * General 32-bit instance field put.
     *
     * for: iput, iput-object, iput-boolean, iput-byte, iput-char, iput-short
     */
    /* op vA, vB, field@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref CCCC */
    lw      a2, offDvmDex_pResFields(a3) /* a2<- pDvmDex->pResFields */
    GET_VREG(s4, a0)                    /* s4<- fp[B], the object pointer */
    sll     t6, a1, 2
    addu    t6, a2, t6
    lw      v0, 0(t6)                   /* a0<- resolved InstField ptr */
    bnez    v0, .LOP_IPUT_finish      /* if not null, already resolved */
    lw      a2, offGlue_method(rGLUE)   /* a2<- current method */
    EXPORT_PC()                         /* resolve() could throw */
    LA(t9, dvmResolveInstField)
    jalr    t9                          /* v0<- resolved InstField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    bnez    v0, .LOP_IPUT_finish      /* if not null, finish up */
    nop
    b       common_exceptionThrown      /* Bail on null pointer */
    nop

/* ------------------------------ */
    .balign 128
.L_OP_IPUT_WIDE: /* 0x5a */
/* File: mips/OP_IPUT_WIDE.S */
    /*
     * General 32-bit instance field put.
     *
     * for: iput, iput-object, iput-boolean, iput-byte, iput-char, iput-short
     */
    /* op vA, vB, field@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref CCCC */
    lw      a2, offDvmDex_pResFields(a3) /* a2<- pDvmDex->pResFields */
    GET_VREG(s4, a0)                    /* s4<- fp[B], the object pointer */
    sll     t6, a1, 2
    addu    t6, a2, t6
    lw      v0, 0(t6)                   /* a0<- resolved InstField ptr */
    bnez    v0, .LOP_IPUT_WIDE_finish      /* if not null, already resolved */
    lw      a2, offGlue_method(rGLUE)   /* a2<- current method */
    EXPORT_PC()                         /* resolve() could throw */
    LA(t9, dvmResolveInstField)
    jalr    t9                          /* v0<- resolved InstField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    bnez    v0, .LOP_IPUT_WIDE_finish      /* if not null, finish up */
    nop
    b       common_exceptionThrown      /* Bail on null pointer */
    nop

/* ------------------------------ */
    .balign 128
.L_OP_IPUT_OBJECT: /* 0x5b */
/* File: mips/OP_IPUT_OBJECT.S */
/* File: mips/OP_IPUT.S */
    /*
     * General 32-bit instance field put.
     *
     * for: iput, iput-object, iput-boolean, iput-byte, iput-char, iput-short
     */
    /* op vA, vB, field@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref CCCC */
    lw      a2, offDvmDex_pResFields(a3) /* a2<- pDvmDex->pResFields */
    GET_VREG(s4, a0)                    /* s4<- fp[B], the object pointer */
    sll     t6, a1, 2
    addu    t6, a2, t6
    lw      v0, 0(t6)                   /* a0<- resolved InstField ptr */
    bnez    v0, .LOP_IPUT_OBJECT_finish      /* if not null, already resolved */
    lw      a2, offGlue_method(rGLUE)   /* a2<- current method */
    EXPORT_PC()                         /* resolve() could throw */
    LA(t9, dvmResolveInstField)
    jalr    t9                          /* v0<- resolved InstField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    bnez    v0, .LOP_IPUT_OBJECT_finish      /* if not null, finish up */
    nop
    b       common_exceptionThrown      /* Bail on null pointer */
    nop


/* ------------------------------ */
    .balign 128
.L_OP_IPUT_BOOLEAN: /* 0x5c */
/* File: mips/OP_IPUT_BOOLEAN.S */
/* include "mips/OP_IPUT.S" { "store":"sb" } */
/* File: mips/OP_IPUT.S */
    /*
     * General 32-bit instance field put.
     *
     * for: iput, iput-object, iput-boolean, iput-byte, iput-char, iput-short
     */
    /* op vA, vB, field@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref CCCC */
    lw      a2, offDvmDex_pResFields(a3) /* a2<- pDvmDex->pResFields */
    GET_VREG(s4, a0)                    /* s4<- fp[B], the object pointer */
    sll     t6, a1, 2
    addu    t6, a2, t6
    lw      v0, 0(t6)                   /* a0<- resolved InstField ptr */
    bnez    v0, .LOP_IPUT_BOOLEAN_finish      /* if not null, already resolved */
    lw      a2, offGlue_method(rGLUE)   /* a2<- current method */
    EXPORT_PC()                         /* resolve() could throw */
    LA(t9, dvmResolveInstField)
    jalr    t9                          /* v0<- resolved InstField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    bnez    v0, .LOP_IPUT_BOOLEAN_finish      /* if not null, finish up */
    nop
    b       common_exceptionThrown      /* Bail on null pointer */
    nop


/* ------------------------------ */
    .balign 128
.L_OP_IPUT_BYTE: /* 0x5d */
/* File: mips/OP_IPUT_BYTE.S */
/* include "mips/OP_IPUT.S" { "store":"sb" } */
/* File: mips/OP_IPUT.S */
    /*
     * General 32-bit instance field put.
     *
     * for: iput, iput-object, iput-boolean, iput-byte, iput-char, iput-short
     */
    /* op vA, vB, field@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref CCCC */
    lw      a2, offDvmDex_pResFields(a3) /* a2<- pDvmDex->pResFields */
    GET_VREG(s4, a0)                    /* s4<- fp[B], the object pointer */
    sll     t6, a1, 2
    addu    t6, a2, t6
    lw      v0, 0(t6)                   /* a0<- resolved InstField ptr */
    bnez    v0, .LOP_IPUT_BYTE_finish      /* if not null, already resolved */
    lw      a2, offGlue_method(rGLUE)   /* a2<- current method */
    EXPORT_PC()                         /* resolve() could throw */
    LA(t9, dvmResolveInstField)
    jalr    t9                          /* v0<- resolved InstField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    bnez    v0, .LOP_IPUT_BYTE_finish      /* if not null, finish up */
    nop
    b       common_exceptionThrown      /* Bail on null pointer */
    nop


/* ------------------------------ */
    .balign 128
.L_OP_IPUT_CHAR: /* 0x5e */
/* File: mips/OP_IPUT_CHAR.S */
/* include "mips/OP_IPUT.S" { "store":"sh" } */
/* File: mips/OP_IPUT.S */
    /*
     * General 32-bit instance field put.
     *
     * for: iput, iput-object, iput-boolean, iput-byte, iput-char, iput-short
     */
    /* op vA, vB, field@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref CCCC */
    lw      a2, offDvmDex_pResFields(a3) /* a2<- pDvmDex->pResFields */
    GET_VREG(s4, a0)                    /* s4<- fp[B], the object pointer */
    sll     t6, a1, 2
    addu    t6, a2, t6
    lw      v0, 0(t6)                   /* a0<- resolved InstField ptr */
    bnez    v0, .LOP_IPUT_CHAR_finish      /* if not null, already resolved */
    lw      a2, offGlue_method(rGLUE)   /* a2<- current method */
    EXPORT_PC()                         /* resolve() could throw */
    LA(t9, dvmResolveInstField)
    jalr    t9                          /* v0<- resolved InstField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    bnez    v0, .LOP_IPUT_CHAR_finish      /* if not null, finish up */
    nop
    b       common_exceptionThrown      /* Bail on null pointer */
    nop


/* ------------------------------ */
    .balign 128
.L_OP_IPUT_SHORT: /* 0x5f */
/* File: mips/OP_IPUT_SHORT.S */
/* include "mips/OP_IPUT.S" { "store":"sh" } */
/* File: mips/OP_IPUT.S */
    /*
     * General 32-bit instance field put.
     *
     * for: iput, iput-object, iput-boolean, iput-byte, iput-char, iput-short
     */
    /* op vA, vB, field@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref CCCC */
    lw      a2, offDvmDex_pResFields(a3) /* a2<- pDvmDex->pResFields */
    GET_VREG(s4, a0)                    /* s4<- fp[B], the object pointer */
    sll     t6, a1, 2
    addu    t6, a2, t6
    lw      v0, 0(t6)                   /* a0<- resolved InstField ptr */
    bnez    v0, .LOP_IPUT_SHORT_finish      /* if not null, already resolved */
    lw      a2, offGlue_method(rGLUE)   /* a2<- current method */
    EXPORT_PC()                         /* resolve() could throw */
    LA(t9, dvmResolveInstField)
    jalr    t9                          /* v0<- resolved InstField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    bnez    v0, .LOP_IPUT_SHORT_finish      /* if not null, finish up */
    nop
    b       common_exceptionThrown      /* Bail on null pointer */
    nop


/* ------------------------------ */
    .balign 128
.L_OP_SGET: /* 0x60 */
/* File: mips/OP_SGET.S */
    /*
     * General 32-bit SGET handler.
     *
     * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
     */
    /* op vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    bnez    v0, .LOP_SGET_finish      /* if not null, finish */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */
    nop

.LOP_SGET_finish:           /* field ptr in v0 */
    lw      a1, offStaticField_value(v0) /* a1<- field value */
    srl     t5, rINST, 8                /* t5<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(a1, t5)                    /* fp[AA]<- a1 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* ------------------------------ */
    .balign 128
.L_OP_SGET_WIDE: /* 0x61 */
/* File: mips/OP_SGET_WIDE.S */
    /*
     * 64-bit SGET handler.
     */
    /* sget-wide vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    bnez    v0, .LOP_SGET_WIDE_finish      /* if not null, finish */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */
    nop

.LOP_SGET_WIDE_finish:
    srl     a1, rINST, 8                /* a1<- AA */
    lw      a2, offStaticField_value(v0) /* a2/a3<- field value (aligned) */
    lw      a3, offStaticField_value+4(v0)
    sll     a1, a1, 2
    addu    a1, rFP, a1                 /* a1<- &fp[AA] */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    sw      a2, 0(a1)                   /* vAA/vAA+1<- a2/a3 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a3, 4(a1)

/* ------------------------------ */
    .balign 128
.L_OP_SGET_OBJECT: /* 0x62 */
/* File: mips/OP_SGET_OBJECT.S */
/* File: mips/OP_SGET.S */
    /*
     * General 32-bit SGET handler.
     *
     * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
     */
    /* op vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    bnez    v0, .LOP_SGET_OBJECT_finish      /* if not null, finish */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */
    nop

.LOP_SGET_OBJECT_finish:           /* field ptr in v0 */
    lw      a1, offStaticField_value(v0) /* a1<- field value */
    srl     t5, rINST, 8                /* t5<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(a1, t5)                    /* fp[AA]<- a1 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_SGET_BOOLEAN: /* 0x63 */
/* File: mips/OP_SGET_BOOLEAN.S */
/* File: mips/OP_SGET.S */
    /*
     * General 32-bit SGET handler.
     *
     * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
     */
    /* op vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    bnez    v0, .LOP_SGET_BOOLEAN_finish      /* if not null, finish */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */
    nop

.LOP_SGET_BOOLEAN_finish:           /* field ptr in v0 */
    lw      a1, offStaticField_value(v0) /* a1<- field value */
    srl     t5, rINST, 8                /* t5<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(a1, t5)                    /* fp[AA]<- a1 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_SGET_BYTE: /* 0x64 */
/* File: mips/OP_SGET_BYTE.S */
/* File: mips/OP_SGET.S */
    /*
     * General 32-bit SGET handler.
     *
     * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
     */
    /* op vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    bnez    v0, .LOP_SGET_BYTE_finish      /* if not null, finish */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */
    nop

.LOP_SGET_BYTE_finish:           /* field ptr in v0 */
    lw      a1, offStaticField_value(v0) /* a1<- field value */
    srl     t5, rINST, 8                /* t5<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(a1, t5)                    /* fp[AA]<- a1 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_SGET_CHAR: /* 0x65 */
/* File: mips/OP_SGET_CHAR.S */
/* File: mips/OP_SGET.S */
    /*
     * General 32-bit SGET handler.
     *
     * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
     */
    /* op vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    bnez    v0, .LOP_SGET_CHAR_finish      /* if not null, finish */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */
    nop

.LOP_SGET_CHAR_finish:           /* field ptr in v0 */
    lw      a1, offStaticField_value(v0) /* a1<- field value */
    srl     t5, rINST, 8                /* t5<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(a1, t5)                    /* fp[AA]<- a1 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_SGET_SHORT: /* 0x66 */
/* File: mips/OP_SGET_SHORT.S */
/* File: mips/OP_SGET.S */
    /*
     * General 32-bit SGET handler.
     *
     * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
     */
    /* op vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    bnez    v0, .LOP_SGET_SHORT_finish      /* if not null, finish */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */
    nop

.LOP_SGET_SHORT_finish:           /* field ptr in v0 */
    lw      a1, offStaticField_value(v0) /* a1<- field value */
    srl     t5, rINST, 8                /* t5<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(a1, t5)                    /* fp[AA]<- a1 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_SPUT: /* 0x67 */
/* File: mips/OP_SPUT.S */
    /*
     * General 32-bit SPUT handler.
     *
     * for: sput, sput-object, sput-boolean, sput-byte, sput-char, sput-short
     */
    /* op vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    bnez    v0, .LOP_SPUT_finish      /* if not null, finish */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */

.LOP_SPUT_finish:   /* field ptr in v0 */
    srl     a2, rINST, 8                /* r2<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_VREG(a1, a2)                    /* r1<- fp[AA] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, offStaticField_value(v0) /* field<- vAA */


/* ------------------------------ */
    .balign 128
.L_OP_SPUT_WIDE: /* 0x68 */
/* File: mips/OP_SPUT_WIDE.S */
    /*
     * 64-bit SPUT handler.
     */
    /* sput-wide vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    srl     s4, rINST, 8                /* s4<- AA */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    sll     s4, s4, 2
    bnez    v0, .LOP_SPUT_WIDE_finish      /* if not null, finish */
    addu    s4, rFP, s4                 /* s4<- &fp[AA] */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */

.LOP_SPUT_WIDE_finish:        /* field ptr in v0, &fp[AA] in s4 */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    lw      a2, 0(s4)                   /* r2/r3<- vAA/vAA+1 */
    lw      a3, 4(s4)
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      a2, offStaticField_value(v0) /* field<- vAA/vAA+1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a3, offStaticField_value+4(v0)


/* ------------------------------ */
    .balign 128
.L_OP_SPUT_OBJECT: /* 0x69 */
/* File: mips/OP_SPUT_OBJECT.S */
/* File: mips/OP_SPUT.S */
    /*
     * General 32-bit SPUT handler.
     *
     * for: sput, sput-object, sput-boolean, sput-byte, sput-char, sput-short
     */
    /* op vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    bnez    v0, .LOP_SPUT_OBJECT_finish      /* if not null, finish */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */

.LOP_SPUT_OBJECT_finish:   /* field ptr in v0 */
    srl     a2, rINST, 8                /* r2<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_VREG(a1, a2)                    /* r1<- fp[AA] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, offStaticField_value(v0) /* field<- vAA */



/* ------------------------------ */
    .balign 128
.L_OP_SPUT_BOOLEAN: /* 0x6a */
/* File: mips/OP_SPUT_BOOLEAN.S */
/* File: mips/OP_SPUT.S */
    /*
     * General 32-bit SPUT handler.
     *
     * for: sput, sput-object, sput-boolean, sput-byte, sput-char, sput-short
     */
    /* op vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    bnez    v0, .LOP_SPUT_BOOLEAN_finish      /* if not null, finish */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */

.LOP_SPUT_BOOLEAN_finish:   /* field ptr in v0 */
    srl     a2, rINST, 8                /* r2<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_VREG(a1, a2)                    /* r1<- fp[AA] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, offStaticField_value(v0) /* field<- vAA */



/* ------------------------------ */
    .balign 128
.L_OP_SPUT_BYTE: /* 0x6b */
/* File: mips/OP_SPUT_BYTE.S */
/* File: mips/OP_SPUT.S */
    /*
     * General 32-bit SPUT handler.
     *
     * for: sput, sput-object, sput-boolean, sput-byte, sput-char, sput-short
     */
    /* op vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    bnez    v0, .LOP_SPUT_BYTE_finish      /* if not null, finish */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */

.LOP_SPUT_BYTE_finish:   /* field ptr in v0 */
    srl     a2, rINST, 8                /* r2<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_VREG(a1, a2)                    /* r1<- fp[AA] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, offStaticField_value(v0) /* field<- vAA */



/* ------------------------------ */
    .balign 128
.L_OP_SPUT_CHAR: /* 0x6c */
/* File: mips/OP_SPUT_CHAR.S */
/* File: mips/OP_SPUT.S */
    /*
     * General 32-bit SPUT handler.
     *
     * for: sput, sput-object, sput-boolean, sput-byte, sput-char, sput-short
     */
    /* op vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    bnez    v0, .LOP_SPUT_CHAR_finish      /* if not null, finish */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */

.LOP_SPUT_CHAR_finish:   /* field ptr in v0 */
    srl     a2, rINST, 8                /* r2<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_VREG(a1, a2)                    /* r1<- fp[AA] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, offStaticField_value(v0) /* field<- vAA */



/* ------------------------------ */
    .balign 128
.L_OP_SPUT_SHORT: /* 0x6d */
/* File: mips/OP_SPUT_SHORT.S */
/* File: mips/OP_SPUT.S */
    /*
     * General 32-bit SPUT handler.
     *
     * for: sput, sput-object, sput-boolean, sput-byte, sput-char, sput-short
     */
    /* op vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    bnez    v0, .LOP_SPUT_SHORT_finish      /* if not null, finish */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */

.LOP_SPUT_SHORT_finish:   /* field ptr in v0 */
    srl     a2, rINST, 8                /* r2<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_VREG(a1, a2)                    /* r1<- fp[AA] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, offStaticField_value(v0) /* field<- vAA */



/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_VIRTUAL: /* 0x6e */
/* File: mips/OP_INVOKE_VIRTUAL.S */
    /*
     * Handle a virtual method call.
     *
     * for: invoke-virtual, invoke-virtual/range
     */
    /* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
    /* op vAA, {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- pDvmDex */
    FETCH(a1, 1)                        /* a1<- BBBB */
    lw      a3, offDvmDex_pResMethods(a3)    /* a3<- pDvmDex->pResMethods */
    FETCH(s5, 2)                        /* s5<- GFED or CCCC */
    sll     t6, a1, 2
    addu    t6, t6, a3
    lw      v0, 0(a3)                   /* v0<- resolved baseMethod */
    .if     (!0)
    andi    s5, s5, 15                  /* s5<- D (or stays CCCC) */
    .endif
    bnez    v0, .LOP_INVOKE_VIRTUAL_continue    /* if resolved, continue on */
    EXPORT_PC()                         /* must export for invoke */
    lw      a3, offGlue_method(rGLUE)   /* a3<- glue->method */
    li      a2, METHOD_VIRTUAL          /* resolver method type */
    LA(t9,dvmResolveMethod)
    jalr    t9                          /* v0<- call(clazz, ref, flags) */
    lw      a0, offMethod_clazz(a3)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null return, handle exception */

    /*
     * At this point:
     *  v0 = resolved base method
     *  s5 = C or CCCC (index of first arg, which is the "this" ptr)
     */
.LOP_INVOKE_VIRTUAL_continue:
    GET_VREG(a1, s5)                        /* a1<- "this" ptr */
    lhu     a2, offMethod_methodIndex(v0)   /* a2<- baseMethod->methodIndex */
    beqz    a1, common_errNullObject        /* null "this", throw exception */
    nop
    lw      a3, offObject_clazz(a1)         /* a1<- thisPtr->clazz */
    lw      a3, offClassObject_vtable(a3)   /* a3<- thisPtr->clazz->vtable */
    sll     t5, a2, 2
    addu    t5, t5, a3
    b       common_invokeMethodNoRange    /* continue on */
    lw      a0, 0(t5)                        /* a0<- vtable[methodIndex] */


/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_SUPER: /* 0x6f */
    /* stub for OP_INVOKE_SUPER */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_INVOKE_SUPER  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_DIRECT: /* 0x70 */
    /* stub for OP_INVOKE_DIRECT */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_INVOKE_DIRECT  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_STATIC: /* 0x71 */
    /* stub for OP_INVOKE_STATIC */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_INVOKE_STATIC  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_INTERFACE: /* 0x72 */
    /* stub for OP_INVOKE_INTERFACE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_INVOKE_INTERFACE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_73: /* 0x73 */
/* File: mips/OP_UNUSED_73.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_VIRTUAL_RANGE: /* 0x74 */
/* File: mips/OP_INVOKE_VIRTUAL_RANGE.S */
/* File: mips/OP_INVOKE_VIRTUAL.S */
    /*
     * Handle a virtual method call.
     *
     * for: invoke-virtual, invoke-virtual/range
     */
    /* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
    /* op vAA, {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- pDvmDex */
    FETCH(a1, 1)                        /* a1<- BBBB */
    lw      a3, offDvmDex_pResMethods(a3)    /* a3<- pDvmDex->pResMethods */
    FETCH(s5, 2)                        /* s5<- GFED or CCCC */
    sll     t6, a1, 2
    addu    t6, t6, a3
    lw      v0, 0(a3)                   /* v0<- resolved baseMethod */
    .if     (!1)
    andi    s5, s5, 15                  /* s5<- D (or stays CCCC) */
    .endif
    bnez    v0, .LOP_INVOKE_VIRTUAL_RANGE_continue    /* if resolved, continue on */
    EXPORT_PC()                         /* must export for invoke */
    lw      a3, offGlue_method(rGLUE)   /* a3<- glue->method */
    li      a2, METHOD_VIRTUAL          /* resolver method type */
    LA(t9,dvmResolveMethod)
    jalr    t9                          /* v0<- call(clazz, ref, flags) */
    lw      a0, offMethod_clazz(a3)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null return, handle exception */

    /*
     * At this point:
     *  v0 = resolved base method
     *  s5 = C or CCCC (index of first arg, which is the "this" ptr)
     */
.LOP_INVOKE_VIRTUAL_RANGE_continue:
    GET_VREG(a1, s5)                        /* a1<- "this" ptr */
    lhu     a2, offMethod_methodIndex(v0)   /* a2<- baseMethod->methodIndex */
    beqz    a1, common_errNullObject        /* null "this", throw exception */
    nop
    lw      a3, offObject_clazz(a1)         /* a1<- thisPtr->clazz */
    lw      a3, offClassObject_vtable(a3)   /* a3<- thisPtr->clazz->vtable */
    sll     t5, a2, 2
    addu    t5, t5, a3
    b       common_invokeMethodRange    /* continue on */
    lw      a0, 0(t5)                        /* a0<- vtable[methodIndex] */



/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_SUPER_RANGE: /* 0x75 */
    /* stub for OP_INVOKE_SUPER_RANGE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_INVOKE_SUPER_RANGE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_DIRECT_RANGE: /* 0x76 */
    /* stub for OP_INVOKE_DIRECT_RANGE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_INVOKE_DIRECT_RANGE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_STATIC_RANGE: /* 0x77 */
    /* stub for OP_INVOKE_STATIC_RANGE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_INVOKE_STATIC_RANGE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_INTERFACE_RANGE: /* 0x78 */
    /* stub for OP_INVOKE_INTERFACE_RANGE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_INVOKE_INTERFACE_RANGE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_79: /* 0x79 */
/* File: mips/OP_UNUSED_79.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_7A: /* 0x7a */
/* File: mips/OP_UNUSED_7A.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_NEG_INT: /* 0x7b */
/* File: mips/OP_NEG_INT.S */
/* File: mips/unop.S */
    /*
     * Generic 32-bit unary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = op r0".
     * This could be an ARM instruction or a function call.
     *
     * for: neg-int, not-int, neg-float, int-to-float, float-to-int,
     *      int-to-byte, int-to-char, int-to-short
     */
    /* unop vA, vB */
    srl     a3, rINST, 12               /* a3<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a3)                    /* a0<- vB */
    andi    s4, s4, 15
                               /* optional op */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    subu    v0, zero, a0                              /* a0<- op, a0-a3 maybe changed */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */
    /* 9-10 instructions */


/* ------------------------------ */
    .balign 128
.L_OP_NOT_INT: /* 0x7c */
/* File: mips/OP_NOT_INT.S */
/* File: mips/unop.S */
    /*
     * Generic 32-bit unary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = op r0".
     * This could be an ARM instruction or a function call.
     *
     * for: neg-int, not-int, neg-float, int-to-float, float-to-int,
     *      int-to-byte, int-to-char, int-to-short
     */
    /* unop vA, vB */
    srl     a3, rINST, 12               /* a3<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a3)                    /* a0<- vB */
    andi    s4, s4, 15
                               /* optional op */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    nor     v0, zero, a0                              /* a0<- op, a0-a3 maybe changed */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */
    /* 9-10 instructions */


/* ------------------------------ */
    .balign 128
.L_OP_NEG_LONG: /* 0x7d */
/* File: mips/OP_NEG_LONG.S */
    /*
     * Generic 64-bit unary operation.
     *
     * For: neg-long
     */
    /* unop vA, vB */
    srl     s4, rINST, 8                /* r9<- A+ */
    srl     s5, rINST, 12               /* r3<- B */
    andi    s4, s4, 15
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[B] */
    sll     s4, s4, 2
    lw      a0, 0(s5)                   /* a0/a1<- vBB */
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a1, 4(s5)
    subu    v0, zero, a0
    sltu    a2, zero, v0
    subu    v1, zero, a1
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    subu    v1, v1, a2
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


/* ------------------------------ */
    .balign 128
.L_OP_NOT_LONG: /* 0x7e */
/* File: mips/OP_NOT_LONG.S */
/* File: mips/unopWide.S */
    /*
     * Generic 64-bit unary operation.
     *
     * For: neg-long, not-long, neg-double, long-to-double, double-to-long
     */
    /* unop vA, vB */
    srl     s4, rINST, 8                /* r9<- A+ */
    srl     s5, rINST, 12               /* r3<- B */
    andi    s4, s4, 15
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[B] */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a0, 0(s5)                   /* a0/a1<- vBB */
    lw      a1, 4(s5)
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    nor     v0, zero, a0                           /* optional op1  */
    nor     v1, zero, a1                              /* v0/v1<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)
    /* 12-13 instructions */



/* ------------------------------ */
    .balign 128
.L_OP_NEG_FLOAT: /* 0x7f */
/* File: mips/OP_NEG_FLOAT.S */
/* File: mips/unop.S */
    /*
     * Generic 32-bit unary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = op r0".
     * This could be an ARM instruction or a function call.
     *
     * for: neg-int, not-int, neg-float, int-to-float, float-to-int,
     *      int-to-byte, int-to-char, int-to-short
     */
    /* unop vA, vB */
    srl     a3, rINST, 12               /* a3<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a3)                    /* a0<- vB */
    andi    s4, s4, 15
    lui    v1, 0x8000                           /* optional op */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    xor     v0, a0, v1                              /* a0<- op, a0-a3 maybe changed */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */
    /* 9-10 instructions */


/* ------------------------------ */
    .balign 128
.L_OP_NEG_DOUBLE: /* 0x80 */
/* File: mips/OP_NEG_DOUBLE.S */
    /*
     * Generic 64-bit unary operation.
     *
     * For: neg-double
     */
    /* unop vA, vB */
    srl     s4, rINST, 8                /* r9<- A+ */
    srl     s5, rINST, 12               /* r3<- B */
    andi    s4, s4, 15
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[B] */
    sll     s4, s4, 2
    lw      a0, 0(s5)                   /* a0/a1<- vBB */
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a1, 4(s5)
    lui     t1, 0x8000
    move    v0, a0
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    xor     v1, a1, t1
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


/* ------------------------------ */
    .balign 128
.L_OP_INT_TO_LONG: /* 0x81 */
/* File: mips/OP_INT_TO_LONG.S */
/* File: mips/unopWider.S */
    /*
     * Generic 32bit-to-64bit unary operation.  Provide an "instr" line
     * that specifies an instruction that performs "v1 = op a0", where
     * "result" is a 64-bit quantity in v0/v1.
     *
     * For: int-to-long, int-to-double, float-to-long, float-to-double
     */
    /* unop vA, vB */
    srl     s4, rINST, 8                /* r9<- A+ */
    srl     s5, rINST, 12               /* r3<- B */
    andi    s4, s4, 15
    GET_VREG(a0, s5)                    /* r0<- vB */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* r9<- &fp[A] */
    move   v0, a0                           /* optional op */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    sra     v1, a0, 31                              /* v1<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vA/vA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /*  jump to next instruction */
    sw      v1, 4(s4)



/* ------------------------------ */
    .balign 128
.L_OP_INT_TO_FLOAT: /* 0x82 */
    /* stub for OP_INT_TO_FLOAT */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_INT_TO_FLOAT  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_INT_TO_DOUBLE: /* 0x83 */
    /* stub for OP_INT_TO_DOUBLE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_INT_TO_DOUBLE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_LONG_TO_INT: /* 0x84 */
/* File: mips/OP_LONG_TO_INT.S */
/* we ignore the high word, making this equivalent to a 32-bit reg move */
/* File: mips/OP_MOVE.S */
    /* for move, move-object, long-to-int */
    /* op vA, vB */
    srl     a1, rINST, 12               /* a1<- B from 15:12 */
    srl     a0, rINST, 8                /* a0<- A from 11:8 */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    GET_VREG(a2, a1)                    /* a2<- fp[B] */
    andi    a0, a0, 15
    GET_INST_OPCODE(t7)                 /* t7<- opcode from rINST */
    SET_VREG(a2, a0)                    /* fp[A]<- a2 */
    GOTO_OPCODE(t7)                     /* execute next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_LONG_TO_FLOAT: /* 0x85 */
    /* stub for OP_LONG_TO_FLOAT */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_LONG_TO_FLOAT  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_LONG_TO_DOUBLE: /* 0x86 */
    /* stub for OP_LONG_TO_DOUBLE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_LONG_TO_DOUBLE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_FLOAT_TO_INT: /* 0x87 */
    /* stub for OP_FLOAT_TO_INT */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_FLOAT_TO_INT  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_FLOAT_TO_LONG: /* 0x88 */
    /* stub for OP_FLOAT_TO_LONG */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_FLOAT_TO_LONG  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_FLOAT_TO_DOUBLE: /* 0x89 */
    /* stub for OP_FLOAT_TO_DOUBLE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_FLOAT_TO_DOUBLE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_DOUBLE_TO_INT: /* 0x8a */
    /* stub for OP_DOUBLE_TO_INT */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_DOUBLE_TO_INT  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_DOUBLE_TO_LONG: /* 0x8b */
    /* stub for OP_DOUBLE_TO_LONG */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_DOUBLE_TO_LONG  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_DOUBLE_TO_FLOAT: /* 0x8c */
    /* stub for OP_DOUBLE_TO_FLOAT */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_DOUBLE_TO_FLOAT  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_INT_TO_BYTE: /* 0x8d */
/* File: mips/OP_INT_TO_BYTE.S */
/* File: mips/unop.S */
    /*
     * Generic 32-bit unary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = op r0".
     * This could be an ARM instruction or a function call.
     *
     * for: neg-int, not-int, neg-float, int-to-float, float-to-int,
     *      int-to-byte, int-to-char, int-to-short
     */
    /* unop vA, vB */
    srl     a3, rINST, 12               /* a3<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a3)                    /* a0<- vB */
    andi    s4, s4, 15
    sll     v0, a0, 24                           /* optional op */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    sra     v0, v0, 24                              /* a0<- op, a0-a3 maybe changed */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */
    /* 9-10 instructions */


/* ------------------------------ */
    .balign 128
.L_OP_INT_TO_CHAR: /* 0x8e */
/* File: mips/OP_INT_TO_CHAR.S */
/* The ARM opcodes use an "asl" instructions, but there is no such thing.
 * The gcc/gas just silently turns this into an "lsl", so we really just
 * want to strip the uppper 16 bits of the word.
 */
/* File: mips/unop.S */
    /*
     * Generic 32-bit unary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = op r0".
     * This could be an ARM instruction or a function call.
     *
     * for: neg-int, not-int, neg-float, int-to-float, float-to-int,
     *      int-to-byte, int-to-char, int-to-short
     */
    /* unop vA, vB */
    srl     a3, rINST, 12               /* a3<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a3)                    /* a0<- vB */
    andi    s4, s4, 15
    sll     v0, a0, 16                           /* optional op */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    srl     v0, v0, 16                              /* a0<- op, a0-a3 maybe changed */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */
    /* 9-10 instructions */


/* ------------------------------ */
    .balign 128
.L_OP_INT_TO_SHORT: /* 0x8f */
/* File: mips/OP_INT_TO_SHORT.S */
/* File: mips/unop.S */
    /*
     * Generic 32-bit unary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = op r0".
     * This could be an ARM instruction or a function call.
     *
     * for: neg-int, not-int, neg-float, int-to-float, float-to-int,
     *      int-to-byte, int-to-char, int-to-short
     */
    /* unop vA, vB */
    srl     a3, rINST, 12               /* a3<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a3)                    /* a0<- vB */
    andi    s4, s4, 15
    sll     v0, a0, 16                           /* optional op */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    srl     v0, v0, 16                              /* a0<- op, a0-a3 maybe changed */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */
    /* 9-10 instructions */


/* ------------------------------ */
    .balign 128
.L_OP_ADD_INT: /* 0x90 */
/* File: mips/OP_ADD_INT.S */
/* File: mips/binop.S */
    /*
     * Generic 32-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int, sub-int, mul-int, div-int, rem-int, and-int, or-int,
     *      xor-int, shl-int, shr-int, ushr-int, add-float, sub-float,
     *      mul-float, div-float, rem-float
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    srl     a3, a0, 8                   /* a3<- CC */
    andi    a2, a0, 255                 /* a2<- BB */
    GET_VREG(a1, a3)                    /* a1<- vCC */
    GET_VREG(a0, a2)                    /* a0<- vBB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    nop
    .endif

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
                               /* optional op */
    addu    v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_SUB_INT: /* 0x91 */
/* File: mips/OP_SUB_INT.S */
/* File: mips/binop.S */
    /*
     * Generic 32-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int, sub-int, mul-int, div-int, rem-int, and-int, or-int,
     *      xor-int, shl-int, shr-int, ushr-int, add-float, sub-float,
     *      mul-float, div-float, rem-float
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    srl     a3, a0, 8                   /* a3<- CC */
    andi    a2, a0, 255                 /* a2<- BB */
    GET_VREG(a1, a3)                    /* a1<- vCC */
    GET_VREG(a0, a2)                    /* a0<- vBB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    nop
    .endif

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
                               /* optional op */
    subu    v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_MUL_INT: /* 0x92 */
/* File: mips/OP_MUL_INT.S */
/* File: mips/binop.S */
    /*
     * Generic 32-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int, sub-int, mul-int, div-int, rem-int, and-int, or-int,
     *      xor-int, shl-int, shr-int, ushr-int, add-float, sub-float,
     *      mul-float, div-float, rem-float
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    srl     a3, a0, 8                   /* a3<- CC */
    andi    a2, a0, 255                 /* a2<- BB */
    GET_VREG(a1, a3)                    /* a1<- vCC */
    GET_VREG(a0, a2)                    /* a0<- vBB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    nop
    .endif

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
                               /* optional op */
    mul     v0, a1, a0                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_DIV_INT: /* 0x93 */
/* File: mips/OP_DIV_INT.S */
/* File: mips/binop.S */
    /*
     * Generic 32-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int, sub-int, mul-int, div-int, rem-int, and-int, or-int,
     *      xor-int, shl-int, shr-int, ushr-int, add-float, sub-float,
     *      mul-float, div-float, rem-float
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    srl     a3, a0, 8                   /* a3<- CC */
    andi    a2, a0, 255                 /* a2<- BB */
    GET_VREG(a1, a3)                    /* a1<- vCC */
    GET_VREG(a0, a2)                    /* a0<- vBB */
    .if 1
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    nop
    .endif

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    div    zero, a0, a1                           /* optional op */
    mflo    v0                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_REM_INT: /* 0x94 */
/* File: mips/OP_REM_INT.S */
/* File: mips/binop.S */
    /*
     * Generic 32-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int, sub-int, mul-int, div-int, rem-int, and-int, or-int,
     *      xor-int, shl-int, shr-int, ushr-int, add-float, sub-float,
     *      mul-float, div-float, rem-float
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    srl     a3, a0, 8                   /* a3<- CC */
    andi    a2, a0, 255                 /* a2<- BB */
    GET_VREG(a1, a3)                    /* a1<- vCC */
    GET_VREG(a0, a2)                    /* a0<- vBB */
    .if 1
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    nop
    .endif

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    div    zero, a0, a1                           /* optional op */
    mfhi    v0                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_AND_INT: /* 0x95 */
/* File: mips/OP_AND_INT.S */
/* File: mips/binop.S */
    /*
     * Generic 32-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int, sub-int, mul-int, div-int, rem-int, and-int, or-int,
     *      xor-int, shl-int, shr-int, ushr-int, add-float, sub-float,
     *      mul-float, div-float, rem-float
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    srl     a3, a0, 8                   /* a3<- CC */
    andi    a2, a0, 255                 /* a2<- BB */
    GET_VREG(a1, a3)                    /* a1<- vCC */
    GET_VREG(a0, a2)                    /* a0<- vBB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    nop
    .endif

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
                               /* optional op */
    and     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_OR_INT: /* 0x96 */
/* File: mips/OP_OR_INT.S */
/* File: mips/binop.S */
    /*
     * Generic 32-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int, sub-int, mul-int, div-int, rem-int, and-int, or-int,
     *      xor-int, shl-int, shr-int, ushr-int, add-float, sub-float,
     *      mul-float, div-float, rem-float
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    srl     a3, a0, 8                   /* a3<- CC */
    andi    a2, a0, 255                 /* a2<- BB */
    GET_VREG(a1, a3)                    /* a1<- vCC */
    GET_VREG(a0, a2)                    /* a0<- vBB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    nop
    .endif

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
                               /* optional op */
    or     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_XOR_INT: /* 0x97 */
/* File: mips/OP_XOR_INT.S */
/* File: mips/binop.S */
    /*
     * Generic 32-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int, sub-int, mul-int, div-int, rem-int, and-int, or-int,
     *      xor-int, shl-int, shr-int, ushr-int, add-float, sub-float,
     *      mul-float, div-float, rem-float
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    srl     a3, a0, 8                   /* a3<- CC */
    andi    a2, a0, 255                 /* a2<- BB */
    GET_VREG(a1, a3)                    /* a1<- vCC */
    GET_VREG(a0, a2)                    /* a0<- vBB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    nop
    .endif

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
                               /* optional op */
    xor     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_SHL_INT: /* 0x98 */
/* File: mips/OP_SHL_INT.S */
/* File: mips/binop.S */
    /*
     * Generic 32-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int, sub-int, mul-int, div-int, rem-int, and-int, or-int,
     *      xor-int, shl-int, shr-int, ushr-int, add-float, sub-float,
     *      mul-float, div-float, rem-float
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    srl     a3, a0, 8                   /* a3<- CC */
    andi    a2, a0, 255                 /* a2<- BB */
    GET_VREG(a1, a3)                    /* a1<- vCC */
    GET_VREG(a0, a2)                    /* a0<- vBB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    nop
    .endif

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    andi    a1, a1, 31                           /* optional op */
    sllv     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_SHR_INT: /* 0x99 */
/* File: mips/OP_SHR_INT.S */
/* File: mips/binop.S */
    /*
     * Generic 32-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int, sub-int, mul-int, div-int, rem-int, and-int, or-int,
     *      xor-int, shl-int, shr-int, ushr-int, add-float, sub-float,
     *      mul-float, div-float, rem-float
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    srl     a3, a0, 8                   /* a3<- CC */
    andi    a2, a0, 255                 /* a2<- BB */
    GET_VREG(a1, a3)                    /* a1<- vCC */
    GET_VREG(a0, a2)                    /* a0<- vBB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    nop
    .endif

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    andi    a1, a1, 31                           /* optional op */
    srav     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_USHR_INT: /* 0x9a */
/* File: mips/OP_USHR_INT.S */
/* File: mips/binop.S */
    /*
     * Generic 32-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int, sub-int, mul-int, div-int, rem-int, and-int, or-int,
     *      xor-int, shl-int, shr-int, ushr-int, add-float, sub-float,
     *      mul-float, div-float, rem-float
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    srl     a3, a0, 8                   /* a3<- CC */
    andi    a2, a0, 255                 /* a2<- BB */
    GET_VREG(a1, a3)                    /* a1<- vCC */
    GET_VREG(a0, a2)                    /* a0<- vBB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    nop
    .endif

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    andi    a1, a1, 31                           /* optional op */
    srlv     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_ADD_LONG: /* 0x9b */
/* File: mips/OP_ADD_LONG.S */
/* File: mips/binopWide.S */
    /*
     * Generic 64-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0-a1 op a2-a3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * for: add-long, sub-long, div-long, rem-long, and-long, or-long,
     *      xor-long, add-double, sub-double, mul-double, div-double,
     *      rem-double
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    s6, a0, 255                 /* s6<- BB */
    srl     s5, a0, 8                   /* s5<- CC */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[AA] */
    sll     s6, s6, 2
    addu    s6, rFP, s6                 /* s6<- &fp[BB] */
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[CC] */
    lw      a0, 0(s6)                   /* a0/a1<- vBB/vBB+1 */
    lw      a1, 4(s6)
    lw      a2, 0(s5)                   /* a2/a3<- vCC/vCC+1 */
    lw      a3, 4(s5)
    .if 0
    or      t7, a2, a3                  /* second arg (a2-a3) is zero? */
    beqz    t7, common_errDivideByZero
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    addu    v0, a0, a2; sltu t7,v0,a0                             /* Probably several comma separated */
    addu     t6, a1, a3; addu v1,t6,t7                             /* result<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)             /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)



/* ------------------------------ */
    .balign 128
.L_OP_SUB_LONG: /* 0x9c */
/* File: mips/OP_SUB_LONG.S */
/* File: mips/binopWide.S */
    /*
     * Generic 64-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0-a1 op a2-a3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * for: add-long, sub-long, div-long, rem-long, and-long, or-long,
     *      xor-long, add-double, sub-double, mul-double, div-double,
     *      rem-double
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    s6, a0, 255                 /* s6<- BB */
    srl     s5, a0, 8                   /* s5<- CC */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[AA] */
    sll     s6, s6, 2
    addu    s6, rFP, s6                 /* s6<- &fp[BB] */
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[CC] */
    lw      a0, 0(s6)                   /* a0/a1<- vBB/vBB+1 */
    lw      a1, 4(s6)
    lw      a2, 0(s5)                   /* a2/a3<- vCC/vCC+1 */
    lw      a3, 4(s5)
    .if 0
    or      t7, a2, a3                  /* second arg (a2-a3) is zero? */
    beqz    t7, common_errDivideByZero
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    subu    v0, a0, a2; sltu t7,a0,v0                             /* Probably several comma separated */
    subu     t6, a1, a3; subu v1,t6,t7                             /* result<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)             /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)



/* ------------------------------ */
    .balign 128
.L_OP_MUL_LONG: /* 0x9d */
/* File: mips/OP_MUL_LONG.S */
    /*
     * Generic 64-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0-a1 op a2-a3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * for: add-long, sub-long, div-long, rem-long, and-long, or-long,
     *      xor-long, add-double, sub-double, mul-double, div-double,
     *      rem-double
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    s6, a0, 255                 /* s6<- BB */
    srl     s5, a0, 8                   /* s5<- CC */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[AA] */
    sll     s6, s6, 2
    addu    s6, rFP, s6                 /* s6<- &fp[BB] */
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[CC] */
    lw      a0, 0(s6)                   /* a0/a1<- vBB/vBB+1 */
    lw      a1, 4(s6)
    lw      a3, 4(s5)
    lw      a2, 0(s5)                   /* a2/a3<- vCC/vCC+1 */
    mul	    t3, a3, a0
    multu   a0, a2
    mflo    v0
    mfhi    t1
    mul     t2, a1, a2
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    addu    v1, t2, t3
    addu    v1, v1, t1
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


/* ------------------------------ */
    .balign 128
.L_OP_DIV_LONG: /* 0x9e */
/* File: mips/OP_DIV_LONG.S */
    /*
     * Generic 64-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0-a1 op a2-a3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * for: add-long, sub-long, div-long, rem-long, and-long, or-long,
     *      xor-long, add-double, sub-double, mul-double, div-double,
     *      rem-double
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    s6, a0, 255                 /* s6<- BB */
    srl     s5, a0, 8                   /* s5<- CC */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[AA] */
    sll     s6, s6, 2
    addu    s6, rFP, s6                 /* s6<- &fp[BB] */
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[CC] */
    lw      a2, 0(s5)                   /* a2/a3<- vCC/vCC+1 */
    lw      a3, 4(s5)			/* divisor */
    lw      a0, 0(s6)                   /* a0/a1<- vBB/vBB+1, dividend */
    or      t1, a2, a3
    beqz    t1, common_errDivideByZero
    lw      a1, 4(s6)
    beqz    a0, testneg_OP_DIV_LONG
    lui     t4, 0x8000
divit_OP_DIV_LONG:
    LA(t9, __divdi3)
    jalr    t9
    nop

store_OP_DIV_LONG:
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


/* ------------------------------ */
    .balign 128
.L_OP_REM_LONG: /* 0x9f */
/* File: mips/OP_REM_LONG.S */
    /*
     * Generic 64-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0-a1 op a2-a3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * for: add-long, sub-long, div-long, rem-long, and-long, or-long,
     *      xor-long, add-double, sub-double, mul-double, div-double,
     *      rem-double
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    s6, a0, 255                 /* s6<- BB */
    srl     s5, a0, 8                   /* s5<- CC */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[AA] */
    sll     s6, s6, 2
    addu    s6, rFP, s6                 /* s6<- &fp[BB] */
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[CC] */
    lw      a2, 0(s5)                   /* a2/a3<- vCC/vCC+1 */
    lw      a3, 4(s5)			/* divisor */
    lw      a0, 0(s6)                   /* a0/a1<- vBB/vBB+1, dividend */
    or      t1, a2, a3
    beqz    t1, common_errDivideByZero
    lw      a1, 4(s6)
    beqz    a0, testneg_OP_REM_LONG
    lui     t4, 0x8000
divit_OP_REM_LONG:
    LA(t9, __moddi3)
    jalr    t9
    nop

store_OP_REM_LONG:
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


/* ------------------------------ */
    .balign 128
.L_OP_AND_LONG: /* 0xa0 */
/* File: mips/OP_AND_LONG.S */
/* File: mips/binopWide.S */
    /*
     * Generic 64-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0-a1 op a2-a3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * for: add-long, sub-long, div-long, rem-long, and-long, or-long,
     *      xor-long, add-double, sub-double, mul-double, div-double,
     *      rem-double
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    s6, a0, 255                 /* s6<- BB */
    srl     s5, a0, 8                   /* s5<- CC */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[AA] */
    sll     s6, s6, 2
    addu    s6, rFP, s6                 /* s6<- &fp[BB] */
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[CC] */
    lw      a0, 0(s6)                   /* a0/a1<- vBB/vBB+1 */
    lw      a1, 4(s6)
    lw      a2, 0(s5)                   /* a2/a3<- vCC/vCC+1 */
    lw      a3, 4(s5)
    .if 0
    or      t7, a2, a3                  /* second arg (a2-a3) is zero? */
    beqz    t7, common_errDivideByZero
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    and     v0, a0, a2                             /* Probably several comma separated */
    and      v1, a1, a3                             /* result<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)             /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)



/* ------------------------------ */
    .balign 128
.L_OP_OR_LONG: /* 0xa1 */
/* File: mips/OP_OR_LONG.S */
/* File: mips/binopWide.S */
    /*
     * Generic 64-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0-a1 op a2-a3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * for: add-long, sub-long, div-long, rem-long, and-long, or-long,
     *      xor-long, add-double, sub-double, mul-double, div-double,
     *      rem-double
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    s6, a0, 255                 /* s6<- BB */
    srl     s5, a0, 8                   /* s5<- CC */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[AA] */
    sll     s6, s6, 2
    addu    s6, rFP, s6                 /* s6<- &fp[BB] */
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[CC] */
    lw      a0, 0(s6)                   /* a0/a1<- vBB/vBB+1 */
    lw      a1, 4(s6)
    lw      a2, 0(s5)                   /* a2/a3<- vCC/vCC+1 */
    lw      a3, 4(s5)
    .if 0
    or      t7, a2, a3                  /* second arg (a2-a3) is zero? */
    beqz    t7, common_errDivideByZero
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    or     v0, a0, a2                             /* Probably several comma separated */
    or      v1, a1, a3                             /* result<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)             /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)



/* ------------------------------ */
    .balign 128
.L_OP_XOR_LONG: /* 0xa2 */
/* File: mips/OP_XOR_LONG.S */
/* File: mips/binopWide.S */
    /*
     * Generic 64-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0-a1 op a2-a3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * for: add-long, sub-long, div-long, rem-long, and-long, or-long,
     *      xor-long, add-double, sub-double, mul-double, div-double,
     *      rem-double
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    s6, a0, 255                 /* s6<- BB */
    srl     s5, a0, 8                   /* s5<- CC */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[AA] */
    sll     s6, s6, 2
    addu    s6, rFP, s6                 /* s6<- &fp[BB] */
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[CC] */
    lw      a0, 0(s6)                   /* a0/a1<- vBB/vBB+1 */
    lw      a1, 4(s6)
    lw      a2, 0(s5)                   /* a2/a3<- vCC/vCC+1 */
    lw      a3, 4(s5)
    .if 0
    or      t7, a2, a3                  /* second arg (a2-a3) is zero? */
    beqz    t7, common_errDivideByZero
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    xor     v0, a0, a2                             /* Probably several comma separated */
    xor      v1, a1, a3                             /* result<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)             /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)



/* ------------------------------ */
    .balign 128
.L_OP_SHL_LONG: /* 0xa3 */
/* File: mips/OP_SHL_LONG.S */
    /*
     * Long integer shift.  This is different from the generic 32/64-bit
     * binary operations because vAA/vBB are 64-bit but vCC (the shift
     * distance) is 32-bit.  Also, Dalvik requires us to mask off the low
     * 6 bits of the shift distance.
     */
    /* shl-long vAA, vBB, vCC */
    FETCH(a0, 1)                       /* a0<- CCBB */
    srl     s4, rINST, 8               /* s4<- AA */
    andi    s5, a0, 255                /* s5<- BB */
    srl     s6, a0, 8                  /* s6<- CC */
    sll     s5, s5, 2
    add     s5, rFP, s5                 /* s5<- &fp[BB] */
    GET_VREG(t7, s6)                    /* t7<- vCC */
    lw      a0, 0(s5)                   /* a0/a1<- vBB/vBB+1 */
    lw      a1, 4(s5)
    andi    t0, t7, 63                  /* t0<- t7 & 0x3f */
    sll     s4, s4, 2
    add     s4, rFP, s4                 /* s4<- &fp[AA] */

    nor     t2, zero, t0
    srl     t9, a0, 1
    srlv    a2, t9, t2
    sllv    t6, a1, t0
    andi    t1, t7, 0x20
    sllv    v0, a0, t0
    or      v1, a2, t6
    movn    v1, v0, t1

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    movn    v0, zero, t1
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


/* ------------------------------ */
    .balign 128
.L_OP_SHR_LONG: /* 0xa4 */
/* File: mips/OP_SHR_LONG.S */
    /*
     * Long integer shift.  This is different from the generic 32/64-bit
     * binary operations because vAA/vBB are 64-bit but vCC (the shift
     * distance) is 32-bit.  Also, Dalvik requires us to mask off the low
     * 6 bits of the shift distance.
     */
    /* shl-long vAA, vBB, vCC */
    FETCH(a0, 1)                       /* a0<- CCBB */
    srl     s4, rINST, 8               /* s4<- AA */
    andi    s5, a0, 255                /* s5<- BB */
    srl     s6, a0, 8                  /* s6<- CC */
    sll     s5, s5, 2
    add     s5, rFP, s5                 /* s5<- &fp[BB] */
    GET_VREG(t7, s6)                    /* t7<- vCC */
    lw      a0, 0(s5)                   /* a0/a1<- vBB/vBB+1 */
    lw      a1, 4(s5)
    andi    t1, t7, 63                  /* t0<- t7 & 0x3f */
    sll     s4, s4, 2
    add     s4, rFP, s4                 /* s4<- &fp[AA] */

    sll     t2, a1, 1
    nor     v0, zero, t1
    sllv    a2, t2, v0
    srlv    t6, a0, t1
    andi    t0, t7, 0x20
    srav    v1, a1, t1
    sra     t4, a1, 31
    or      v0, a2, t6
    movn    v0, v1, t0

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    movn    v1, t4, t0
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


/* ------------------------------ */
    .balign 128
.L_OP_USHR_LONG: /* 0xa5 */
/* File: mips/OP_USHR_LONG.S */
    /*
     * Long integer shift.  This is different from the generic 32/64-bit
     * binary operations because vAA/vBB are 64-bit but vCC (the shift
     * distance) is 32-bit.  Also, Dalvik requires us to mask off the low
     * 6 bits of the shift distance.
     */
    /* shl-long vAA, vBB, vCC */
    FETCH(a0, 1)                       /* a0<- CCBB */
    srl     s4, rINST, 8               /* s4<- AA */
    andi    s5, a0, 255                /* s5<- BB */
    srl     s6, a0, 8                  /* s6<- CC */
    sll     s5, s5, 2
    add     s5, rFP, s5                 /* s5<- &fp[BB] */
    GET_VREG(t7, s6)                    /* t7<- vCC */
    lw      a0, 0(s5)                   /* a0/a1<- vBB/vBB+1 */
    lw      a1, 4(s5)
    andi    t0, t7, 63                  /* t0<- t7 & 0x3f */
    sll     s4, s4, 2
    add     s4, rFP, s4                 /* s4<- &fp[AA] */

    nor     t2, zero, t0
    sll     t9, a0, 1
    sllv    a2, t9, t2
    srlv    t6, a1, t0
    andi    t1, t7, 0x20
    srlv    v1, a1, t0
    or      v0, a2, t6
    movn    v0, v1, t1

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    movn    v1, zero, t1
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


/* ------------------------------ */
    .balign 128
.L_OP_ADD_FLOAT: /* 0xa6 */
    /* stub for OP_ADD_FLOAT */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_ADD_FLOAT  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_SUB_FLOAT: /* 0xa7 */
    /* stub for OP_SUB_FLOAT */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_SUB_FLOAT  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_MUL_FLOAT: /* 0xa8 */
    /* stub for OP_MUL_FLOAT */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_MUL_FLOAT  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_DIV_FLOAT: /* 0xa9 */
    /* stub for OP_DIV_FLOAT */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_DIV_FLOAT  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_REM_FLOAT: /* 0xaa */
    /* stub for OP_REM_FLOAT */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_REM_FLOAT  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_ADD_DOUBLE: /* 0xab */
    /* stub for OP_ADD_DOUBLE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_ADD_DOUBLE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_SUB_DOUBLE: /* 0xac */
    /* stub for OP_SUB_DOUBLE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_SUB_DOUBLE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_MUL_DOUBLE: /* 0xad */
    /* stub for OP_MUL_DOUBLE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_MUL_DOUBLE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_DIV_DOUBLE: /* 0xae */
    /* stub for OP_DIV_DOUBLE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_DIV_DOUBLE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_REM_DOUBLE: /* 0xaf */
    /* stub for OP_REM_DOUBLE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_REM_DOUBLE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_ADD_INT_2ADDR: /* 0xb0 */
/* File: mips/OP_ADD_INT_2ADDR.S */
/* File: mips/binop2addr.S */
    /*
     * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (r1).  Useful for integer division and modulus.
     *
     * For: add-int/2addr, sub-int/2addr, mul-int/2addr, div-int/2addr,
     *      rem-int/2addr, and-int/2addr, or-int/2addr, xor-int/2addr,
     *      shl-int/2addr, shr-int/2addr, ushr-int/2addr, add-float/2addr,
     *      sub-float/2addr, mul-float/2addr, div-float/2addr, rem-float/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8                /* s4<- A+ */
    srl     s5, rINST, 12               /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(a0, s4)                    /* a0<- vA */
    GET_VREG(a1, s5)                    /* a1<- vB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

                               /* optional op */
    addu    v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_SUB_INT_2ADDR: /* 0xb1 */
/* File: mips/OP_SUB_INT_2ADDR.S */
/* File: mips/binop2addr.S */
    /*
     * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (r1).  Useful for integer division and modulus.
     *
     * For: add-int/2addr, sub-int/2addr, mul-int/2addr, div-int/2addr,
     *      rem-int/2addr, and-int/2addr, or-int/2addr, xor-int/2addr,
     *      shl-int/2addr, shr-int/2addr, ushr-int/2addr, add-float/2addr,
     *      sub-float/2addr, mul-float/2addr, div-float/2addr, rem-float/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8                /* s4<- A+ */
    srl     s5, rINST, 12               /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(a0, s4)                    /* a0<- vA */
    GET_VREG(a1, s5)                    /* a1<- vB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

                               /* optional op */
    subu    v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_MUL_INT_2ADDR: /* 0xb2 */
/* File: mips/OP_MUL_INT_2ADDR.S */
/* File: mips/binop2addr.S */
    /*
     * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (r1).  Useful for integer division and modulus.
     *
     * For: add-int/2addr, sub-int/2addr, mul-int/2addr, div-int/2addr,
     *      rem-int/2addr, and-int/2addr, or-int/2addr, xor-int/2addr,
     *      shl-int/2addr, shr-int/2addr, ushr-int/2addr, add-float/2addr,
     *      sub-float/2addr, mul-float/2addr, div-float/2addr, rem-float/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8                /* s4<- A+ */
    srl     s5, rINST, 12               /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(a0, s4)                    /* a0<- vA */
    GET_VREG(a1, s5)                    /* a1<- vB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

                               /* optional op */
    mul     v0, a1, a0                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_DIV_INT_2ADDR: /* 0xb3 */
/* File: mips/OP_DIV_INT_2ADDR.S */
/* File: mips/binop2addr.S */
    /*
     * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (r1).  Useful for integer division and modulus.
     *
     * For: add-int/2addr, sub-int/2addr, mul-int/2addr, div-int/2addr,
     *      rem-int/2addr, and-int/2addr, or-int/2addr, xor-int/2addr,
     *      shl-int/2addr, shr-int/2addr, ushr-int/2addr, add-float/2addr,
     *      sub-float/2addr, mul-float/2addr, div-float/2addr, rem-float/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8                /* s4<- A+ */
    srl     s5, rINST, 12               /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(a0, s4)                    /* a0<- vA */
    GET_VREG(a1, s5)                    /* a1<- vB */
    .if 1
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

    div    zero, a0, a1                           /* optional op */
    mflo    v0                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_REM_INT_2ADDR: /* 0xb4 */
/* File: mips/OP_REM_INT_2ADDR.S */
/* File: mips/binop2addr.S */
    /*
     * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (r1).  Useful for integer division and modulus.
     *
     * For: add-int/2addr, sub-int/2addr, mul-int/2addr, div-int/2addr,
     *      rem-int/2addr, and-int/2addr, or-int/2addr, xor-int/2addr,
     *      shl-int/2addr, shr-int/2addr, ushr-int/2addr, add-float/2addr,
     *      sub-float/2addr, mul-float/2addr, div-float/2addr, rem-float/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8                /* s4<- A+ */
    srl     s5, rINST, 12               /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(a0, s4)                    /* a0<- vA */
    GET_VREG(a1, s5)                    /* a1<- vB */
    .if 1
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

    div    zero, a0, a1                           /* optional op */
    mfhi    v0                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_AND_INT_2ADDR: /* 0xb5 */
/* File: mips/OP_AND_INT_2ADDR.S */
/* File: mips/binop2addr.S */
    /*
     * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (r1).  Useful for integer division and modulus.
     *
     * For: add-int/2addr, sub-int/2addr, mul-int/2addr, div-int/2addr,
     *      rem-int/2addr, and-int/2addr, or-int/2addr, xor-int/2addr,
     *      shl-int/2addr, shr-int/2addr, ushr-int/2addr, add-float/2addr,
     *      sub-float/2addr, mul-float/2addr, div-float/2addr, rem-float/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8                /* s4<- A+ */
    srl     s5, rINST, 12               /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(a0, s4)                    /* a0<- vA */
    GET_VREG(a1, s5)                    /* a1<- vB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

                               /* optional op */
    and     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_OR_INT_2ADDR: /* 0xb6 */
/* File: mips/OP_OR_INT_2ADDR.S */
/* File: mips/binop2addr.S */
    /*
     * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (r1).  Useful for integer division and modulus.
     *
     * For: add-int/2addr, sub-int/2addr, mul-int/2addr, div-int/2addr,
     *      rem-int/2addr, and-int/2addr, or-int/2addr, xor-int/2addr,
     *      shl-int/2addr, shr-int/2addr, ushr-int/2addr, add-float/2addr,
     *      sub-float/2addr, mul-float/2addr, div-float/2addr, rem-float/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8                /* s4<- A+ */
    srl     s5, rINST, 12               /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(a0, s4)                    /* a0<- vA */
    GET_VREG(a1, s5)                    /* a1<- vB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

                               /* optional op */
    or     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_XOR_INT_2ADDR: /* 0xb7 */
/* File: mips/OP_XOR_INT_2ADDR.S */
/* File: mips/binop2addr.S */
    /*
     * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (r1).  Useful for integer division and modulus.
     *
     * For: add-int/2addr, sub-int/2addr, mul-int/2addr, div-int/2addr,
     *      rem-int/2addr, and-int/2addr, or-int/2addr, xor-int/2addr,
     *      shl-int/2addr, shr-int/2addr, ushr-int/2addr, add-float/2addr,
     *      sub-float/2addr, mul-float/2addr, div-float/2addr, rem-float/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8                /* s4<- A+ */
    srl     s5, rINST, 12               /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(a0, s4)                    /* a0<- vA */
    GET_VREG(a1, s5)                    /* a1<- vB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

                               /* optional op */
    xor     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_SHL_INT_2ADDR: /* 0xb8 */
/* File: mips/OP_SHL_INT_2ADDR.S */
/* File: mips/binop2addr.S */
    /*
     * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (r1).  Useful for integer division and modulus.
     *
     * For: add-int/2addr, sub-int/2addr, mul-int/2addr, div-int/2addr,
     *      rem-int/2addr, and-int/2addr, or-int/2addr, xor-int/2addr,
     *      shl-int/2addr, shr-int/2addr, ushr-int/2addr, add-float/2addr,
     *      sub-float/2addr, mul-float/2addr, div-float/2addr, rem-float/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8                /* s4<- A+ */
    srl     s5, rINST, 12               /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(a0, s4)                    /* a0<- vA */
    GET_VREG(a1, s5)                    /* a1<- vB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

    andi    a1, a1, 31                           /* optional op */
    sllv     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_SHR_INT_2ADDR: /* 0xb9 */
/* File: mips/OP_SHR_INT_2ADDR.S */
/* File: mips/binop2addr.S */
    /*
     * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (r1).  Useful for integer division and modulus.
     *
     * For: add-int/2addr, sub-int/2addr, mul-int/2addr, div-int/2addr,
     *      rem-int/2addr, and-int/2addr, or-int/2addr, xor-int/2addr,
     *      shl-int/2addr, shr-int/2addr, ushr-int/2addr, add-float/2addr,
     *      sub-float/2addr, mul-float/2addr, div-float/2addr, rem-float/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8                /* s4<- A+ */
    srl     s5, rINST, 12               /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(a0, s4)                    /* a0<- vA */
    GET_VREG(a1, s5)                    /* a1<- vB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

    andi    a1, a1, 31                           /* optional op */
    srav     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_USHR_INT_2ADDR: /* 0xba */
/* File: mips/OP_USHR_INT_2ADDR.S */
/* File: mips/binop2addr.S */
    /*
     * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (r1).  Useful for integer division and modulus.
     *
     * For: add-int/2addr, sub-int/2addr, mul-int/2addr, div-int/2addr,
     *      rem-int/2addr, and-int/2addr, or-int/2addr, xor-int/2addr,
     *      shl-int/2addr, shr-int/2addr, ushr-int/2addr, add-float/2addr,
     *      sub-float/2addr, mul-float/2addr, div-float/2addr, rem-float/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8                /* s4<- A+ */
    srl     s5, rINST, 12               /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(a0, s4)                    /* a0<- vA */
    GET_VREG(a1, s5)                    /* a1<- vB */
    .if 0
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

    andi    a1, a1, 31                           /* optional op */
    srlv     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_ADD_LONG_2ADDR: /* 0xbb */
/* File: mips/OP_ADD_LONG_2ADDR.S */
/* File: mips/binopWide2addr.S */
    /*
     * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = r0-r1 op r2-r3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
     *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
     *      sub-double/2addr, mul-double/2addr, div-double/2addr,
     *      rem-double/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8               /* s4<- A+ */
    srl     s5, rINST, 12              /* s5<- B */
    andi    s4, s4, 15
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[B] */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a0, 0(s4)                   /* a0/a1<- vAA/vAA+1 */
    lw      a1, 4(s4)
    lw      a2, 0(s5)                   /* a2/a3<- vBB/vBB+1 */
    lw      a3, 4(s5)
    .if 0
    or      t7, a2, a3                  /* second arg (a2-a3) is zero? */
    beqz    t7, common_errDivideByZero
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

    addu    v0, a0, a2; sltu t7,v0,a0                             /* optional op */
    addu     t6, a1, a3; addu v1,t6,t7                             /* result<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)             /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)



/* ------------------------------ */
    .balign 128
.L_OP_SUB_LONG_2ADDR: /* 0xbc */
/* File: mips/OP_SUB_LONG_2ADDR.S */
/* File: mips/binopWide2addr.S */
    /*
     * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = r0-r1 op r2-r3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
     *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
     *      sub-double/2addr, mul-double/2addr, div-double/2addr,
     *      rem-double/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8               /* s4<- A+ */
    srl     s5, rINST, 12              /* s5<- B */
    andi    s4, s4, 15
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[B] */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a0, 0(s4)                   /* a0/a1<- vAA/vAA+1 */
    lw      a1, 4(s4)
    lw      a2, 0(s5)                   /* a2/a3<- vBB/vBB+1 */
    lw      a3, 4(s5)
    .if 0
    or      t7, a2, a3                  /* second arg (a2-a3) is zero? */
    beqz    t7, common_errDivideByZero
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

    subu    v0, a0, a2; sltu t7,a0,v0                             /* optional op */
    subu     t6, a1, a3; subu v1,t6,t7                             /* result<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)             /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)



/* ------------------------------ */
    .balign 128
.L_OP_MUL_LONG_2ADDR: /* 0xbd */
/* File: mips/OP_MUL_LONG_2ADDR.S */
    /*
     * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = r0-r1 op r2-r3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
     *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
     *      sub-double/2addr, mul-double/2addr, div-double/2addr,
     *      rem-double/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8               /* s4<- A+ */
    srl     s5, rINST, 12              /* s5<- B */
    andi    s4, s4, 15
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[B] */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a0, 0(s4)                   /* a0/a1<- vAA/vAA+1 */
    lw      a1, 4(s4)
    lw      a3, 4(s5)                   /* a2/a3<- vBB/vBB+1 */
    lw      a2, 0(s5)

    mul	    t3, a3, a0
    multu   a0, a2
    mflo    v0
    mfhi    t1
    mul     t2, a1, a2

    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    addu    v1, t2, t3
    addu    v1, v1, t1
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


/* ------------------------------ */
    .balign 128
.L_OP_DIV_LONG_2ADDR: /* 0xbe */
/* File: mips/OP_DIV_LONG_2ADDR.S */
    /*
     * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = r0-r1 op r2-r3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
     *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
     *      sub-double/2addr, mul-double/2addr, div-double/2addr,
     *      rem-double/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8               /* s4<- A+ */
    srl     s5, rINST, 12              /* s5<- B */
    andi    s4, s4, 15
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[B] */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a3, 4(s5)                   /* a2/a3<- vBB/vBB+1, divisor */
    lw      a2, 0(s5)
    lw      a0, 0(s4)                   /* a0/a1<- vAA/vAA+1, dividend */
    or      t1, a2, a3
    beqz    t1, common_errDivideByZero
    lw      a1, 4(s4)
    beqz    a0, testneg_OP_DIV_LONG_2ADDR
    lui     t4, 0x8000
divit_OP_DIV_LONG_2ADDR:
    LA(t9, __divdi3)
    jalr    t9
    nop

store_OP_DIV_LONG_2ADDR:
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)



/* ------------------------------ */
    .balign 128
.L_OP_REM_LONG_2ADDR: /* 0xbf */
/* File: mips/OP_REM_LONG_2ADDR.S */
    /*
     * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = r0-r1 op r2-r3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
     *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
     *      sub-double/2addr, mul-double/2addr, div-double/2addr,
     *      rem-double/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8               /* s4<- A+ */
    srl     s5, rINST, 12              /* s5<- B */
    andi    s4, s4, 15
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[B] */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a3, 4(s5)                   /* a2/a3<- vBB/vBB+1, divisor */
    lw      a2, 0(s5)
    lw      a0, 0(s4)                   /* a0/a1<- vAA/vAA+1, dividend */
    or      t1, a2, a3
    beqz    t1, common_errDivideByZero
    lw      a1, 4(s4)
    beqz    a0, testneg_OP_REM_LONG_2ADDR
    lui     t4, 0x8000
divit_OP_REM_LONG_2ADDR:
    LA(t9, __moddi3)
    jalr    t9
    nop

store_OP_REM_LONG_2ADDR:
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)



/* ------------------------------ */
    .balign 128
.L_OP_AND_LONG_2ADDR: /* 0xc0 */
/* File: mips/OP_AND_LONG_2ADDR.S */
/* File: mips/binopWide2addr.S */
    /*
     * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = r0-r1 op r2-r3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
     *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
     *      sub-double/2addr, mul-double/2addr, div-double/2addr,
     *      rem-double/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8               /* s4<- A+ */
    srl     s5, rINST, 12              /* s5<- B */
    andi    s4, s4, 15
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[B] */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a0, 0(s4)                   /* a0/a1<- vAA/vAA+1 */
    lw      a1, 4(s4)
    lw      a2, 0(s5)                   /* a2/a3<- vBB/vBB+1 */
    lw      a3, 4(s5)
    .if 0
    or      t7, a2, a3                  /* second arg (a2-a3) is zero? */
    beqz    t7, common_errDivideByZero
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

    and     v0, a0, a2                             /* optional op */
    and      v1, a1, a3                             /* result<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)             /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)



/* ------------------------------ */
    .balign 128
.L_OP_OR_LONG_2ADDR: /* 0xc1 */
/* File: mips/OP_OR_LONG_2ADDR.S */
/* File: mips/binopWide2addr.S */
    /*
     * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = r0-r1 op r2-r3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
     *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
     *      sub-double/2addr, mul-double/2addr, div-double/2addr,
     *      rem-double/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8               /* s4<- A+ */
    srl     s5, rINST, 12              /* s5<- B */
    andi    s4, s4, 15
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[B] */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a0, 0(s4)                   /* a0/a1<- vAA/vAA+1 */
    lw      a1, 4(s4)
    lw      a2, 0(s5)                   /* a2/a3<- vBB/vBB+1 */
    lw      a3, 4(s5)
    .if 0
    or      t7, a2, a3                  /* second arg (a2-a3) is zero? */
    beqz    t7, common_errDivideByZero
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

    or     v0, a0, a2                             /* optional op */
    or      v1, a1, a3                             /* result<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)             /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)



/* ------------------------------ */
    .balign 128
.L_OP_XOR_LONG_2ADDR: /* 0xc2 */
/* File: mips/OP_XOR_LONG_2ADDR.S */
/* File: mips/binopWide2addr.S */
    /*
     * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = r0-r1 op r2-r3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
     *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
     *      sub-double/2addr, mul-double/2addr, div-double/2addr,
     *      rem-double/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8               /* s4<- A+ */
    srl     s5, rINST, 12              /* s5<- B */
    andi    s4, s4, 15
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[B] */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a0, 0(s4)                   /* a0/a1<- vAA/vAA+1 */
    lw      a1, 4(s4)
    lw      a2, 0(s5)                   /* a2/a3<- vBB/vBB+1 */
    lw      a3, 4(s5)
    .if 0
    or      t7, a2, a3                  /* second arg (a2-a3) is zero? */
    beqz    t7, common_errDivideByZero
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

    xor     v0, a0, a2                             /* optional op */
    xor      v1, a1, a3                             /* result<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)             /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)



/* ------------------------------ */
    .balign 128
.L_OP_SHL_LONG_2ADDR: /* 0xc3 */
/* File: mips/OP_SHL_LONG_2ADDR.S */
    /*
     * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = r0-r1 op r2-r3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
     *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
     *      sub-double/2addr, mul-double/2addr, div-double/2addr,
     *      rem-double/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8               /* s4<- A+ */
    srl     s5, rINST, 12              /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(t7, s5)                    /* t7<- vB */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a0, 0(s4)                   /* a0/a1<- vAA/vAA+1 */
    lw      a1, 4(s4)

    andi    t0, t7, 63                  /* t0<- t7 & 0x3f */
    nor     t2, zero, t0
    srl     t9, a0, 1
    srlv    a2, t9, t2
    sllv    t6, a1, t0
    andi    t1, t7, 0x20
    sllv    v0, a0, t0
    or      v1, a2, t6
    movn    v1, v0, t1

    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    movn    v0, zero, t1
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


/* ------------------------------ */
    .balign 128
.L_OP_SHR_LONG_2ADDR: /* 0xc4 */
/* File: mips/OP_SHR_LONG_2ADDR.S */
    /*
     * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = r0-r1 op r2-r3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
     *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
     *      sub-double/2addr, mul-double/2addr, div-double/2addr,
     *      rem-double/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8               /* s4<- A+ */
    srl     s5, rINST, 12              /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(t7, s5)                    /* t7<- vB */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a0, 0(s4)                   /* a0/a1<- vAA/vAA+1 */
    lw      a1, 4(s4)

    andi    t1, t7, 63                  /* t0<- t7 & 0x3f */
    sll     t2, a1, 1
    nor     v0, zero, t1
    sllv    a2, t2, v0
    srlv    t6, a0, t1
    andi    t0, t7, 0x20
    srav    v1, a1, t1
    sra     t4, a1, 31
    or      v0, a2, t6
    movn    v0, v1, t0


    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    movn    v1, t4, t0
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


/* ------------------------------ */
    .balign 128
.L_OP_USHR_LONG_2ADDR: /* 0xc5 */
/* File: mips/OP_USHR_LONG_2ADDR.S */
    /*
     * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = r0-r1 op r2-r3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
     *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
     *      sub-double/2addr, mul-double/2addr, div-double/2addr,
     *      rem-double/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8               /* s4<- A+ */
    srl     s5, rINST, 12              /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(t7, s5)                    /* t7<- vB */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a0, 0(s4)                   /* a0/a1<- vAA/vAA+1 */
    lw      a1, 4(s4)

    andi    t0, t7, 63                  /* t0<- t7 & 0x3f */
    nor     t2, zero, t0
    sll     t9, a0, 1
    sllv    a2, t9, t2
    srlv    t6, a1, t0
    andi    t1, t7, 0x20
    srlv    v1, a1, t0
    or      v0, a2, t6
    movn    v0, v1, t1

    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    movn    v1, zero, t1
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


/* ------------------------------ */
    .balign 128
.L_OP_ADD_FLOAT_2ADDR: /* 0xc6 */
    /* stub for OP_ADD_FLOAT_2ADDR */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_ADD_FLOAT_2ADDR  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_SUB_FLOAT_2ADDR: /* 0xc7 */
    /* stub for OP_SUB_FLOAT_2ADDR */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_SUB_FLOAT_2ADDR  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_MUL_FLOAT_2ADDR: /* 0xc8 */
    /* stub for OP_MUL_FLOAT_2ADDR */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_MUL_FLOAT_2ADDR  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_DIV_FLOAT_2ADDR: /* 0xc9 */
    /* stub for OP_DIV_FLOAT_2ADDR */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_DIV_FLOAT_2ADDR  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_REM_FLOAT_2ADDR: /* 0xca */
    /* stub for OP_REM_FLOAT_2ADDR */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_REM_FLOAT_2ADDR  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_ADD_DOUBLE_2ADDR: /* 0xcb */
    /* stub for OP_ADD_DOUBLE_2ADDR */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_ADD_DOUBLE_2ADDR  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_SUB_DOUBLE_2ADDR: /* 0xcc */
    /* stub for OP_SUB_DOUBLE_2ADDR */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_SUB_DOUBLE_2ADDR  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_MUL_DOUBLE_2ADDR: /* 0xcd */
    /* stub for OP_MUL_DOUBLE_2ADDR */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_MUL_DOUBLE_2ADDR  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_DIV_DOUBLE_2ADDR: /* 0xce */
    /* stub for OP_DIV_DOUBLE_2ADDR */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_DIV_DOUBLE_2ADDR  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_REM_DOUBLE_2ADDR: /* 0xcf */
    /* stub for OP_REM_DOUBLE_2ADDR */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_REM_DOUBLE_2ADDR  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_ADD_INT_LIT16: /* 0xd0 */
/* File: mips/OP_ADD_INT_LIT16.S */
/* File: mips/binopLit16.S */
    /*
     * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit16, rsub-int, mul-int/lit16, div-int/lit16,
     *      rem-int/lit16, and-int/lit16, or-int/lit16, xor-int/lit16
     */
    /* binop/lit16 vA, vB, #+CCCC */
    FETCH_S(a1, 1)                      /* a1<- ssssCCCC (sign-extended) */
    srl     a2, rINST, 12               /* a2<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a2)                    /* a0<- vB */
    andi    s4, s4, 15
    .if 0
    beqz    a1, common_errDivideByZero   /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    addu    v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_RSUB_INT: /* 0xd1 */
/* File: mips/OP_RSUB_INT.S */
/* this op is "rsub-int", but can be thought of as "rsub-int/lit16" */
/* File: mips/binopLit16.S */
    /*
     * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit16, rsub-int, mul-int/lit16, div-int/lit16,
     *      rem-int/lit16, and-int/lit16, or-int/lit16, xor-int/lit16
     */
    /* binop/lit16 vA, vB, #+CCCC */
    FETCH_S(a1, 1)                      /* a1<- ssssCCCC (sign-extended) */
    srl     a2, rINST, 12               /* a2<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a2)                    /* a0<- vB */
    andi    s4, s4, 15
    .if 0
    beqz    a1, common_errDivideByZero   /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    subu     v0, a1, a0                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_MUL_INT_LIT16: /* 0xd2 */
/* File: mips/OP_MUL_INT_LIT16.S */
/* File: mips/binopLit16.S */
    /*
     * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit16, rsub-int, mul-int/lit16, div-int/lit16,
     *      rem-int/lit16, and-int/lit16, or-int/lit16, xor-int/lit16
     */
    /* binop/lit16 vA, vB, #+CCCC */
    FETCH_S(a1, 1)                      /* a1<- ssssCCCC (sign-extended) */
    srl     a2, rINST, 12               /* a2<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a2)                    /* a0<- vB */
    andi    s4, s4, 15
    .if 0
    beqz    a1, common_errDivideByZero   /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    mul     v0, a1, a0                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_DIV_INT_LIT16: /* 0xd3 */
/* File: mips/OP_DIV_INT_LIT16.S */
/* File: mips/binopLit16.S */
    /*
     * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit16, rsub-int, mul-int/lit16, div-int/lit16,
     *      rem-int/lit16, and-int/lit16, or-int/lit16, xor-int/lit16
     */
    /* binop/lit16 vA, vB, #+CCCC */
    FETCH_S(a1, 1)                      /* a1<- ssssCCCC (sign-extended) */
    srl     a2, rINST, 12               /* a2<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a2)                    /* a0<- vB */
    andi    s4, s4, 15
    .if 1
    beqz    a1, common_errDivideByZero   /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    mflo    v0                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_REM_INT_LIT16: /* 0xd4 */
/* File: mips/OP_REM_INT_LIT16.S */
/* File: mips/binopLit16.S */
    /*
     * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit16, rsub-int, mul-int/lit16, div-int/lit16,
     *      rem-int/lit16, and-int/lit16, or-int/lit16, xor-int/lit16
     */
    /* binop/lit16 vA, vB, #+CCCC */
    FETCH_S(a1, 1)                      /* a1<- ssssCCCC (sign-extended) */
    srl     a2, rINST, 12               /* a2<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a2)                    /* a0<- vB */
    andi    s4, s4, 15
    .if 1
    beqz    a1, common_errDivideByZero   /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    mfhi    v0                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_AND_INT_LIT16: /* 0xd5 */
/* File: mips/OP_AND_INT_LIT16.S */
/* File: mips/binopLit16.S */
    /*
     * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit16, rsub-int, mul-int/lit16, div-int/lit16,
     *      rem-int/lit16, and-int/lit16, or-int/lit16, xor-int/lit16
     */
    /* binop/lit16 vA, vB, #+CCCC */
    FETCH_S(a1, 1)                      /* a1<- ssssCCCC (sign-extended) */
    srl     a2, rINST, 12               /* a2<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a2)                    /* a0<- vB */
    andi    s4, s4, 15
    .if 0
    beqz    a1, common_errDivideByZero   /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    and     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_OR_INT_LIT16: /* 0xd6 */
/* File: mips/OP_OR_INT_LIT16.S */
/* File: mips/binopLit16.S */
    /*
     * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit16, rsub-int, mul-int/lit16, div-int/lit16,
     *      rem-int/lit16, and-int/lit16, or-int/lit16, xor-int/lit16
     */
    /* binop/lit16 vA, vB, #+CCCC */
    FETCH_S(a1, 1)                      /* a1<- ssssCCCC (sign-extended) */
    srl     a2, rINST, 12               /* a2<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a2)                    /* a0<- vB */
    andi    s4, s4, 15
    .if 0
    beqz    a1, common_errDivideByZero   /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    or     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_XOR_INT_LIT16: /* 0xd7 */
/* File: mips/OP_XOR_INT_LIT16.S */
/* File: mips/binopLit16.S */
    /*
     * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit16, rsub-int, mul-int/lit16, div-int/lit16,
     *      rem-int/lit16, and-int/lit16, or-int/lit16, xor-int/lit16
     */
    /* binop/lit16 vA, vB, #+CCCC */
    FETCH_S(a1, 1)                      /* a1<- ssssCCCC (sign-extended) */
    srl     a2, rINST, 12               /* a2<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a2)                    /* a0<- vB */
    andi    s4, s4, 15
    .if 0
    beqz    a1, common_errDivideByZero   /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    xor     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_ADD_INT_LIT8: /* 0xd8 */
/* File: mips/OP_ADD_INT_LIT8.S */
/* File: mips/binopLit8.S */
    /*
     * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, div-int/lit8,
     *      rem-int/lit8, and-int/lit8, or-int/lit8, xor-int/lit8,
     *      shl-int/lit8, shr-int/lit8, ushr-int/lit8
     */
    /* binop/lit8 vAA, vBB, #+CC */
    FETCH_S(a3, 1)                    /* a3<- ssssCCBB (sign-extended for CC) */
    srl     s4, rINST, 8              /* s4<- AA */
    andi    a2, a3, 255               /* a2<- BB */
    GET_VREG(a0, a2)                  /* a0<- vBB */
    sra     a1, a3, 8                 /* a1<- ssssssCC (sign extended) */
    .if 0
    beqz     a1, common_errDivideByZero /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

                               /* optional op */
    addu    v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_RSUB_INT_LIT8: /* 0xd9 */
/* File: mips/OP_RSUB_INT_LIT8.S */
/* File: mips/binopLit8.S */
    /*
     * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, div-int/lit8,
     *      rem-int/lit8, and-int/lit8, or-int/lit8, xor-int/lit8,
     *      shl-int/lit8, shr-int/lit8, ushr-int/lit8
     */
    /* binop/lit8 vAA, vBB, #+CC */
    FETCH_S(a3, 1)                    /* a3<- ssssCCBB (sign-extended for CC) */
    srl     s4, rINST, 8              /* s4<- AA */
    andi    a2, a3, 255               /* a2<- BB */
    GET_VREG(a0, a2)                  /* a0<- vBB */
    sra     a1, a3, 8                 /* a1<- ssssssCC (sign extended) */
    .if 0
    beqz     a1, common_errDivideByZero /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

                               /* optional op */
    subu     v0, a1, a0                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_MUL_INT_LIT8: /* 0xda */
/* File: mips/OP_MUL_INT_LIT8.S */
/* File: mips/binopLit8.S */
    /*
     * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, div-int/lit8,
     *      rem-int/lit8, and-int/lit8, or-int/lit8, xor-int/lit8,
     *      shl-int/lit8, shr-int/lit8, ushr-int/lit8
     */
    /* binop/lit8 vAA, vBB, #+CC */
    FETCH_S(a3, 1)                    /* a3<- ssssCCBB (sign-extended for CC) */
    srl     s4, rINST, 8              /* s4<- AA */
    andi    a2, a3, 255               /* a2<- BB */
    GET_VREG(a0, a2)                  /* a0<- vBB */
    sra     a1, a3, 8                 /* a1<- ssssssCC (sign extended) */
    .if 0
    beqz     a1, common_errDivideByZero /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

                               /* optional op */
    mul     v0, a1, a0                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_DIV_INT_LIT8: /* 0xdb */
/* File: mips/OP_DIV_INT_LIT8.S */
/* File: mips/binopLit8.S */
    /*
     * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, div-int/lit8,
     *      rem-int/lit8, and-int/lit8, or-int/lit8, xor-int/lit8,
     *      shl-int/lit8, shr-int/lit8, ushr-int/lit8
     */
    /* binop/lit8 vAA, vBB, #+CC */
    FETCH_S(a3, 1)                    /* a3<- ssssCCBB (sign-extended for CC) */
    srl     s4, rINST, 8              /* s4<- AA */
    andi    a2, a3, 255               /* a2<- BB */
    GET_VREG(a0, a2)                  /* a0<- vBB */
    sra     a1, a3, 8                 /* a1<- ssssssCC (sign extended) */
    .if 1
    beqz     a1, common_errDivideByZero /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    div    zero, a0, a1                           /* optional op */
    mflo    v0                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_REM_INT_LIT8: /* 0xdc */
/* File: mips/OP_REM_INT_LIT8.S */
/* File: mips/binopLit8.S */
    /*
     * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, div-int/lit8,
     *      rem-int/lit8, and-int/lit8, or-int/lit8, xor-int/lit8,
     *      shl-int/lit8, shr-int/lit8, ushr-int/lit8
     */
    /* binop/lit8 vAA, vBB, #+CC */
    FETCH_S(a3, 1)                    /* a3<- ssssCCBB (sign-extended for CC) */
    srl     s4, rINST, 8              /* s4<- AA */
    andi    a2, a3, 255               /* a2<- BB */
    GET_VREG(a0, a2)                  /* a0<- vBB */
    sra     a1, a3, 8                 /* a1<- ssssssCC (sign extended) */
    .if 1
    beqz     a1, common_errDivideByZero /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    div    zero, a0, a1                           /* optional op */
    mfhi    v0                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_AND_INT_LIT8: /* 0xdd */
/* File: mips/OP_AND_INT_LIT8.S */
/* File: mips/binopLit8.S */
    /*
     * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, div-int/lit8,
     *      rem-int/lit8, and-int/lit8, or-int/lit8, xor-int/lit8,
     *      shl-int/lit8, shr-int/lit8, ushr-int/lit8
     */
    /* binop/lit8 vAA, vBB, #+CC */
    FETCH_S(a3, 1)                    /* a3<- ssssCCBB (sign-extended for CC) */
    srl     s4, rINST, 8              /* s4<- AA */
    andi    a2, a3, 255               /* a2<- BB */
    GET_VREG(a0, a2)                  /* a0<- vBB */
    sra     a1, a3, 8                 /* a1<- ssssssCC (sign extended) */
    .if 0
    beqz     a1, common_errDivideByZero /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

                               /* optional op */
    and     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_OR_INT_LIT8: /* 0xde */
/* File: mips/OP_OR_INT_LIT8.S */
/* File: mips/binopLit8.S */
    /*
     * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, div-int/lit8,
     *      rem-int/lit8, and-int/lit8, or-int/lit8, xor-int/lit8,
     *      shl-int/lit8, shr-int/lit8, ushr-int/lit8
     */
    /* binop/lit8 vAA, vBB, #+CC */
    FETCH_S(a3, 1)                    /* a3<- ssssCCBB (sign-extended for CC) */
    srl     s4, rINST, 8              /* s4<- AA */
    andi    a2, a3, 255               /* a2<- BB */
    GET_VREG(a0, a2)                  /* a0<- vBB */
    sra     a1, a3, 8                 /* a1<- ssssssCC (sign extended) */
    .if 0
    beqz     a1, common_errDivideByZero /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

                               /* optional op */
    or     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_XOR_INT_LIT8: /* 0xdf */
/* File: mips/OP_XOR_INT_LIT8.S */
/* File: mips/binopLit8.S */
    /*
     * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, div-int/lit8,
     *      rem-int/lit8, and-int/lit8, or-int/lit8, xor-int/lit8,
     *      shl-int/lit8, shr-int/lit8, ushr-int/lit8
     */
    /* binop/lit8 vAA, vBB, #+CC */
    FETCH_S(a3, 1)                    /* a3<- ssssCCBB (sign-extended for CC) */
    srl     s4, rINST, 8              /* s4<- AA */
    andi    a2, a3, 255               /* a2<- BB */
    GET_VREG(a0, a2)                  /* a0<- vBB */
    sra     a1, a3, 8                 /* a1<- ssssssCC (sign extended) */
    .if 0
    beqz     a1, common_errDivideByZero /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

                               /* optional op */
    xor     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_SHL_INT_LIT8: /* 0xe0 */
/* File: mips/OP_SHL_INT_LIT8.S */
/* File: mips/binopLit8.S */
    /*
     * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, div-int/lit8,
     *      rem-int/lit8, and-int/lit8, or-int/lit8, xor-int/lit8,
     *      shl-int/lit8, shr-int/lit8, ushr-int/lit8
     */
    /* binop/lit8 vAA, vBB, #+CC */
    FETCH_S(a3, 1)                    /* a3<- ssssCCBB (sign-extended for CC) */
    srl     s4, rINST, 8              /* s4<- AA */
    andi    a2, a3, 255               /* a2<- BB */
    GET_VREG(a0, a2)                  /* a0<- vBB */
    sra     a1, a3, 8                 /* a1<- ssssssCC (sign extended) */
    .if 0
    beqz     a1, common_errDivideByZero /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    andi    a1, a1, 31                           /* optional op */
    sllv     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_SHR_INT_LIT8: /* 0xe1 */
/* File: mips/OP_SHR_INT_LIT8.S */
/* File: mips/binopLit8.S */
    /*
     * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, div-int/lit8,
     *      rem-int/lit8, and-int/lit8, or-int/lit8, xor-int/lit8,
     *      shl-int/lit8, shr-int/lit8, ushr-int/lit8
     */
    /* binop/lit8 vAA, vBB, #+CC */
    FETCH_S(a3, 1)                    /* a3<- ssssCCBB (sign-extended for CC) */
    srl     s4, rINST, 8              /* s4<- AA */
    andi    a2, a3, 255               /* a2<- BB */
    GET_VREG(a0, a2)                  /* a0<- vBB */
    sra     a1, a3, 8                 /* a1<- ssssssCC (sign extended) */
    .if 0
    beqz     a1, common_errDivideByZero /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    andi    a1, a1, 31                           /* optional op */
    srav     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_USHR_INT_LIT8: /* 0xe2 */
/* File: mips/OP_USHR_INT_LIT8.S */
/* File: mips/binopLit8.S */
    /*
     * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, div-int/lit8,
     *      rem-int/lit8, and-int/lit8, or-int/lit8, xor-int/lit8,
     *      shl-int/lit8, shr-int/lit8, ushr-int/lit8
     */
    /* binop/lit8 vAA, vBB, #+CC */
    FETCH_S(a3, 1)                    /* a3<- ssssCCBB (sign-extended for CC) */
    srl     s4, rINST, 8              /* s4<- AA */
    andi    a2, a3, 255               /* a2<- BB */
    GET_VREG(a0, a2)                  /* a0<- vBB */
    sra     a1, a3, 8                 /* a1<- ssssssCC (sign extended) */
    .if 0
    beqz     a1, common_errDivideByZero /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    andi    a1, a1, 31                           /* optional op */
    srlv     v0, a0, a1                              /* v0<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)               /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_E3: /* 0xe3 */
/* File: mips/OP_UNUSED_E3.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_E4: /* 0xe4 */
/* File: mips/OP_UNUSED_E4.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_E5: /* 0xe5 */
/* File: mips/OP_UNUSED_E5.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_E6: /* 0xe6 */
/* File: mips/OP_UNUSED_E6.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_E7: /* 0xe7 */
/* File: mips/OP_UNUSED_E7.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_E8: /* 0xe8 */
/* File: mips/OP_UNUSED_E8.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_E9: /* 0xe9 */
/* File: mips/OP_UNUSED_E9.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_EA: /* 0xea */
/* File: mips/OP_UNUSED_EA.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_EB: /* 0xeb */
/* File: mips/OP_UNUSED_EB.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_EC: /* 0xec */
/* File: mips/OP_UNUSED_EC.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_ED: /* 0xed */
/* File: mips/OP_UNUSED_ED.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_EXECUTE_INLINE: /* 0xee */
    /* stub for OP_EXECUTE_INLINE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_EXECUTE_INLINE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_EF: /* 0xef */
/* File: mips/OP_UNUSED_EF.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_DIRECT_EMPTY: /* 0xf0 */
    /* stub for OP_INVOKE_DIRECT_EMPTY */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_INVOKE_DIRECT_EMPTY  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_F1: /* 0xf1 */
/* File: mips/OP_UNUSED_F1.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_IGET_QUICK: /* 0xf2 */
    /* stub for OP_IGET_QUICK */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_IGET_QUICK  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_IGET_WIDE_QUICK: /* 0xf3 */
    /* stub for OP_IGET_WIDE_QUICK */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_IGET_WIDE_QUICK  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_IGET_OBJECT_QUICK: /* 0xf4 */
    /* stub for OP_IGET_OBJECT_QUICK */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_IGET_OBJECT_QUICK  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_IPUT_QUICK: /* 0xf5 */
    /* stub for OP_IPUT_QUICK */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_IPUT_QUICK  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_IPUT_WIDE_QUICK: /* 0xf6 */
    /* stub for OP_IPUT_WIDE_QUICK */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_IPUT_WIDE_QUICK  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_IPUT_OBJECT_QUICK: /* 0xf7 */
    /* stub for OP_IPUT_OBJECT_QUICK */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_IPUT_OBJECT_QUICK  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_VIRTUAL_QUICK: /* 0xf8 */
    /* stub for OP_INVOKE_VIRTUAL_QUICK */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_INVOKE_VIRTUAL_QUICK  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_VIRTUAL_QUICK_RANGE: /* 0xf9 */
    /* stub for OP_INVOKE_VIRTUAL_QUICK_RANGE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_INVOKE_VIRTUAL_QUICK_RANGE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_SUPER_QUICK: /* 0xfa */
    /* stub for OP_INVOKE_SUPER_QUICK */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_INVOKE_SUPER_QUICK  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_INVOKE_SUPER_QUICK_RANGE: /* 0xfb */
    /* stub for OP_INVOKE_SUPER_QUICK_RANGE */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_OP_INVOKE_SUPER_QUICK_RANGE  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */
/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_FC: /* 0xfc */
/* File: mips/OP_UNUSED_FC.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_FD: /* 0xfd */
/* File: mips/OP_UNUSED_FD.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_FE: /* 0xfe */
/* File: mips/OP_UNUSED_FE.S */
/* File: mips/unused.S */
    b     common_abort
    nop



/* ------------------------------ */
    .balign 128
.L_OP_UNUSED_FF: /* 0xff */
/* File: mips/OP_UNUSED_FF.S */
/* File: mips/unused.S */
    b     common_abort
    nop




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
    .text
    .balign 4
dvmAsmSisterStart:

/* continuation for OP_CHECK_CAST */

    /*
     * Trivial test failed, need to perform full check.  This is common.
     *  a0 holds obj->clazz
     *  a1 holds class resolved from BBBB
     *  s4 holds object
     */
.LOP_CHECK_CAST_fullcheck:
    LA(t9,dvmInstanceofNonTrivial)          /* v0<- boolean result */
    jalr    t9
    nop
    bnez    v0, .LOP_CHECK_CAST_okay            /* non-zero (true), success */
    nop

    /* A cast has failed.  We need to throw a ClassCastException with the
     * class of the object that failed to be cast.
     */
    EXPORT_PC()                         /* about to throw */
    lw      a3, offObject_clazz(s4)     /* a3<- obj->clazz */
    move    gp, s8
    la      a0, .strClassCastException
    la      t9, dvmThrowExceptionWithClassMessage
    jalr    t9
    lw      a1, offClassObject_descriptor(a3) /* r1<- obj->clazz->descriptor */
    b       common_exceptionThrown
    nop

    /*
     * Resolution required.  This is the least-likely path.
     *
     *  a2 holds BBBB
     *  s4 holds object
     */
.LOP_CHECK_CAST_resolve:
    EXPORT_PC()                         /* resolve() could throw */
    lw      a3, offGlue_method(rGLUE)   /* a3<- glue->method */
    move    a1, a2                      /* a1<- BBBB */
    LA(t9,dvmResolveClass)              /* v0<- resolved ClassObject ptr */
    move    a2, zero                    /* a2<- false */
    jalr    t9
    lw      a0, offMethod_clazz(a3)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* yes, handle exception */
    lw      a0, offObject_clazz(s4)     /* a0<- obj->clazz */
    b       .LOP_CHECK_CAST_resolved        /* pick up where we left off */
    move    a1, v0                      /* a1<- class resolved from BBBB */



/* continuation for OP_INSTANCE_OF */

    /*
     * Resolution required.  This is the least-likely path.
     *
     *  a3 holds CCCC
     *  s4 holds A
     */
.LOP_INSTANCE_OF_resolve:
    EXPORT_PC()                         /* resolve() could throw */
    lw      a0, offGlue_method(rGLUE)   /* a0<- glue->method */
    move    a1, a3                      /* a1<- BBBB */
    li      a2, 1                       /* a2<- true */
    LA(t9,dvmResolveClass)              /* v0<- resolved ClassObject ptr */
    jalr    t9
    lw      a0, offMethod_clazz(a0)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null returned, handle exception */
    srl     a3, rINST, 12               /* a3<- B */
    GET_VREG(a0, a3)                    /* a0<- vB (object) */
    move    a1, v0                      /* a1<- class resolved from BBB */
    b       .LOP_INSTANCE_OF_resolved        /* pick up where we left off */
    lw      a0, offObject_clazz(a0)     /* a0<- obj->clazz */


/* continuation for OP_CMPL_FLOAT */

.LOP_CMPL_FLOAT_finish:
    srl     s4, rINST, 8                /* s4<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* continuation for OP_IGET */

.LOP_IGET_finish:
    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    beqz    s4, common_errNullObject        /* bail if object was null */
    addu    t5, s4, a3
    lw   a0, 0(t5)                   /* a0<- obj.field (8/16/32 bits) */
    srl     a2, rINST, 8                /* a2<- A+ */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    andi    a2, a2, 15                  /* a2<- A */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a0, a2)                    /* fp[A]<- a0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* continuation for OP_IGET_WIDE */

.LOP_IGET_WIDE_finish:
    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    beqz    s4, common_errNullObject        /* bail if object was null */
    addu    t5, s4, a3
    lw      a0, 0(t5)                   /* a0/a1<- obj.field (64 bits) */
    lw      a1, 4(t5)
    srl     a2, rINST, 6                /* a2<- A+ */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    andi    a2, a2, 0x3c                /* a2<- A*4 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    addu    t6, rFP, a2			/* t6<- &fp[A] */
    SET_VREG(a0, a2)                    /* fp[A]<- a0 */
    sw      a0, 0(t6)
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, 4(t6)


/* continuation for OP_IGET_OBJECT */

.LOP_IGET_OBJECT_finish:
    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    beqz    s4, common_errNullObject        /* bail if object was null */
    addu    t5, s4, a3
    lw   a0, 0(t5)                   /* a0<- obj.field (8/16/32 bits) */
    srl     a2, rINST, 8                /* a2<- A+ */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    andi    a2, a2, 15                  /* a2<- A */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a0, a2)                    /* fp[A]<- a0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* continuation for OP_IGET_BOOLEAN */

.LOP_IGET_BOOLEAN_finish:
    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    beqz    s4, common_errNullObject        /* bail if object was null */
    addu    t5, s4, a3
    lw   a0, 0(t5)                   /* a0<- obj.field (8/16/32 bits) */
    srl     a2, rINST, 8                /* a2<- A+ */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    andi    a2, a2, 15                  /* a2<- A */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a0, a2)                    /* fp[A]<- a0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* continuation for OP_IGET_BYTE */

.LOP_IGET_BYTE_finish:
    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    beqz    s4, common_errNullObject        /* bail if object was null */
    addu    t5, s4, a3
    lw   a0, 0(t5)                   /* a0<- obj.field (8/16/32 bits) */
    srl     a2, rINST, 8                /* a2<- A+ */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    andi    a2, a2, 15                  /* a2<- A */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a0, a2)                    /* fp[A]<- a0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* continuation for OP_IGET_CHAR */

.LOP_IGET_CHAR_finish:
    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    beqz    s4, common_errNullObject        /* bail if object was null */
    addu    t5, s4, a3
    lw   a0, 0(t5)                   /* a0<- obj.field (8/16/32 bits) */
    srl     a2, rINST, 8                /* a2<- A+ */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    andi    a2, a2, 15                  /* a2<- A */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a0, a2)                    /* fp[A]<- a0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* continuation for OP_IGET_SHORT */

.LOP_IGET_SHORT_finish:
    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    beqz    s4, common_errNullObject        /* bail if object was null */
    addu    t5, s4, a3
    lw   a0, 0(t5)                   /* a0<- obj.field (8/16/32 bits) */
    srl     a2, rINST, 8                /* a2<- A+ */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    andi    a2, a2, 15                  /* a2<- A */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a0, a2)                    /* fp[A]<- a0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/* continuation for OP_IPUT */

    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
.LOP_IPUT_finish:
    srl     a1, rINST, 8                /* aa<- A+ */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    andi    a1, a1, 15                  /* a1<- A */
    beqz    s4, common_errNullObject    /* bail if object was null */
    GET_VREG(a0, a1)                    /* a0<- fp[A] */
    addu    t5, s4, a3
    sw  a0, 0(t5)                   /* a0<- obj.field (8/16/32 bits) */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */

/* continuation for OP_IPUT_WIDE */

    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
.LOP_IPUT_WIDE_finish:
    srl     a2, rINST, 6                /* a2<- A+ */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    andi    a2, a2, 0x3c                /* a2<- A*4 */
    addu    a2, rFP, a2			/* a2<- &fp[A] */
    beqz    s4, common_errNullObject    /* bail if object was null */
    addu    t5, s4, a3
    lw      a0, 0(a2)			/* a0/a1<- fp[A] */
    lw      a1, 4(a2)
    sw      a0, 0(t5)                   /* t5<- obj.field (64 bits) */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                     /* jump to next instruction */
    sw      a1, 4(t5)

/* continuation for OP_IPUT_OBJECT */

    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
.LOP_IPUT_OBJECT_finish:
    srl     a1, rINST, 8                /* aa<- A+ */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    andi    a1, a1, 15                  /* a1<- A */
    beqz    s4, common_errNullObject    /* bail if object was null */
    GET_VREG(a0, a1)                    /* a0<- fp[A] */
    addu    t5, s4, a3
    sw  a0, 0(t5)                   /* a0<- obj.field (8/16/32 bits) */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */

/* continuation for OP_IPUT_BOOLEAN */

    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
.LOP_IPUT_BOOLEAN_finish:
    srl     a1, rINST, 8                /* aa<- A+ */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    andi    a1, a1, 15                  /* a1<- A */
    beqz    s4, common_errNullObject    /* bail if object was null */
    GET_VREG(a0, a1)                    /* a0<- fp[A] */
    addu    t5, s4, a3
    sw  a0, 0(t5)                   /* a0<- obj.field (8/16/32 bits) */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */

/* continuation for OP_IPUT_BYTE */

    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
.LOP_IPUT_BYTE_finish:
    srl     a1, rINST, 8                /* aa<- A+ */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    andi    a1, a1, 15                  /* a1<- A */
    beqz    s4, common_errNullObject    /* bail if object was null */
    GET_VREG(a0, a1)                    /* a0<- fp[A] */
    addu    t5, s4, a3
    sw  a0, 0(t5)                   /* a0<- obj.field (8/16/32 bits) */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */

/* continuation for OP_IPUT_CHAR */

    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
.LOP_IPUT_CHAR_finish:
    srl     a1, rINST, 8                /* aa<- A+ */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    andi    a1, a1, 15                  /* a1<- A */
    beqz    s4, common_errNullObject    /* bail if object was null */
    GET_VREG(a0, a1)                    /* a0<- fp[A] */
    addu    t5, s4, a3
    sw  a0, 0(t5)                   /* a0<- obj.field (8/16/32 bits) */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */

/* continuation for OP_IPUT_SHORT */

    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
.LOP_IPUT_SHORT_finish:
    srl     a1, rINST, 8                /* aa<- A+ */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    andi    a1, a1, 15                  /* a1<- A */
    beqz    s4, common_errNullObject    /* bail if object was null */
    GET_VREG(a0, a1)                    /* a0<- fp[A] */
    addu    t5, s4, a3
    sw  a0, 0(t5)                   /* a0<- obj.field (8/16/32 bits) */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */

/* continuation for OP_SGET_WIDE */

    /*
     * Continuation if the field has not yet been resolved.
     *  r1: BBBB field ref
     */
.LOP_SGET_WIDE_resolve:


/* continuation for OP_DIV_LONG */

testneg_OP_DIV_LONG:
    bne     a1, t4, divit_OP_DIV_LONG
    li      t5, 0xffff
    bne     a2, t5, divit_OP_DIV_LONG
    nop
    bne     a3, t5, divit_OP_DIV_LONG
    move    v0, zero
    b       store_OP_DIV_LONG
    lui     v1, 0x8000

/* continuation for OP_REM_LONG */

testneg_OP_REM_LONG:
    bne     a1, t4, divit_OP_REM_LONG
    li      t5, 0xffff
    bne     a2, t5, divit_OP_REM_LONG
    nop
    bne     a3, t5, divit_OP_REM_LONG
    move    v0, zero
    b       store_OP_REM_LONG
    move    v1, zero

/* continuation for OP_DIV_LONG_2ADDR */

testneg_OP_DIV_LONG_2ADDR:
    bne     a1, t4, divit_OP_DIV_LONG_2ADDR
    li      t5, 0xffff
    bne     a2, t5, divit_OP_DIV_LONG_2ADDR
    nop
    bne     a3, t5, divit_OP_DIV_LONG_2ADDR
    move    v0, zero
    b       store_OP_DIV_LONG_2ADDR
    lui     v1, 0x8000

/* continuation for OP_REM_LONG_2ADDR */

testneg_OP_REM_LONG_2ADDR:
    bne     a1, t4, divit_OP_REM_LONG_2ADDR
    li      t5, 0xffff
    bne     a2, t5, divit_OP_REM_LONG_2ADDR
    nop
    bne     a3, t5, divit_OP_REM_LONG_2ADDR
    move    v0, zero
    b       store_OP_REM_LONG_2ADDR
    move    v1, zero

    .size   dvmAsmSisterStart, .-dvmAsmSisterStart
    .global dvmAsmSisterEnd
dvmAsmSisterEnd:

/* File: mips/footer.S */
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
 *  s4 is PC adjustment *in bytes*
 */
common_backwardBranch:
    bal     common_periodicChecks
    li      a0, kInterpEntryInstr
    FETCH_ADVANCE_INST_RB(s4)           /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


/*
 * Need to see if the thread needs to be suspended or debugger/profiler
 * activity has begun.
 *
 * TODO: if JDWP isn't running, zero out pDebuggerActive pointer so we don't
 * have to do the second ld.
 *
 * TODO: reduce this so we're just checking a single location.
 *
 * On entry:
 *  a0 is reentry type, e.g. kInterpEntryInstr
 *  s4 is trampoline PC adjustment *in bytes*
 */
common_periodicChecks:
    lw     a3, offGlue_pSelfSuspendCount(rGLUE)	/* a3<- &suspendCount */

#if defined(WITH_DEBUGGER)
    lw     a1, offGlue_pDebuggerActive(rGLUE)	/* a1<- &debuggerActive */
#endif
#if defined(WITH_PROFILER)
    lw     a2, offGlue_pActiveProfilers(rGLUE)	/* r2<- &activeProfilers */
#endif

    lw     a3, 0(a3)                    /* a3<- suspendCount (int) */

#if defined(WITH_DEBUGGER)
    lw     a1, 0(a1)                    /* r1<- debuggerActive (boolean) */
#endif
#if defined (WITH_PROFILER)
    lw     a2, 0(a2)                    /* r2<- activeProfilers (int) */
#endif

    /*suspend pending? */
    bnez     a3, 2f                      /* yes, check suspend */
    nop

#if defined(WITH_DEBUGGER) || defined(WITH_PROFILER)
# if defined(WITH_DEBUGGER) && defined(WITH_PROFILER)
    or    v0, a1, a2		/* debugger attached or profiler started? */
# elif defined(WITH_DEBUGGER)
    move   v0, a1               /*  debugger attached? */
# elif defined(WITH_PROFILER)
    move   v0, r2               /*  profiler started? */
# endif
    bnez    v0, 3f              /*  debugger/profiler, switch interp */
    nop
#endif

    jr      ra                  /*  nothing to do, return */
    nop

2:  /* check suspend */
    move    gp, s8
    la      t9, dvmCheckSuspendPending  /* suspend if necessary, then return */
    jr      t9
    lw     a0, offGlue_self(rGLUE)	/* a0<- glue->self */

3:  /* debugger/profiler enabled, bail out */
    addu    rPC, rPC, s4                /* update rPC */
    sw      a0, offGlue_entryPoint(rGLUE)
    b       common_gotoBail
    li      a1, 1                      /* "want switch" = true */


/*
 * The equivalent of "goto bail", this calls through the "bail handler".
 *
 * State registers will be saved to the "glue" area before bailing.
 *
 * On entry:
 *  a1 is "bool changeInterp", indicating if we want to switch to the
 *     other interpreter or just bail all the way out
 */
common_gotoBail:
    SAVE_PC_FP_TO_GLUE()                /* export state to "glue" */
    move    gp, s8
    la      t9, dvmMterpStdBail         /* call(glue, changeInterp) */
    jr      t9
    move    a0, rGLUE                   /* a0<- glue ptr */


/*
 * Common code for method invocation with range.
 *
 * On entry:
 *  a0 is "Method* methodToCall", the method we're trying to call
 */
common_invokeMethodRange:
.LinvokeNewRange:
    /* prepare to copy args to "outs" area of current frame */
    srl     a2, rINST, 8	     /* a2<- AA (arg count) -- test for zero */
    SAVEAREA_FROM_FP(t7, rFP)        /* t7<- stack save area */
    beqz    a2, .LinvokeArgsDone     /* if no args, skip the rest */
    FETCH(a1, 2)                     /* a1<- CCCC */

    /* a0=methodToCall, a1=CCCC, a2=count, t7=outs
    */
    sll	    a1, a1, 2
    addu    a3, rFP, a1		        /* a3<- &fp[CCCC] */
    sll	    v0, a2, 2
    subu    t7, t7, v0                  /* t7<- "outs" area, for call args */
1:  lw      a1, 0(a3)                   /* val = *fp */
    addiu   a2, a2, -1                  /* count-- */
    addiu   a3, a3, 4			/* fp ++ */
    sw      a1, 0(t7)                   /* *outs = val */
    bnez    a2, 1b                      /* ...while count != 0 */
    addiu   t7, t7, 4			/* out++ */
    b       .LinvokeArgsDone

/*
 * Common code for method invocation without range.
 *
 * On entry:
 *  a0 is "Method* methodToCall", the method we're trying to call
 */
common_invokeMethodNoRange:
.LinvokeNewNoRange:
    /* prepare to copy args to "outs" area of current frame
    */
    srl	    a2, rINST, 12	     /* a2<- B (arg count) -- test for zero */
    SAVEAREA_FROM_FP(t7, rFP)        /* t7<- stack save area */
    beqz    a2, .LinvokeArgsDone     /* if no args, skip the rest */
    FETCH(a1, 2)                     /* r1<- GFED */

    /* a0=methodToCall, a1=GFED, a2=count, t7=outs
    */
.LinvokeNonRange:
    beqz    a2, 0f
    addiu   v0, a2, -4
    beqz    v0, 4f
    addiu   v0, a2, -3
    beqz    v0, 3f
    addiu   v0, a2, -2
    beqz    v0, 2f
    addiu   v0, a2, -1
    beqz    v0, 1f			/* Fall through to 5. delay slot OK */

5:  andi    v0, rINST, 0x0f00		/* isolate A */
    srl     v0, v0, 6			/* a3<- vA (shift right 8, left 2) */
    addu    v0, v0, rFP
    lw	    a3, 0(v0)
    sw	    a3, 0(t7)			/* *outs = vA */
    addiu   t7, t7, -4			/* outs-- */

4:  andi    v0, a1, 0xf000              /*  isolate G */
    srl     v0, v0, 10      		/* a3<- vG (shift right 12, left 2) */
    addu    v0, v0, rFP
    lw	    a3, 0(v0)
    sw      a3, 0(t7)		        /* *outs = vG */
    addiu   t7, t7, -4			/* outs-- */

3:  andi    v0, a1, 0x0f00              /*  isolate F */
    srl     v0, v0, 6      		/* a3<- vF */
    addu    v0, v0, rFP
    lw	    a3, 0(v0)
    sw      a3, 0(t7)		        /* *outs = vF */
    addiu   t7, t7, -4			/* outs-- */

2:  andi    v0, a1, 0x00f0              /*  isolate E */
    srl     v0, v0, 2      		/* a3<- vE */
    addu    v0, v0, rFP
    lw	    a3, 0(v0)
    sw      a3, 0(t7)		        /* *outs = vE */
    addiu   t7, t7, -4			/* outs-- */

1:  andi    v0, a1, 0x000f              /*  isolate D */
    sll     v0, v0, 2      		/* a3<- vD */
    addu    v0, v0, rFP
    lw	    a3, 0(v0)
    sw      a3, 0(t7)		        /* *outs = vE */
    addiu   t7, t7, -4			/* outs-- */

0:  /* fall through to .LinvokeArgsDone */

.LinvokeArgsDone: 	/*  a0=methodToCall */
    /* find space for the new stack frame, check for overflow
    */
    SAVEAREA_FROM_FP(a1, rFP)           /* a1<- stack save area */
    lhu     a2, offMethod_registersSize(a0)  /* r2<- methodToCall->regsSize */
    lhu     a3, offMethod_outsSize(a0)   /* a3<- methodToCall->outsSize */
    sll	    a2, a2, 2
    subu    a1, a1, a2                /* a1<- newFp (old savearea - regsSize) */
    SAVEAREA_FROM_FP(s4, a1)          /* s4<- newSaveArea */
/*    bl      common_dumpRegs */
    lw      t6, offGlue_interpStackEnd(rGLUE) /* t6<- interpStackEnd */
    sll	    v0, a3, 2
    subu    a3, s4, v0                /* a3<- bottom (newsave - outsSize) */
    subu    v0, a3, t6                /* bottom < interpStackEnd? */
    bltz    v0, .LstackOverflow       /* yes, this frame will overflow stack */

    /* set up newSaveArea
    */
#ifdef EASY_GDB
    SAVEAREA_FROM_FP(t5, rFP)          /* t5<- stack save area */
    sw      t5, offStackSaveArea_prevSave(s4)
#endif
    lw      a3, offMethod_accessFlags(a0) /* a3<- methodToCall->accessFlags */
    sw      rFP, offStackSaveArea_prevFrame(s4)
    sw      rPC, offStackSaveArea_savedPc(s4)

    /* This following instruction works because I know ACC_NATIVE is in the
     * lower 16-bits of accessFlags.
     */
    andi    v0, a3, ACC_NATIVE
    bnez    v0, .LinvokeNative
    sw      a0, offStackSaveArea_method(s4)

    /*
    stmfd   sp!, {r0-r3}
    bl      common_printNewline
    mov     r0, rFP
    mov     r1, #0
    bl      dvmDumpFp
    ldmfd   sp!, {r0-r3}
    stmfd   sp!, {r0-r3}
    mov     r0, r1
    mov     r1, r10
    bl      dvmDumpFp
    bl      common_printNewline
    ldmfd   sp!, {r0-r3}
    */

    /* Update "glue" values for the new method
     * a0=methodToCall, a1=newFp
     */
    lw      a3, offMethod_clazz(a0)        /* a3<- method->clazz */
    sw      a0, offGlue_method(rGLUE)      /* glue->method = methodToCall */
    lw      a3, offClassObject_pDvmDex(a3) /* a3<- method->clazz->pDvmDex */
    lw      rPC, offMethod_insns(a0)       /* rPC<- method->insns */
    sw      a3, offGlue_methodClassDex(rGLUE) /* glue->methodClassDex = ... */
    lw      a2, offGlue_self(rGLUE)         /* a2<- glue->self */
    FETCH_INST()                            /* load rINST from rPC */
    move    rFP, a1                         /* fp = newFp */
    GET_INST_OPCODE(t7)                     /* extract opcode from rINST */
    sw      a1, offThread_curFrame(a2)      /* self->curFrame = newFp */
    GOTO_OPCODE(t7)                         /* jump to next instruction */

.LinvokeNative:
    /* Prep for the native call
     * a0=methodToCall, a1=newFp, s4=newSaveArea
     */
    lw      a3, offGlue_self(rGLUE)      /* a3<- glue->self */
    lw      t6, offThread_jniLocal_nextEntry(a3) /* t6<- thread->refNext */
    sw      a1, offThread_curFrame(a3)   /* self->curFrame = newFp */
    sw      t6, offStackSaveArea_localRefTop(s4) /*newFp->localRefTop=refNext */
    move    s5, a3                      /* t6<- glue->self (preserve) */

    move    a2, a0                      /* a2<- methodToCall */
    move    a0, a1                      /* a0<- newFp (points to args) */

    /* Call methodToCall->nativeFunc(newFp, &retval)
    */
    addiu   sp, sp, -16			/* allocate call stack */
    lw	     t9, offMethod_nativeFunc(a2)
    jalr     t9
    addiu    a1, rGLUE, offGlue_retval  /* a1<- &retval */
    addiu   sp, sp, 16			/* deallocate call stack */

    /* native return; s5=self, s4=newSaveArea
     * equivalent to dvmPopJniLocals
     */
    lw      a0, offStackSaveArea_localRefTop(s4) /* r0<- newSave->localRefTop */
    lw      a1, offThread_exception(s5)          /* check for exception */
    sw      rFP, offThread_curFrame(s5)          /* self->curFrame = fp */
    bnez    a1, common_exceptionThrown      /* a1 != null, handle exception */
    sw      a0, offThread_jniLocal_nextEntry(s5) /* self->refNext<- r0 */

    FETCH_ADVANCE_INST(3)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */

.LstackOverflow:
    move    gp, s8
    addiu   sp, sp, -16			/* allocate call stack */
    la      t9, dvmHandleStackOverflow
    jalr    t9
    lw      a0, offGlue_self(rGLUE)     /* r0<- self */
    b       common_exceptionThrown
    addiu   sp, sp, 16			/* deallocate call stack */

/*
 * Common code for handling a return instruction.
 *
 * This does not return.
 */
common_returnFromMethod:
.LreturnNew:
    li      a0, kInterpEntryReturn
    bal     common_periodicChecks
    li      s4, 0

    SAVEAREA_FROM_FP(a0, rFP)           /* a0<- saveArea (old) */
    lw      rFP, offStackSaveArea_prevFrame(a0) /* fp = saveArea->prevFrame */
    lw      a2, (offStackSaveArea_method - sizeofStackSaveArea)(rFP)
                                        /* a2<- method we're returning to */
    beqz    a2, common_gotoBail         /* break frame, bail out completely */
    li      a1, 0                       /* "want switch" = false */

    lw      rPC, offStackSaveArea_savedPc(a0) /* pc = saveArea->savedPc */
    lw      a3, offGlue_self(rGLUE)      /* a3<- glue->self */
    sw      a2, offGlue_method(rGLUE)    /* glue->method = newSave->method */
    sw      rFP, offThread_curFrame(a3)  /* self->curFrame = fp */
    lw      a1, offMethod_clazz(a2)      /* a1<- method->clazz */
    FETCH_ADVANCE_INST(3)                /* advance rPC, load rINST */
    lw      a1, offClassObject_pDvmDex(a1)   /* a1<- method->clazz->pDvmDex */
    GET_INST_OPCODE(t7)                  /* extract opcode from rINST */
    sw      a1, offGlue_methodClassDex(rGLUE)
    GOTO_OPCODE(t7)                      /* jump to next instruction */

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
    li      a0, kInterpEntryThrow
    bal     common_periodicChecks
    li      s4, 0

    lw      s4, offGlue_self(rGLUE)     /* s4<- glue->self */
    lw      s5, offThread_exception(s4) /* s5<- self->exception */
    addiu   sp, sp, -16			/* allocate call stack */
    move    a1, s4                      /* a1<- self */
    move    gp, s8
    la      t9, dvmAddTrackedAlloc      /* don't let the exception be GCed */
    jalr    t9
    move    a0, s5                      /* a0<- exception */
    addiu   sp, sp, 16			/* deallocate call stack */

    li      a3, 0                       /* a3<- NULL */
    sw      a3, offThread_exception(s4) /* self->exception = NULL */

    /* Make the function call
     * catchAddr = dvmFindCatchBlock(self, relPc, exc, scan?, &fp)
     * First four args in registers, plus two stack words, one for FP and
     * one for &fp.
     */
    addiu   sp, sp, -4			/* stack storage FP */
    sw	    rFP, 0(sp)			/* *--sp = FP */
    move    v0, sp	    
    addiu   sp, sp, -20			/* &fp, arg3 - arg0 */
    sw	    v0, 16(sp)			/* &fp */
    li      a3, 0                       /*  a3<- false */
    lw      a1, offGlue_method(rGLUE)   /*  a1<- glue->method */
    move    a0, s4                      /*  a0<- self */
    lw      a1, offMethod_insns(a1)     /*  a1<- method->insns */
    move    a2, s5                      /*  a2<- exception */
    subu    a1, rPC, a1                 /*  a1<- pc - method->insns */

    /* call, v0 gets catchRelPc (a code-unit offset) */
    move    gp, s8
    la      t9, dvmFindCatchBlock       /* call(self, relPc, exc, scan?, &fp) */
    jalr    t9
    srl	    a1, a1, 1			/*  a1<- offset in code units */

    /* fix earlier stack overflow if necessary; may trash rFP */
    lbu     a1, offThread_stackOverflowed(s4)
    beqz    a1, 1f
    move    s6, v0                      /* save relPc result in rFP */
    move    gp, s8
    la      t9, dvmCleanupStackOverflow /* call(self) */
    jalr    t9
    move    a0, s4                   /* a0<- self */
    move    v0, s6                   /* restore return from dvmFindCatchBlock */
1:

    /* update frame pointer and check result from dvmFindCatchBlock
    */
    lw      rFP, 20(sp)               /* retrieve the updated rFP */
    bltz    v0, .LnotCaughtLocally
    addiu   sp, sp, 24                /* restore stack */

    /* adjust locals to match self->curFrame and updated PC
    */
    SAVEAREA_FROM_FP(a1, rFP)            /*  a1<- new save area */
    lw      a1, offStackSaveArea_method(a1) /*  a1<- new method */
    sw      a1, offGlue_method(rGLUE)    /*  glue->method = new method */
    lw      a2, offMethod_clazz(a1)      /*  a2<- method->clazz */
    lw      a3, offMethod_insns(a1)      /*  a3<- method->insns */
    lw      a2, offClassObject_pDvmDex(a2) /*  a2<- method->clazz->pDvmDex */
    sll     v0, v0, 1
    addu    rPC, a3, v0                  /*  rPC<- method->insns + catchRelPc */
    sw      a2, offGlue_methodClassDex(rGLUE)  /* glue->pDvmDex = meth... */

    /* release the tracked alloc on the exception
    */
    move    a1, s4                      /* a1<- self */
    move    gp, s8
    la      t9, dvmReleaseTrackedAlloc  /* release the exception */
    jalr    t9
    move    a0, s5                      /* a0<- exception */

    /* restore the exception if the handler wants it
    */
    FETCH_INST()                        /* load rINST from rPC */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    subu    v0, t7, OP_MOVE_EXCEPTION   /* is it "move-exception"? */
    bnez    v0, 1f
    nop
    sw      s5, offThread_exception(s4) /* yes, restore the exception */
1:
    GOTO_OPCODE(t7)                     /* jump to next instruction */

.LnotCaughtLocally:			/* s5=exception, s4=self */
    /* fix stack overflow if necessary */
    lbu     a1, offThread_stackOverflowed(s4) /* did we overflow earlier? */
    beqz    a1, .LnoOverflow
    move    gp, s8
    la      t9, dvmCleanupStackOverflow     /* if yes: call(self) */
    jalr    t9
    move    a0, s4                          /* a0<- self */

.LnoOverflow:
    sw      s5, offThread_exception(s4) /* restore exception */
    move    a0, s5                      /* a0<- exception */
    move    gp, s8
    la      t9, dvmReleaseTrackedAlloc  /* release the exception */
    jalr    t9
    move    a1, s4                      /* a1<- self */
    b       common_gotoBail             /* bail out */
    li      a1, 0                       /* "want switch" = false */

/*
 * After returning from a "glued" function, pull out the updated
 * values and start executing at the next instruction.
 */
common_resumeAfterGlueCall:
    LOAD_PC_FP_FROM_GLUE()              /* pull rPC and rFP out of glue */
    FETCH_INST()                        /* load rINST from rPC */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */

/*
 * Invalid array index.
 */
common_errArrayIndex:
    EXPORT_PC()
    move    gp, s8
    la      a0, .strArrayIndexException
    la      t9, dvmThrowException
    jalr    t9
    li      a1, 0
    b       common_exceptionThrown
    nop

/*
 * Invalid array value.
 */
common_errArrayStore:
    EXPORT_PC()
    move    gp, s8
    la      a0, .strArrayStoreException
    la      t9, dvmThrowException
    jalr    t9
    li      a1, 0
    b       common_exceptionThrown
    nop

/*
 * Integer divide or mod by zero.
 */
common_errDivideByZero:
    EXPORT_PC()
    move    gp, s8
    la      a0, .strArithmeticException
    la      t9, dvmThrowException
    jalr    t9
    li      a1, 0
    b       common_exceptionThrown
    nop

/*
 * Attempt to allocate an array with a negative size.
 */
common_errNegativeArraySize:
    EXPORT_PC()
    move    gp, s8
    la      a0, .strNegativeArraySizeException
    la      t9, dvmThrowException
    jalr    t9
    li      a1, 0
    b       common_exceptionThrown
    nop

/*
 * Invocation of a non-existent method.
 */
common_errNoSuchMethod:
    EXPORT_PC()
    move    gp, s8
    la      a0, .strNoSuchMethodError
    la      t9, dvmThrowException
    jalr    t9
    li      a1, 0
    b       common_exceptionThrown
    nop

/*
 * We encountered a null object when we weren't expecting one.  We
 * export the PC, throw a NullPointerException, and goto the exception
 * processing code.
 */
common_errNullObject:
    EXPORT_PC()
    move    gp, s8
    la      a0, .strNullPointerException
    la      t9, dvmThrowException
    jalr    t9
    li      a1, 0
    b       common_exceptionThrown
    nop

/*
 * For debugging, cause an immediate fault.  The source address will
 * be in lr (use a bl instruction to jump here).
 */
common_abort:
    b       .LdeadFood
    nop
.LdeadFood:
    .word   0xdeadf00d
    nop

#if 0
/*
 * Call a C helper function that dumps regs and possibly some
 * additional info.  Requires the C function to be compiled in.
 */
    .if     0
common_dumpRegs:
    stmfd   sp!, {r0, r1, r2, r3, ip, lr}
    bl      dvmMterpDumpArmRegs
    ldmfd   sp!, {r0, r1, r2, r3, ip, lr}
    bx      lr
    .endif
#endif

/*
 * Zero-terminated ASCII string data.
 */
    .section .rodata.str1.4,"aMS",%progbits,1

.strBadEntryPoint:
    .asciz  "Bad entry point %d\n"
.strArithmeticException:
    .asciz  "Ljava/lang/ArithmeticException;"
.strArrayIndexException:
    .asciz  "Ljava/lang/ArrayIndexOutOfBoundsException;"
.strArrayStoreException:
    .asciz  "Ljava/lang/ArrayStoreException;"
.strClassCastException:
    .asciz  "Ljava/lang/ClassCastException;"
.strDivideByZero:
    .asciz  "divide by zero"
.strFilledNewArrayNotImpl:
    .asciz  "filled-new-array only implemented for objects and 'int'"
.strInternalError:
    .asciz  "Ljava/lang/InternalError;"
.strInstantiationError:
    .asciz  "Ljava/lang/InstantiationError;"
.strNegativeArraySizeException:
    .asciz  "Ljava/lang/NegativeArraySizeException;"
.strNoSuchMethodError:
    .asciz  "Ljava/lang/NoSuchMethodError;"
.strNullPointerException:
    .asciz  "Ljava/lang/NullPointerException;"

.strLogTag:
    .asciz  "mterp"
.strExceptionNotCaughtLocally:
    .asciz  "Exception %s from %s:%d not caught locally\n"



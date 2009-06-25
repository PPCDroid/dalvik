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


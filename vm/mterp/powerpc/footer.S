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
 * activity has begun.
 *
 * TODO: if JDWP isn't running, zero out pDebuggerActive pointer so we don't
 * have to do the second ld.
 *
 * TODO: reduce this so we're just checking a single location.
 *
 * On entry:
 *  r3 is reentry type, e.g. kInterpEntryInstr
 *  r11 is trampoline PC adjustment *in bytes*
 */
common_periodicChecks:
	lwz	r10, offGlue_pSelfSuspendCount(rGLUE)	/* r10<- &suspendCount */

	/* speculatively store r0 before it is clobbered by dvmCheckSuspendPending */
	stw     r3, offGlue_entryPoint(rGLUE)

#if defined(WITH_DEBUGGER)
	lwz	r9, offGlue_pDebuggerActive(rGLUE)	/* r9<- &debuggerActive */
#endif
#if defined(WITH_PROFILER)
	lwz	r8, offGlue_pActiveProfilers(rGLUE)	/* r8<- &activeProfilers */
#endif

	lwz	r10, 0(r10)				/* r10<- suspendCount (int) */

#if defined(WITH_DEBUGGER)
	lwz	r9, 0(r9)				/* r9<- debuggerActive (boolean) */
#endif
#if defined (WITH_PROFILER)
	lwz     r8, 0(r8)				/* r8<- activeProfilers (int) */
#endif

	/* suspend pending? */
	cmpwi	r10, 0					/* yes, do full suspension check */
	bne	2f

#if defined(WITH_DEBUGGER) || defined(WITH_PROFILER)
# if defined(WITH_DEBUGGER) && defined(WITH_PROFILER)
	or	r9, r9, r8				/* debugger attached or profiler started? */
	cmpwi	r9, 0					/* yes, check suspend */
# elif defined(WITH_DEBUGGER)
	cmpwi	r9, 0					/* yes, check suspend */
# elif defined(WITH_PROFILER)
	cmpwi	r8, 0					/*  profiler started? */
# endif
	bne	3f					/*  debugger/profiler, switch interp */
#endif

	blr						/*  nothing to do, return */

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

3:	add	rPC, rPC, r11				/* debugger/profiler enabled, bail out */
	li      r4, 1                      		/* "want switch" = true */
	b       common_gotoBail

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
	srwi	r5, rINST, 8
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
	srwi	r5, rINST, 12			/* r5<- B (arg count) -- test for zero */
	cmpwi	r5, 0
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

	cmpw	r6, r5					/* bottom < interpStackEnd? */
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
	li	r20, 0
	bl	common_periodicChecks

	lwz	r20, offGlue_self(rGLUE)		/* r20<- glue->self */
	lwz	r19, offThread_exception(r20)		/* r19<- self->exception */
	mr	r4, r20					/* r4<- self */
	mr	r3, r19					/* r3<- exception */
	bl	dvmAddTrackedAlloc@plt			/* don't let the exception be GCed */
	li	r0, 0					/* r0<- NULL */
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

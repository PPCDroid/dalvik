%verify "executed"
%verify "unimplemented array type"
	/*
	* Create a new array with elements filled from registers.
	*
	* for: filled-new-array/range
	*/
	/* op {vCCCC..v(CCCC+AA-1)}, type@BBBB */
	rlwinm  r19,rINST,24,24,31		/* r19<- AA */
	FETCH(r4, 1)				/* r4<- CCCC */
	slwi	r5, r4, 2			/* r5<- CCCC << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r6, offDvmDex_pResClasses(r6)	/* r6<- pDvmDex->pResClasses */
	lwzx	r3, r6, r5			/* r3<- resolved class */
#else
	lwzx	r3, rResCls, r5			/* r3<- resolved class */
#endif
	EXPORT_PC()				/* need for resolve and alloc */
	cmpwi	r3, 0				/* already resolved? */
	bne+	.L${opcode}_continue		/*  yes, continue on */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	li	r5, 0				/* r5<- false */
	bl	dvmResolveClass@plt		/* r3<- call(clazz, ref) */
	cmpwi	r3, 0				/* got null? */
	bne+    .L${opcode}_continue		/* continue? */
	b	common_exceptionThrown		/* no, handle exception */

%break
	/*
	 * On entry:
	 *  r3 holds array class
	 *  r19 holds length
	 */
.L${opcode}_continue:
	lwz	r6, offClassObject_descriptor(r3)	/* r6<- arrayClass->descriptor */
	lbz	r6, 1(r6)			/* r6<- descriptor[1] */
	cmpwi	r6, 'I'				/* array of ints? */
	beq+	0f
	cmpwi	r6, 'L'				/* array of objects? */
	beq	0f
	cmpwi	r6, '['				/* array of arrays? */
	beq	0f
	b	.L${opcode}_notimpl		/* no, not handled yet */
0:	mr	r4, r19				/* r4<- r19 (length) */
	li	r5, ALLOC_DONT_TRACK		/* r5<- alloc flags */
	bl	dvmAllocArrayByClass@plt	/* r3<- call(arClass, length, flags) */
	cmpwi	r3, 0				/* null return? */
	beq-	common_exceptionThrown		/* alloc failed, handle exception */

	FETCH(r4, 2)				/* r4<- CCCC */
	FETCH_ADVANCE_INST(3)			/* advance to next instr, load rINST */
	stw     r3, offGlue_retval(rGLUE)	/* retval.l <- new array */
	addi	r3, r3, offArrayObject_contents	/* r3<- newArray->contents */

	/* copy values from registers into the array */
	/* r3=array, r4=CCCC, r19=AA */
	cmpwi	r19, 0				/* length was initially <= 0 */
	ble	2f				/* yes, bail */
	mtctr	r19				/* ctr<- r19 */
	slwi	r6, r4, 2			/* r6<- r4 << 2 */
	add     r5, rFP, r6			/* r5<- &fp[CCCC] */
	addi	r3, r3, -4			/* point one back for pre-inc */
	addi	r5, r5, -4			/* point one back for pre-inc */
1:	lwzu	r6, 4(r5)			/* r6<- *++r5 */
	stwu	r6, 4(r3)			/* *++contents = vX */
	bdnz+	1b				/* loop while ctr > 0 */

2:	GET_INST_OPCODE_GOTO(r0)		/* r0<- opcode from rINST */

	/*
	 * Throw an exception indicating that we have not implemented this
	 * mode of filled-new-array.
	 */
.L${opcode}_notimpl:
	lis	r3, .LstrInternalError@ha
	addi	r3, r3, .LstrInternalError@l
	lis	r4, .LstrFilledNewArrayNotImpl@ha
	addi	r4, r4, .LstrFilledNewArrayNotImpl@l
	bl      dvmThrowException@plt
	b       common_exceptionThrown

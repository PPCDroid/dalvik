%verify "executed"
%verify "negative array length"
%verify "allocation fails"
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
	beq-	.L${opcode}_resolve		/* do resolve now */
.L${opcode}_finish:
	li	r5, ALLOC_DONT_TRACK		/* don't track in local refs table */
	bl	dvmAllocArrayByClass@plt	/* r3<- call(clazz(r3), length(r4), flags(r5)) */
	cmpwi	r3, 0				/* failed? */
	beq-	common_exceptionThrown		/* yes, handle the exception */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* vA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */
%break


    /*
     * Resolve class.  (This is an uncommon case.)
     *
     *  r4 holds array length
     *  r5 holds class ref CCCC
     */
.L${opcode}_resolve:
	mr	r20, r4				/* r20<- length (save) */
	lwz	r6, offGlue_method(rGLUE)	/* r3<- glue->method */
	lwz     r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	mr	r4, r5				/* r4<- CCCC */
	li	r5, 0				/* r5<- false */
	bl	dvmResolveClass@plt		/* r3<- call(clazz, ref) */
	cmpwi	r3, 0				/* got null? */
	mr	r4, r20				/* r4<- length (restore) */
	bne+	.L${opcode}_finish		/* OK */
	b	common_exceptionThrown		/* handle exception */

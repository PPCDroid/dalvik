%default { "isrange":"0", "routine":"NoRange" }
%verify "executed"
%verify "unknown method"
	/*
	 * Handle a direct method call.
	 *
	 * for: invoke-direct, invoke-direct/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	FETCH(r19, 2)				/* r19<- GFED or CCCC */
	.if	(!$isrange)
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
	bne+	common_invokeMethod${routine}	/* no, continue on */
	b	common_errNullObject		/* yes, throw exception */

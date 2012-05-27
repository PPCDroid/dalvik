%default { "isrange":"0", "routine":"NoRange" }
%verify "executed"
%verify "unknown method"
%verify "null object"
	/*
	 * Handle an interface method call.
	 *
	 * for: invoke-interface, invoke-interface/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	FETCH(r6, 2)				/* r6<- GFED or CCCC */
	.if	(!$isrange)
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
	bne+	common_invokeMethod${routine}	/* no, continue on */
	b	common_exceptionThrown

%default { "isrange":"0", "routine":"NoRange" }
%verify "executed"
%verify "unknown method"
	/*
	 * Handle an optimized "super" method call.
	 *
	 * for: [opt] invoke-super-quick, invoke-super-quick/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op vAA, {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	FETCH(r19, 2)				/* r19<- GFED or CCCC */
	.if	(!$isrange)
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
	b	common_invokeMethod${routine}

%default { "isrange":"0", "routine":"NoRange" }
%verify "executed"
%verify "null object"
	/*
	 * Handle a virtual method call.
	 *
	 * for: invoke-virtual, invoke-virtual/range
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
	cmpwi	r20, 0				/* null "this" ref? */
	beq- 	common_errNullObject		/* yes, throw exception */
	lwz	r6, offObject_clazz(r20)	/* r6<- thisPtr->clazz */
	lwz	r6, offClassObject_vtable(r6)	/* r6<- thisPtr->clazz->vtable */
	slwi	r5, r4, 2			/* r5<- BBBB << 2 */
	EXPORT_PC()				/* invoke must export */
	lwzx	r3, r6, r5			/* r3<- vtable[methodIndex] */
	b	common_invokeMethod${routine}

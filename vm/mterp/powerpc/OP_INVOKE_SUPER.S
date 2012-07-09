%default { "isrange":"0", "routine":"NoRange" }
%verify "executed"
%verify "unknown method"
	/*
	 * Handle a "super" method call.
	 *
	 * for: invoke-super, invoke-super/range
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
	slwi	r5, r4, 2			/* r5<- r4 << 2 */
	GET_VREG_S(r20, r19)			/* r20<- "this" ptr */
	EXPORT_PC()				/* must export for invoke */
	cmpwi	r20, 0				/* null "this"? */
	beq-	common_errNullObject		/* null "this", throw exception */
	lwz	r21, offGlue_method(rGLUE)	/* r21<- glue->method */
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r21, offMethod_clazz(r21)	/* r21<- method->clazz */
	lwz	r6, offDvmDex_pResMethods(r6)	/* r6<- pDvmDex->pResMethods */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
	cmpwi	r3, 0				/* already resolved? */
	bne+	0f				/* resolved?, yes */
	mr	r3, r21				/* r3<- method->clazz */
	li	r5, METHOD_VIRTUAL		/* resolver method type */
	bl	dvmResolveMethod@plt		/* r3<- call(clazz, ref, flags) */
	cmpwi	r3, 0				/* got null? */
	beq-	common_exceptionThrown		/* yes, handle exception */
0:	lwz	r4, offClassObject_super(r21)	/* r4<- method->clazz->super */
	lhz	r5, offMethod_methodIndex(r3)	/* r5<- baseMethod->methodIndex */
	lwz	r6, offClassObject_vtableCount(r4)	/* r6<- super->vtableCount */
	cmplw	r5, r6				/* compare (methodIndex, vTableCount) */
	bge-	.L${opcode}_nsm			/* method not present in superclass */
	lwz	r4, offClassObject_vtable(r4)	/* r4<- ...clazz->super->vtable */
	slwi	r5, r5, 2			/* r5<- baseMethod->methodIndex << 2 */
	lwzx	r3, r4, r5			/* r3<- vtable[methodIndex] */
	b	common_invokeMethod${routine}	/* no, continue on */
%break
.L${opcode}_nsm:
	lwz	r4, offMethod_name(r3)		/* r4<- method name */
	b	common_errNoSuchMethod

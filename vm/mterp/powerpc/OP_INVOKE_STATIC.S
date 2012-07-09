%default { "routine":"NoRange" }
%verify "executed"
%verify "unknown method"
	/*
	 * Handle a static method call.
	 *
	 * for: invoke-static, invoke-static/range
	 */
	/* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
	/* op {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	FETCH(r4, 1)				/* r4<- BBBB */
	lwz	r6, offDvmDex_pResMethods(r6)	/* r6<- pDvmDex->pResMethods */
	slwi	r5, r4, 2			/* r5<- r4 << 2 */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
	cmpwi	r3, 0				/* already resolved? */
	EXPORT_PC()				/* must export for invoke */
	bne+	common_invokeMethod${routine}	/* yes, calls */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	li	r5, METHOD_STATIC		/* resolver method type */
	bl	dvmResolveMethod@plt		/* r3<- call(clazz, ref, flags) */
	cmpwi	r3, 0				/* got null? */
	bne+	common_invokeMethod${routine}	/* no, call */
	b 	common_exceptionThrown		/* yes, throw exception */

%verify "executed"
%verify "class not resolved"
%verify "class cannot be resolved"
%verify "class not initialized"
%verify "class fails to initialize"
%verify "class already resolved/initialized"
%verify "class is abstract or interface"
%verify "allocation fails"
	/*
	 * Create a new instance of a class.
	 */
	/* new-instance vAA, class@BBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	slwi	r5, r4, 2			/* r5<- BBBB << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r6, offDvmDex_pResClasses(r6)	/* r6<- pDvmDex->pResClasses */
	lwzx	r3, r6, r5			/* r3<- resolved class */
#else
	lwzx	r3, rResCls, r5			/* r3<- resolved class */
#endif
	EXPORT_PC()				/* req'd for init, resolve, alloc */
	cmpwi	r3, 0				/* already resolved? */
	bne+	0f				/* yes, continue */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	li	r5, 0				/* r5<- false */
	bl	dvmResolveClass@plt		/* r3<- resolved ClassObject ptr */
	cmpwi	r3, 0				/* got null? */
	beq-	common_exceptionThrown		/* yes, handle exception */
0:	lbz	r4, offClassObject_status(r3)	/* r1<- ClassStatus enum */
	cmpwi	r4, CLASS_INITIALIZED		/* has class been initialized? */
	bne-	.L${opcode}_needinit		/* no, init class now */
.L${opcode}_initialized:			/* r3=class */
						/* finish */
	li	r4, ALLOC_DONT_TRACK		/* flags for alloc call */
	bl	dvmAllocObject@plt		/* r3<- new object */
	cmpwi	r3, 0				/* failed? */
	beq-	common_exceptionThrown		/* yes, handle the exception */
	rlwinm	r6,rINST,26,6,29		/* r6<- AA << 2 */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r6)			/* vAA<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

%break

    /*
     * Class initialization required.
     *
     *  r3 holds class object
     */
.L${opcode}_needinit:
	mr	r19, r3				/* save r3 */
	bl	dvmInitClass@plt		/* initialize class */
	cmpwi	r3, 0				/* check boolean result */
	mr	r3, r19				/* restore r3 */
	bne+	.L${opcode}_initialized		/* success, continue */
	b	common_exceptionThrown		/* failed, deal with init exception */

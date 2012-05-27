%verify "executed"
%verify "null object"
%verify "class cast exception thrown, with correct class name"
%verify "class cast exception not thrown on same class"
%verify "class cast exception not thrown on subclass"
%verify "class not resolved"
%verify "class already resolved"
	/*
	 * Check to see if a cast from one class to another is allowed.
	 */
	/* check-cast vAA, class@BBBB */
	rlwinm	r6,rINST,26,6,29		/* r6<- AA << 2 */
	FETCH(r4, 1)				/* r4<- BBBB */
	GET_VREG_S(r19, r6)			/* r19<- object */
	cmpwi	r19, 0				/* is object null? */
	beq-    0f				/* null obj, cast always succeeds */
	slwi	r5, r4, 2			/* r5<- BBBB << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r6, offDvmDex_pResClasses(r6)	/* r6<- pDvmDex->pResClasses */
	lwzx	r4, r6, r5			/* r4<- resolved class */
#else
	lwzx	r4, rResCls, r5			/* r4<- resolved class */
#endif
	cmpwi	r4, 0				/* have we resolved this before? */
	beq-	.L${opcode}_resolve		/* not resolved, do it now */
.L${opcode}_resolved:
	lwz	r3, offObject_clazz(r19)	/* r3<- obj->clazz */
	cmpw	r3, r4				/* same class (trivial success)? */
	beq-	0f				/* yes, skip full check */
	/*
	* Trivial test failed, need to perform full check.  This is common.
	*  r3 holds obj->clazz
	*  r4 holds class resolved from BBBB
	*  r19 holds object
	*/
	bl	dvmInstanceofNonTrivial@plt	/* r3<- boolean result */
	cmpwi	r3, 0				/* failed? */
	beq-	.L${opcode}_throw		/* yes, throw exception */
0:	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

%break

.L${opcode}_throw:
	/* A cast has failed.  We need to throw a ClassCastException with the */
	/* class of the object that failed to be cast. */
	EXPORT_PC()				/* about to throw */
	lis	r3, .LstrClassCastException@ha	/* r3<- string message */
	addi	r3, r3, .LstrClassCastException@l
	lwz	r6, offObject_clazz(r19)	/* r6<- obj->clazz */
	lwz	r4, offClassObject_descriptor(r6)	/* r4<- obj->clazz->descriptor */
	bl	dvmThrowExceptionWithClassMessage@plt
	b       common_exceptionThrown

	/*
	 * Resolution required.  This is the least-likely path.
	 *
	 *  r5 holds BBBB << 2
	 *  r19 holds object
	 */
.L${opcode}_resolve:
	EXPORT_PC()				/* resolve() could throw */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	srwi	r4, r5, 2			/* r4<- BBBB */
	li	r5, 0				/* r5<- false */
	bl	dvmResolveClass@plt		/* r3<- resolved ClassObject ptr */
	cmpwi	r3, 0				/* got null? */
	beq-	common_exceptionThrown		/* yes, handle exception */
	mr	r4, r3				/* r4<- class resolved from BBBB */
	b	.L${opcode}_resolved		/* pick up where we left off */

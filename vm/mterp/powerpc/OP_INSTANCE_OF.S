%verify "executed"
%verify "null object"
%verify "class cast exception thrown, with correct class name"
%verify "class cast exception not thrown on same class"
%verify "class cast exception not thrown on subclass"
%verify "class not resolved"
%verify "class already resolved"
	/*
	 * Check to see if an object reference is an instance of a class.
	 *
	 * Most common situation is a non-null object, being compared against
	 * an already-resolved class.
	 */
	/* instance-of vA, vB, class@CCCC */
	rlwinm	r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm	r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r6)			/* r3<- vB (object) */
	cmpwi	r3, 0				/* is object null? */
	beq-	0f				/* null obj, not an instance, store r3 */
	FETCH(r4, 1)				/* r4<- CCCC */
	slwi	r5, r4, 2			/* r5<- CCCC << 2 */
	lwz	r3, offObject_clazz(r3)		/* r3<- obj->clazz */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- pDvmDex */
	lwz	r6, offDvmDex_pResClasses(r6)	/* r6<- pDvmDex->pResClasses */
	lwzx	r4, r6, r5			/* r4<- resolved class */
#else
	lwzx	r4, rResCls, r5			/* r4<- resolved class */
#endif
	cmpwi	r4, 0				/* have we resolved this before? */
	beq-	.L${opcode}_resolve		/* not resolved, do it now */
.L${opcode}_resolved:				/* r0=obj->clazz, r1=resolved class */
	cmpw	r3, r4				/* same class (trivial success)? */
	bne-	1f				/* yes, do full check */
	li	r3, 1				/* indicate success */
	b	0f
1:	bl	dvmInstanceofNonTrivial@plt	/* r3<- boolean result */
0:	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* vA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */
%break

	/*
	 * Resolution required.  This is the least-likely path.
	 *
	 *  r5 holds CCCC << 2
	 *  r19 holds A
	 */
.L${opcode}_resolve:
	EXPORT_PC()				/* resolve() could throw */
	lwz	r6, offGlue_method(rGLUE)	/* r6<- glue->method */
	lwz	r3, offMethod_clazz(r6)		/* r3<- method->clazz */
	srwi	r4, r5, 2			/* r4<- CCCC */
	li	r5, 0				/* r5<- true */
	bl	dvmResolveClass@plt		/* r3<- resolved ClassObject ptr */
	cmpwi	r3, 0				/* got null? */
	beq-	common_exceptionThrown		/* yes, handle exception */
	mr	r4, r3				/* r4<- class resolved from CCCC */
	rlwinm	r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r6)			/* r3<- vB (object) */
	lwz	r3, offObject_clazz(r3)		/* r3<- obj->clazz */
	b	.L${opcode}_resolved		/* pick up where we left off */

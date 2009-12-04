%verify "executed"
%verify "String already resolved"
%verify "String not yet resolved"
%verify "String cannot be resolved"
	/* const/string vAA, String@BBBBBBBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r3, 1)				/* r3<- bbbb (low) */
	FETCH(r4, 2)				/* r4<- BBBB (high) */
	rotlwi	r4, r4, 16			/* rotate */
	or	r4, r3, r4			/* r4<- BBBBbbbb */
	slwi	r6, r4, 2			/* r6<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r5, offGlue_methodClassDex(rGLUE)	/* r5<- glue->methodClassDex */
	lwz	r5, offDvmDex_pResStrings(r5)	/* r5<- dvmDex->pResStrings */
	lwzx	r3, r5, r6			/* r3<- pResStrings[BBBBBBBB] */
#else
	lwzx	r3, rResStr, r6			/* r3<- pResStrings[BBBBBBBB] */
#endif
	cmpwi	r3, 0				/* not yet resolved? */
	bne+	0f				/* resolved, handle it */
	EXPORT_PC()
	lwz	r3, offGlue_method(rGLUE)	/* r3<- glue->method */
	lwz	r3, offMethod_clazz(r3)		/* r3<- method->clazz */
	bl	dvmResolveString@plt		/* r3<- String reference */
	cmpwi	r3, 0				/* failed? */
	beq-	common_exceptionThrown		/* yup, handle the exception */
0:	FETCH_ADVANCE_INST(3)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r19)			/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

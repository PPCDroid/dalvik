%default { "load":"lwz", "store":"stwx", "mask":"" }
%verify "executed"
%verify "field already resolved"
%verify "field not yet resolved"
%verify "field cannot be resolved"
	/*
	 * General 32-bit SGET handler.
	 *
	 * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r6<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved methodToCall */
#else
	lwzx	r3, rResFld, r5			/* r3<- resolved StaticField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveStaticField@plt	/* r3<- resolved StaticField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	$load	r3, offStaticField_value(r3)	/* r3<- byte offset of field */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	.ifnb $mask
	$mask
	.endif
	$store	r3, r19, rFP			/* fp[A]<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

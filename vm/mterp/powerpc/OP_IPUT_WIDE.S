%default {"volatile":"0"}
%verify "executed"
%verify "null object"
%verify "field already resolved"
%verify "field not yet resolved"
%verify "field cannot be resolved"
	/*
	 * General 32-bit instance field get.
	 *
	 * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
	 */
	/* op vA, vB, field@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r3,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	GET_VREG_S(r20, r3)			/* r20<- fp[B], the object pointer */
	slwi	r3, r4, 2			/* r3<- r4 << 2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r5, offDvmDex_pResFields(r6)	/* r5<- pDvmDex->pResFields */
	lwzx	r3, r5, r3			/* r3<- resolved InstField ptr */
#else
	lwzx	r3, rResFld, r3			/* r3<- resolved InstField ptr */
#endif
	cmpwi	r3, 0				/* is resolved entry null? */
	bne+	0f				/* no, already resolved */
	lwz	r5, offGlue_method(rGLUE)	/* r5<- current method */
	EXPORT_PC()				/* resolve() could throw */
	lwz	r3, offMethod_clazz(r5)		/* r3<- method->clazz */
	bl	dvmResolveInstField@plt		/* r3<- resolved InstField ptr */
	cmpwi	r3, 0				/* zero? */
	beq-	common_exceptionThrown		/* yes, exception */
0:	cmpwi	r20, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	lwz	r5, offInstField_byteOffset(r3)	/* r4<- byte offset of field */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	lwzux	r3, r19, rFP			/* r3<-fp[A] (hi) */
	lwz	r4, 4(r19)			/* lo */
	.if $volatile
	add	r5, r20, r5
	bl	dvmQuasiAtomicSwap64@plt
	.else
	stwux	r3, r20, r5			/* obj.field(64 bits) <- r3 (hi)  */
	stw	r4, 4(r20)			/* lo */
	.endif
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

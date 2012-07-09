%verify "executed"
%verify "field already resolved"
%verify "field not yet resolved"
%verify "field cannot be resolved"
	/*
	 * 32-bit SPUT handler for objects
	 *
	 * for: sput-object
	 */
	/* op vAA, field@CCCC */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r4, 1)				/* r4<- field ref CCCC */
	slwi	r5, r4, 2			/* r5<- r4*2 */
#ifndef KEEP_RES_FIELDS_IN_REGS
	lwz	r6, offGlue_methodClassDex(rGLUE)	/* r3<- DvmDex */
	lwz	r6, offDvmDex_pResFields(r6)	/* r6<- pDvmDex->pResFields */
	lwzx	r3, r6, r5			/* r3<- resolved StaticField ptr */
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
0:	lwzx	r4, r19, rFP			/* r3<- fp[A] */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	stw	r4, offStaticField_value(r3)	/* field<- vAA */
	lwz	r20, offField_clazz(r3)
	lwz	r5, offGlue_cardTable(rGLUE)	/* r5<- card table base */
	rlwinm	r20, r20, 32-GC_CARD_SHIFT, GC_CARD_SHIFT, 31
	cmpwi	r4, 0				/* stored a null reference ? */
	beq- 1f
	stbx	r5, r5, r20			/* mark card if not zero */
1:
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

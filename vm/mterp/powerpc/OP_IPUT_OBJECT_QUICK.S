%verify "executed"
%verify "null object"
	/* For: iput-object-quick */
	/* op vA, vB, offset@CCCC */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r5,rINST,22,10,29		/* r3<- B << 2 */
	FETCH(r4, 1)				/* r4<- field byte offset */
	GET_VREG_S(r6, r5)			/* r6<- object we're operating on */
	cmpwi	r6, 0				/* check object for null */
	beq-	common_errNullObject		/* object was null */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_VREG_S(r3, r19)			/* fp[A]<- r3 */
	stwx	r3, r6, r4			/* obj.field (always 32 bits) <- r3 */
	lwz	r5, offGlue_cardTable(rGLUE)	/* r5<- card table base */
	rlwinm	r6, r6, 32-GC_CARD_SHIFT, GC_CARD_SHIFT, 31
	cmpwi	r3, 0				/* stored a null reference ? */
	beq- 1f
	stbx	r5, r5, r6			/* mark card if not zero */
1:
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

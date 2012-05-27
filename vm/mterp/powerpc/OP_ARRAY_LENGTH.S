%verify "executed"
	/*
	 * Return the length of an array.
	 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r6)			/* r3<- vB */
	cmpwi	r3, 0				/* is object null? */
	beq-	common_errNullObject		/* yup, fail */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	lwz	r3, offArrayObject_length(r3)	/* r3<- array length */
	SET_VREG_S(r3, r19)			/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

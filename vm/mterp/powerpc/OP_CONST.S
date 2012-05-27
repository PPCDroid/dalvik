%verify "executed"
	/* const vAA, #+BBBBbbbb */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	FETCH(r3, 1)				/* r3<- bbbb (low) */
	FETCH(r4, 2)				/* r4<- BBBB (high) */
	FETCH_ADVANCE_INST(3)			/* advance rPC, load rINST */
	rotlwi	r4, r4, 16			/* rotate */
	or	r3, r3, r4			/* r3<- BBBBbbbb */
	SET_VREG_S(r3, r19)			/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

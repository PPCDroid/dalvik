%verify "executed"
	/* const-wide/16 vAA, #+BBBB */
	FETCH_S(r4, 1)				/* r4<- ssssBBBB (sign-extended) */
	rlwinm	r6,rINST,26,6,29		/* r6<- AA << 2 */
	srawi	r3, r4, 31			/* r3<- ssssssss */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	add	r6, rFP, r6			/* r6<- &fp[AA] */
	stw	r3, 0(r6)			/* vAA<- r3/r4 */
	stw	r4, 4(r6)
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

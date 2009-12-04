%verify "executed"
	/* const-wide/high16 vAA, #+BBBB000000000000 */
	FETCH_S(r3, 1)				/* r3<- ssssBBBB (sign-extended) */
	rlwinm	r6,rINST,26,6,29		/* r6<- AA << 2 */
	slwi	r3, r3, 16			/* r3<- BBBB0000 */
	li	r4, 0				/* r4<- 00000000 */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	add	r6, rFP, r6			/* r6<- &fp[AA] */
	stw	r3, 0(r6)			/* vAA<- r3/r4 */
	stw	r4, 4(r6)
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

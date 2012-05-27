%verify "executed"
	/* const/high16 vAA, #+BBBB0000 */
	FETCH(r3, 1)				/* r3<- 0000BBBB (zero-extended) */
	rlwinm  r6,rINST,26,6,29		/* r6<- AA << 2 */
	slwi	r3, r3, 16			/* r3<- BBBB0000 */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	SET_VREG_S(r3, r6)			/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

%verify "executed"
	/* unop vA, vB */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	rlwinm  r7,rINST,26,26,29		/* r7<- (A+ & 15) << 2 */
	GET_VREG_D_S(f1, r6)			/* f1<- vB/vB+1 */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	SET_VREG_F_S(f1, r7)			/* vAA <- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

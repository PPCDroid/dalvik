%verify "executed"
	/* for move, move-object, long-to-int */
	/* op vA, vB */
	rlwinm  r4,rINST,22,10,29		/* r6<- B << 2 */
	rlwinm  r3,rINST,26,26,29		/* r7<- (A+ & 15) << 2 */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	GET_VREG_S(r5, r4)			/* r5<- fp[B] */
	SET_VREG_S(r5, r3)			/* fp[A]<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* r0<- opcode from rINST & exec */


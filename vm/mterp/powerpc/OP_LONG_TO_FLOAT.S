%verify "executed"
	/* long-to-float vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r5<- B << 2 */
	lwzux	r3, r6, rFP			/* r3<- vB, r6<- &fp[B] */
	lwz	r4, 4(r6)			/* r4<- vB+1, r5/r6<- vB/vB+1 */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	bl	__floatdisf@plt			/* f1<- (float)(r3/r4) */
	SET_VREG_F_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

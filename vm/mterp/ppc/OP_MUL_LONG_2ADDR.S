%verify "executed"
	/*
	 * Signed 64-bit integer multiply, "/2addr" version.
	 *
	 * See OP_MUL_LONG for an explanation.
	 *
	 */
	/* binop/2addr vA, vB */
	rlwinm  r7,rINST,26,26,29		/* r7<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */

	lwzux	r3, r7, rFP			/* r3<- vA, r5<- &fp[A] */
	lwz	r4, 4(r7)			/* r4<- vA+1, r3/r4<- vA/vA+1 */
	lwzux	r5, r6, rFP			/* r5<- vB, r6<- &fp[B] */
	lwz	r6, 4(r6)			/* r6<- vB+1, r5/r6<- vB/vB+1 */

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	mullw	r8,r5,r4			/* perform 64 bit multiplication */
	mullw	r3,r3,r6
	mulhwu	r9,r6,r4
	mullw	r4,r6,r4
	add	r0,r8,r3
	add	r3,r0,r9

	stw	r3, 0(r7)			/* vAA<- r3, r7<- &fp[A] */
	stw	r4, 4(r7)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

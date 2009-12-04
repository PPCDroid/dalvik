%verify "executed"
	/*
	 * Signed 64-bit integer multiply.
	 */
	/* mul-long vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r7,rINST,26,6,29		/* r7<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	lwzux	r5, r6, rFP			/* r5<- vCC, r6<- &fp[CC] */
	lwz	r6, 4(r6)			/* r6<- vCC+1, r5/r6<- vCC/vCC+1 */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	mullw	r8,r5,r4			/* perform 64 bit multiplication */
	mullw	r3,r3,r6
	mulhwu	r9,r6,r4
	mullw	r4,r6,r4
	add	r0,r8,r3
	add	r3,r0,r9

	stwux	r3, r7, rFP			/* vAA<- r3, r7<- &fp[AA] */
	stw	r4, 4(r7)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

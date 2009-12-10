%verify "executed"
%verify "basic lt, gt, eq"
%verify "hi equal, lo <=>"
%verify "lo equal, hi <=>"
	/*
	 * Compare two 64-bit values.  Puts 0, 1, or -1 into the destination
	 * register based on the results of the comparison.
	 */
	/* cmp-long vAA, vBB, vCC */

	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	lwzux	r5, r6, rFP			/* r5<- vCC, r6<- &fp[CC] */
	lwz	r6, 4(r6)			/* r6<- vCC+1, r5/r6<- vCC/vCC+1 */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	/* comparing high half of the long */
	cmpw	r3,r5
	beq 	0f
	li	r3,1
	bge	1f
	neg	r3,r3
	b	1f				/* done */
	/* perform branch-less (unsigned) r4 > r6 ? 1 : (r4 < r6 ? -1 : 0) */
0:	subf	r5, r6, r4
	subfc	r8, r4, r6 
	subfe	r9, r6, r4 
	subfe	r3, r9, r5 
1:
	SET_VREG_S(r3, r19)			/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

%verify "executed"
	/* move-wide vA, vB */
	/* NOTE: regs can overlap, e.g. "move v6,v7" or "move v7,v6" */
	rlwinm  r5,rINST,26,26,29		/* r5<- A(+) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	add     r6, rFP, r6			/* r6<- &fp[B] */
	add     r5, rFP, r5			/* r5<- &fp[A] */
	lwz	r3, 0(r6)			/* r3/r4<- fp[B] */
	lwz	r4, 4(r6)
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	stw	r3, 0(r5)			/* fp[A]<- r3/r4 */
	stw	r4, 4(r5)
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


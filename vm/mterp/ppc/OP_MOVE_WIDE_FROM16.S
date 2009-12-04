%verify "executed"
	/* move-wide/from16 vAA, vBBBB */
	/* NOTE: regs can overlap, e.g. "move v6,v7" or "move v7,v6" */
	FETCH(r6, 1)				/* r6<- BBBB */
	rlwinm  r5,rINST,26,6,29		/* r2<- AA << 2 */
	slwi	r6, r6, 2			/* r6 <<= 2 */
	add     r5, rFP, r5			/* r5<- &fp[AA] */
	add     r6, rFP, r6			/* r6<- &fp[BBBB] */
	lwz	r3, 0(r6)			/* r3/r4<- fp[BBBB] */
	lwz	r4, 4(r6)
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	stw	r3, 0(r5)			/* fp[AA]<- r3/r4 */
	stw	r4, 4(r5)
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

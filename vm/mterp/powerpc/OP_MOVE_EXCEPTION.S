%verify "executed"
	/* move-exception vAA */
	lwz	r3, offGlue_self(rGLUE)		/* r3<- glue->self */
	rlwinm	r5, rINST, 26, 6, 29		/* r5<- AA << 2 */
	lwz	r6, offThread_exception(r3)	/* r6<- dvmGetException bypass */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	li	r4, 0				/* r4<- 0 */
	SET_VREG_S(r6, r5)			/* fp[AA]<- exception obj */
	stw	r4, offThread_exception(r3)	/* dvmClearException bypass */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


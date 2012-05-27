%verify "executed"
	/* for: move-result, move-result-object */
	/* op vAA */
	rlwinm  r5,rINST,26,6,29		/* r2<- AA << 2 */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	lwz	r3, offGlue_retval(rGLUE)	/* r3<- glue->retval.i */
	SET_VREG_S(r3, r5)			/* fp[AA]<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */


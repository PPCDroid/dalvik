%verify "executed"
	/* move-result-wide vAA */
	rlwinm  r5,rINST,26,6,29		/* r5<- AA << 2 */
	addi	r6, rGLUE, offGlue_retval	/* r3<- &glue->retval */
	add	r5, rFP, r5			/* r5<- &fp[AA] */
	lwz	r3, offGlue_retval(rGLUE)	/* r3/r4<- retval.j */
	lwz	r4, offGlue_retval+4(rGLUE)
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	stw	r3, 0(r5)			/* fp[AA]<- r3/r4 */
	stw	r4, 4(r5)
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

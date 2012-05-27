%verify "executed"
	/*
	 * Return a 64-bit value.  Copies the return value into the "glue"
	 * structure, then jumps to the return handler.
	 */
	/* return-wide vAA */
	rlwinm  r5,rINST,26,6,29		/* r5<- AA << 2*/
	add     r5, rFP, r5			/* r5<- &fp[AA] */
	lwz	r3, 0(r5)			/* r3/r4 <- vAA/vAA+1 */
	lwz	r4, 4(r5)
	stw	r3, offGlue_retval(rGLUE)	/* retval<- r3/r4 */
	stw	r4, offGlue_retval+4(rGLUE)
	b	common_returnFromMethod

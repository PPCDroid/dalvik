%verify "executed"
	/*
	 * Return a 32-bit value.  Copies the return value into the "glue"
	 * structure, then jumps to the return handler.
	 *
	 * for: return, return-object
	 */
	/* op vAA */
	rlwinm  r5,rINST,26,6,29		/* r5<- AA << 2*/
	GET_VREG_S(r3, r5)			/* r0<- vAA */
	stw	r3, offGlue_retval(rGLUE)	/* retval.i <- vAA */
	b	common_returnFromMethod

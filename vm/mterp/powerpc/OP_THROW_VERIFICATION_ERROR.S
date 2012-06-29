%verify executed
	/*
	 * Handle a throw-verification-error instruction.  This throws an
	 * exception for an error discovered during verification.  The
	 * exception is indicated by AA, with some detail provided by BBBB.
	 */
	/* throw-verification-error AA, ref@BBBB */
	rlwinm  r4,rINST,24,24,31		/* r4<- AA */
	lwz	r3, offGlue_method(rGLUE)	/* r3<- glue->method */
	FETCH(r5, 1)				/* r5<- BBBB */
	EXPORT_PC()				/* export the PC */
	bl	dvmThrowVerificationError@plt	/* always throws */
	b	common_exceptionThrown		/* handle exception */

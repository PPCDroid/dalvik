%verify "executed"
%verify "exception for null object"
	/*
	 * Throw an exception object in the current thread.
	 */
	/* throw vAA */
	rlwinm  r5,rINST,26,6,29		/* r5<- AA */
	GET_VREG_S(r4, r5)			/* r4<- vAA (exception object) */
	lwz	r3, offGlue_self(rGLUE)		/* r3<- glue->self */
	cmpwi	r4, 0				/* null object? */
	beq-	common_errNullObject		/* yes, throw an NPE instead */
	/* bypass dvmSetException, just store it */
	stw	r4, offThread_exception(r3)	/* thread->exception<- obj */
	b	common_exceptionThrown

%verify "executed"
%verify "exception for null object"
	/*
	 * Synchronize on an object.
	 */
	/* monitor-enter vAA */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	GET_VREG_S(r4, r19)			/* r4<- vAA (object) */
	lwz	r3, offGlue_self(rGLUE)		/* r3<- glue->self */
	cmpwi	r4, 0				/* null object? */
#ifdef WITH_MONITOR_TRACKING
	EXPORT_PC()				/* export PC so we can grab stack trace */
#endif
	beq-	common_errNullObject		/* null object, throw an exception */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	bl	dvmLockObject@plt		/* call(self, obj) */
#ifdef WITH_DEADLOCK_PREDICTION /* implies WITH_MONITOR_TRACKING */
	lwz	r3, offGlue_self(rGLUE)		/* r3<- glue->self */
	lwz	r4, offThread_exception(r3)	/* check for exception */
	cmpwi	r4, 0
	bne-	common_exceptionThrown		/* exception raised, bail out */
#endif
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

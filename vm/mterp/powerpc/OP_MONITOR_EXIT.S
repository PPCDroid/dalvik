%verify "executed"
%verify "exception for null object (impossible in javac)"
%verify "dvmUnlockObject fails"
	/*
	 * Unlock an object.
	 *
	 * Exceptions that occur when unlocking a monitor need to appear as
	 * if they happened at the following instruction.  See the Dalvik
	 * instruction spec.
	 */
	/* monitor-exit vAA */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	EXPORT_PC()				/* before fetch: export the PC */
	GET_VREG_S(r4, r19)			/* r4<- vAA (object) */
	cmpwi	r4, 0				/* null object? */
	beq-	1f
	lwz	r3, offGlue_self(rGLUE)		/* r3<- glue->self */
	bl	dvmUnlockObject@plt		/* call(self, obj) */
	cmpwi	r3, 0				/* failed? */
	FETCH_ADVANCE_INST(1)			/* before throw: advance rPC, load rINST */
	beq-	common_exceptionThrown		/* yes, exception is pending */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */
1:
	FETCH_ADVANCE_INST(1)			/* advance before throw */
	beq-	common_errNullObject

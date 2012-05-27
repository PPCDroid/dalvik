%default {"preinstr":"", "postinstr":"", "result":"r3"}
	/*
	 * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit16, rsub-int, mul-int/lit16, and-int/lit16, or-int/lit16,
	 *	xor-int/lit16
	 *
	 */
	/* binop/lit16 vA, vB, #+CCCC */
	FETCH_S(r4, 1)				/* r6<- ssssCCCC (sign-extended) */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	$preinstr				/* optional op; may set condition codes */
	$instr					/* $result<- op, r3-r6 changed */
	$postinstr				/* optional op; more space */
	SET_VREG_S($result, r19)		/* vAA<- $result */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


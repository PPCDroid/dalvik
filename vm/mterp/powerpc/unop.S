%default {"preinstr":""}
	/*
	 * Generic 32-bit unary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = op r0".
	 * This could be an ARM instruction or a function call.
	 *
	 * for: neg-int, not-int, int-to-byte, int-to-char, int-to-short
	 *
	 * missing: neg-float, int-to-float, float-to-int
	 */
	/* unop vA, vB */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	$preinstr				/* optional op; may set condition codes */
	$instr					/* r0<- op, r0-r3 changed */
	SET_VREG_S(r3, r19)			/* vAA<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

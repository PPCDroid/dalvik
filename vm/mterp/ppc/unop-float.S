%default {"preinstr":""}
	/*
	 * Generic float unary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = op r0".
	 *
	 */
	/* unop vA, vB */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_F_S(f1, r5)			/* f1<- vBB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	$preinstr				/* optional op; may set condition codes */
	$instr					/* r0<- op, r0-r3 changed */
	SET_VREG_F_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

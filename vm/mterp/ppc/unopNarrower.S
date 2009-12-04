%default {"preinstr":""}
	/*
	 * Generic 64bit-to-32bit unary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = op r0/r1", where
	 * "result" is a 32-bit quantity in r0.
	 *
	 * For: long-to-float, double-to-int, double-to-float
	 */
	/* unop vA, vB */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */

	lwzux	r3, r6, rFP			/* r3<- vB, r6<- &fp[B] */
	lwz	r4, 4(r6)			/* r4<- vB+1, r5/r6<- vB/vB+1 */

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	$preinstr				/* optional op; may set condition codes */
	$instr					/* r0<- op, r0-r3 changed */
	SET_VREG_S(r3, r19)			/* vAA<- r0 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

%default {"preinstr":"", "postinstr":""}
	/*
	 * Generic 32bit-to-64bit unary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = op r0", where
	 * "result" is a 64-bit quantity in r0/r1.
	 *
	 * For: int-to-long, int-to-double, float-to-long, float-to-double
	 */
	/* unop vA, vB */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */

	GET_VREG_S(r3, r6)			/* r3<- vB */

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	$preinstr				/* optional op; may set condition codes */
	$instr					/* result<- op, r3-r6 changed */
	$postinstr				/* optional op; */

	stwux	r3, r19, rFP			/* vAA<- r3, r19<- &fp[A] */
	stw	r4, 4(r19)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

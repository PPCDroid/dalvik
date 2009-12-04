%default {"preinstr":"", "postinstr":""}
	/*
	 * Generic 64-bit unary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = op r3/r4".
	 *
	 * For: neg-long, not-long, neg-double, long-to-double, double-to-long
	 */
	/* unop vA, vB */

	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r5<- B << 2 */

	lwzux	r3, r6, rFP			/* r3<- vB, r6<- &fp[B] */
	lwz	r4, 4(r6)			/* r4<- vB+1, r5/r6<- vB/vB+1 */

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	$preinstr				/* optional op; may set condition codes */
	$instr					/* result<- op, r3-r6 changed */
	$postinstr				/* optional op; */

	stwux	r3, r19, rFP			/* vAA<- r3, r19<- &fp[A] */
	stw	r4, 4(r19)			/* vAA+1<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

%default {"preinstr":"", "postinstr":"", "result0":"r0", "result1":"r1", "chkzero":"0"}
	/*
	 * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0-r1 op r2-r3".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
	 *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
	 *      sub-double/2addr, mul-double/2addr, div-double/2addr,
	 *      rem-double/2addr
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */

	lwzux	r3, r19, rFP			/* r3<- vA, r19<- &fp[A] */
	lwz	r4, 4(r19)			/* r4<- vA+1, r3/r4<- vA/vA+1 */
	lwzux	r5, r6, rFP			/* r5<- vB, r6<- &fp[B] */
	lwz	r6, 4(r6)			/* r6<- vB+1, r5/r6<- vB/vB+1 */

	.if $chkzero
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	$preinstr				/* optional op; may set condition codes */
	$instr					/* result<- op, r3-r6 changed */
	$postinstr				/* optional op; */

	stw	r3, 0(r19)			/* vAA<- $result0, r19<- &fp[A] */
	stw	r4, 4(r19)			/* vAA+1<- $result1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

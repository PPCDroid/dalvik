%default {"preinstr":"", "postinstr":"", "result0":"r3", "result1":"r4", "chkzero":"0"}
	/*
	 * Generic 64-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: add-long, sub-long, and-long, or-long, xor-long
	*/
	/* binopWide vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	lwzux	r5, r6, rFP			/* r5<- vCC, r6<- &fp[CC] */
	lwz	r6, 4(r6)			/* r6<- vCC+1, r5/r6<- vCC/vCC+1 */

	.if $chkzero
	or.	r0, r5, r6			/* second arg (r5-r6) is zero? */
	beq-	common_errDivideByZero
	.endif

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	$preinstr				/* optional op; may set condition codes */
	$instr					/* result<- op, r3-r6 changed */
	$postinstr				/* optional op; */

	stwux	r3, r19, rFP			/* vAA<- $result0, r19<- &fp[AA] */
	stw	r4, 4(r19)			/* vAA+1<- $result1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

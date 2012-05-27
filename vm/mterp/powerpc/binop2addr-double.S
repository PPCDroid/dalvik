%default {"preinstr":"", "postinstr":"", "result":"r3"}
	/*
	 * Generic double "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_D_S(f1, r19)			/* f1<- vA */
	GET_VREG_D_S(f2, r6)			/* f2<- vB */

	b .L${opcode}_split

%break

.L${opcode}_split:

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	$preinstr				/* optional op; may set condition codes */
	$instr					/* result<- op, r3-r6 changed */
	$postinstr				/* optional op; more space */
	SET_VREG_D_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

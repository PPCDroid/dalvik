%default {"preinstr":"", "postinstr":"", "result":"r3"}
	/*
	 * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int/2addr, sub-int/2addr, and-int/2addr, or-int/2addr,
	 * 	xor-int/2addr, shl-int/2addr, shr-int/2addr, ushr-int/2addr,
	 *	mul-int/2addr,
	 */
	/* binop/2addr vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_S(r3, r19)			/* r3<- vA */
	GET_VREG_S(r4, r6)			/* r4<- vB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

	$preinstr				/* optional op; may set condition codes */
	$instr					/* $result<- op, r3-r6 changed */
	$postinstr				/* optional op; more space */
	SET_VREG_S($result, r19)		/* vAA<- $result */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

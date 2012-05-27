%default {"preinstr":"", "postinstr":"", "result":"r3"}
	/*
	 * Generic 32-bit "lit8" binary operation.  Provide an "instr" line
	 * that specifies an instruction that performs "result = r0 op r1".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r0, you can override "result".)
	 *
	 * For: add-int/lit8, rsub-int/lit8, mul-int/lit8, and-int/lit8,
	 *	or-int/lit8, xor-int/lit8, shl-int/lit8, shr-int/lit8,
	 *	ushr-int/lit8
	 *
	 */
	/* binop/lit8 vAA, vBB, #+CC */
	FETCH_S(r6, 1)				/* r6<- ssssCCBB (sign-extended for CC) */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm  r5,r6,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	srawi	r4, r6, 8			/* r4<- ssssssCC (sign extended) */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	$preinstr				/* optional op; may set condition codes */
	$instr					/* $result<- op, r3-r6 changed */
	$postinstr				/* optional op; more space */
	SET_VREG_S($result, r19)		/* vAA<- $result */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


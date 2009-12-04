%default {"preinstr":"", "postinstr":"", "result":"r3"}
	/*
	 * Generic 32-bit binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3 op r4".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	$preinstr				/* optional op; may set condition codes */
	$instr					/* $result<- op, r3-r6 changed */
	$postinstr				/* optional op; more space */
	SET_VREG_S($result, r19)		/* vAA<- $result */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

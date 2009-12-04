%default {"preinstr":"", "postinstr":"", "result":"f3"}
	/*
	 * Generic double binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = f3 op f4".
	 *
	 * For: add-int, sub-int, and-int, or-int, xor-int, shl-int, shr-int,
	 * 	ushr-int, mul-int
	 */

	/* binop vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_D_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_D_S(f1, r5)			/* f1<- vBB+1 */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	$preinstr				/* optional op; may set condition codes */
	$instr					/* $result<- op, r3-r6 changed */
	$postinstr				/* optional op; more space */

	SET_VREG_D_S(f1, r19)			/* vAA/vAA+1<- f1 */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

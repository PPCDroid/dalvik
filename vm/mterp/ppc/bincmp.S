%verify "branch taken"
%verify "branch not taken"
	/*
	 * Generic two-operand compare-and-branch operation.  Provide a "revcmp"
	 * fragment that specifies the *reverse* comparison to perform, e.g.
	 * for "if-le" you would use "gt".
	 *
	 * For: if-eq, if-ne, if-lt, if-ge, if-gt, if-le
	 */
	/* if-cmp vA, vB, +CCCC */
	rlwinm  r3,rINST,26,26,29		/* r3<- (A+ & 15) << 2 */
	rlwinm  r4,rINST,22,10,29		/* r4<- B << 2 */
	GET_VREG_S(r5, r3)			/* r5<- vA */
	GET_VREG_S(r6, r4)			/* r6<- vB */
	li	r11, 4				/* r11<- BYTE branch dist for not-taken */
	cmpw	r5, r6				/* compare (vA, vB) */
	b${revcmp}	1f			/* branch to 1 if comparison failed */
	FETCH_S(r11, 1)				/* r11<- branch offset, in code units */
	slwi.	r11, r11, 1			/* convert to bytes, check sign */
 	blt-	common_backwardBranch		/* yes, do periodic checks */
1:	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

%default {"divide":"1"}
	/*
	 * For: div-int/lit16, rem-int/lit16
	 */
	/* binop/lit16 vA, vB, #+CCCC */
	FETCH_S(r4, 1)				/* r6<- ssssCCCC (sign-extended) */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r4, 0				/* r4 == 0 ? */
	beq-	common_errDivideByZero		/* divide by zero error */
	lis	r5, 0x8000			/* r5<- 0x80000000 */
	cmpw	r3, r5				/* compare with r3 */
	bne+	1f				/* no, normal division */
	cmpwi	r4, -1				/* compare with -1 */
	bne+	1f				/* no, normal division */
	.if $divide
	mr	r7, r3				/* division */
	.else
	li	r7, 0				/* remainder, 0 */
	.endif
	b	2f				/* and skip */
1:	divw	r7, r3, r4			/* divide */
	.if (! $divide)
	mullw	r7, r7, r4			/* compute remainder */
	subf	r7, r7, r3
	.endif
2:
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	SET_VREG_S(r7, r19)			/* vAA<- r7 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */


%default { "naninst":"li	r3, -1" }
%verify "executed"
%verify "basic lt, gt, eq */
%verify "left arg NaN"
%verify "right arg NaN"
	/*
	 * Compare two floating-point values.  Puts 0, 1, or -1 into the
	 * destination register based on the results of the comparison.
	 *
	 * Provide a "naninst" instruction that puts 1 or -1 into r3 depending
	 * on what value we'd like to return when one of the operands is NaN.
	 *
	 * The operation we're implementing is:
	 *   if (x == y)
	 *     return 0;
	 *   else if (x < y)
	 *     return -1;
	 *   else if (x > y)
	 *     return 1;
	 *   else
	 *     return {-1,1};  // one or both operands was NaN
	 *
	 * for: cmpl-double, cmpg-double
	 */
	/* op vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	GET_VREG_D_S(f2, r6)			/* f2<- vCC+1 */
	GET_VREG_D_S(f1, r5)			/* f1<- vBB+1 */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	fcmpu	cr7, f1, f2			/* compare f1, f2 */
	li	r3, -1				/* set result if following comparison true */
	blt-	cr7, 0f				/* branch on f1 < f2 */
	li	r3, 1				/* set result if following comparison true */
	bgt-	cr7, 0f				/* branch on f1 > f2 */
	li	r3, 0				/* set result if following comparison true */
	beq-	cr7, 0f				/* branch on f1 == f2 */
	$naninst				/* either f1 or f2 is a NaN */
0:
	SET_VREG_S(r3, r19)			/* vAA<- e3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

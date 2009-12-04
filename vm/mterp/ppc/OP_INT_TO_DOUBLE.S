%verify "executed"
	/* int-to-double vA, vB */
	rlwinm  r5,rINST,22,10,29		/* r5<- B << 2 */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	GET_VREG_S(r3, r5)			/* r3<- vBB */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	addi	r1, r1, -32			/* make workspace on stack (8 words) */
#ifndef KEEP_INT_ADJUST_IN_REG
	lis	r5, 0x5980			/* r5<- new magic value */
	ori	r5, r5, 0x0004
	stw	r5, 4(r1)			/* store magic value */
#endif
	xoris	r4, r3, 0x8000			/* r4<- r3 with toggled sign */
	lis	r3, 0x4330			/* r3<- magic value */
	stw	r3, 8(r1)			/* store double prefix */
	stw	r4, 12(r1)			/* store constructed double value */
	lfd	f2, 8(r1)			/* f2<- constructed double value */
#ifndef KEEP_INT_ADJUST_IN_REG
	lfs	f0, 4(r1)			/* f0<- constructed const value */
	fsub	f1, f2, f0			/* f1<- constructed double value - adjust */
#else
	fsub	f1, f2, fIntAdj			/* f1<- constructed double value - adjust */
#endif
	addi	r1, r1, 32			/* clean workspace */
	SET_VREG_D_S(f1, r19)			/* vAA<- f1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

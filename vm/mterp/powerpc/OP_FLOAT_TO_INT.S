%verify "executed"
	/* float-to-int vA, vB */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	rlwinm  r7,rINST,26,26,29		/* r7<- (A+ & 15) << 2 */
	GET_VREG_F_S(f1, r6)			/* f1<- vB */
#ifndef KEEP_MAX_MIN_INT_IN_REGS
	lis	r5, .L${opcode}_table@ha	/* r5<- start of constant table */
	addi	r5, r5, .L${opcode}_table@l
	lfs	f0, 0(r5)			/* f0<- max-int in float format */
	lfs	f2, 4(r5)			/* f2<- min-int in float format */
	fcmpu	cr0, f1, f0			/* compare f1 with max int */
	bun-	.L${opcode}_store_zero		/* if f1 is NaN */
	bgt-	.L${opcode}_store_max_int	/* >=, store */
	beq-	.L${opcode}_store_max_int	/* =, store */
	fcmpu	cr0, f1, f2			/* compare f1 with min int */
	blt-	.L${opcode}_store_min_int	/* <=, store */
	beq-	.L${opcode}_store_min_int	/* <=, store */
#else
	fcmpu	cr0, f1, fMaxInt		/* compare f1 with max int */
	bun-	.L${opcode}_store_zero		/* if f1 is NaN */
	bgt-	.L${opcode}_store_max_int	/* >=, store */
	beq-	.L${opcode}_store_max_int	/* =, store */
	fcmpu	cr0, f1, fMinInt		/* compare f1 with min int */
	blt-	.L${opcode}_store_min_int	/* <=, store */
	beq-	.L${opcode}_store_min_int	/* <=, store */
#endif
	fctiwz	f0, f1				/* convert to integer */
	stfiwx	f0, r7, rFP			/* store */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */
%break

#ifndef KEEP_MAX_MIN_INT_IN_REGS
.L${opcode}_table:
	.float	 2147483647	/* max-int */
	.float	-2147483648	/* min-int */
#endif

.L${opcode}_store_zero:
	li	r3, 0				/* r3<- 0 */
	b	0f
.L${opcode}_store_min_int:
	lis	r3, 0x8000			/* r3<- min-int */
	b	0f
.L${opcode}_store_max_int:
	lis	r3, 0x7fff			/* r3<- max-int */
	ori	r3, r3, 0xffff
	/* fallthrough */
0:
	SET_VREG_S(r3, r7)			/* store to register */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

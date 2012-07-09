%verify "executed"
	/* float-to-long vA, vB */
	rlwinm  r19,rINST,26,26,29		/* r19<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */
	GET_VREG_F_S(f1, r6)			/* f1<- vB */
#ifndef KEEP_MAX_MIN_LONG_IN_REGS
	lis	r5, .L${opcode}_table@ha	/* r5<- start of constant table */
	addi	r5, r5, .L${opcode}_table@l
	lfs	f0, 0(r5)			/* f0<- max-long in float format */
	lfs	f2, 4(r5)			/* f2<- min-long in float format */
	fcmpu	cr0, f1, f0			/* compare f1 with max long */
	bun-	.L${opcode}_store_zero		/* f1 is NaN */
	bgt-	.L${opcode}_store_max_int	/* >, store */
	beq-	.L${opcode}_store_max_int	/* ==, store */
	fcmpu	cr0, f1, f2			/* compare f1 with min long */
	blt-	.L${opcode}_store_min_int	/* <, store */
	beq-	.L${opcode}_store_min_int	/* ==, store */
#else
	fcmpu	cr0, f1, fMaxLong		/* compare f1 with max long */
	bun-	.L${opcode}_store_zero		/* f1 is NaN */
	bgt-	.L${opcode}_store_max_int	/* >, store */
	beq-	.L${opcode}_store_max_int	/* ==, store */
	fcmpu	cr0, f1, fMinLong		/* compare f1 with min long */
	blt-	.L${opcode}_store_min_int	/* <, store */
	beq-	.L${opcode}_store_min_int	/* ==, store */
#endif
	bl	__fixsfdi@plt			/* pass to std library */
	stwux	r3, r19, rFP			/* store to register (hi) */
	stw	r4, 4(r19)			/* lo */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */
%break

#ifndef KEEP_MAX_MIN_LONG_IN_REGS
	.align	4
.L${opcode}_table:
	.float	9223372036854775807	/* max-long */
	.float -9223372036854775808	/* min-long */
#endif

.L${opcode}_store_zero:
	li	r3, 0				/* r3/r4<- 0 */
	li	r4, 0
	b	.L${opcode}_store_int
.L${opcode}_store_min_int:
	lis	r3, 0x8000			/* r3/r4<- min-long */
	li	r4, 0
	b	.L${opcode}_store_int
.L${opcode}_store_max_int:
	lis	r3, 0x7fff			/* r3/r4<- max-long */
	ori	r3, r3, 0xffff
	li	r4, -1
	/* fallthrough */
.L${opcode}_store_int:
	stwux	r3, r19, rFP			/* store to register (hi) */
	stw	r4, 4(r19)			/* lo */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

%verify "executed"
%verify "exception handled"
	/*
	 * Execute a "native inline" instruction.
	 *
	 * We need to call:
	 *  bool (func)(u4 arg0, u4 arg1, u4 arg2, u4 arg3, JValue* pResult)
	 */
	/* [opt] execute-inline vAA, {vC, vD, vE, vF}, inline@BBBB */
	FETCH(r19, 1)				/* r19<- BBBB */
	FETCH(r20, 2)				/* r20<- FEDC */
	EXPORT_PC()				/* can throw */
	srwi	r3, rINST, 12			/* r3<- B */
	subfic	r3, r3, 4			/* r3<- 4-r3 */
	lis	r6, .L${opcode}_continue@ha	/* r6<- start of insn block */
	addi	r6, r6, .L${opcode}_continue@l
	slwi	r3, r3, 3			/* 2 insn  */
	add	r0, r6, r3			/* point to first insn of switch */
	mtctr	r0
	bctrl					/* branch & link */
	cmpwi	r3, 0				/* test boolean result of inline */
	beq-	common_exceptionThrown		/* returned false, handle exception */
	FETCH_ADVANCE_INST(3)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

%break

.L${opcode}_continue:
4:	rlwinm	r6, r20, 22, 26, 29		/* r6 = (FEDC & 0xf000) >> 10 */
	lwzx	r6, rFP, r6			/* r6<- vF (shift right 12, left 2) */
3:	rlwinm	r5, r20, 26, 26, 29		/* r6 = (FEDC & 0x0f00) >> 6) */
	lwzx	r5, rFP, r5			/* r6<- vE (shift right 8, left 2) */
2:	rlwinm	r4, r20, 30, 26, 29		/* r6 = (FEDC & 0x00f0) >> 2) */
	lwzx	r4, rFP, r4			/* r6<- vD (shift right 4, left 2) */
1:	rlwinm	r3, r20, 2, 26, 29		/* r6 = (FEDC & 0x000f) << 2) */
	lwzx	r3, rFP, r3			/* r6<- vC (shift right 0, left 2) */

	lis	r8, gDvmInlineOpsTable@ha	/* point to Inline OpsTable */
	addi	r8, r8, gDvmInlineOpsTable@l
	slwi	r9, r19, 4			/* convert * 16 */
	lwzx	r0, r8, r9			/* load func */
	addi	r7, rGLUE, offGlue_retval  	/* r7<- &glue->retval */
	mtctr	r0
	bctr					/* exec */

%verify "executed"
%verify "exception handled"
	/*
	 * Execute a "native inline" instruction, using "/range" semantics.
	 * Same idea as execute-inline, but we get the args differently.
	 *
	 * We need to call:
	 *  bool (func)(u4 arg0, u4 arg1, u4 arg2, u4 arg3, JValue* pResult)
	 */
	/* [opt] execute-inline/range {vCCCC..v(CCCC+AA-1)}, inline@BBBB */
	FETCH(r19, 1)				/* r19<- BBBB */
	FETCH(r20, 2)				/* r20<- CCCC */
	EXPORT_PC()				/* can throw */
	srwi	r3, rINST, 8			/* r3<- AA */
	subfic	r3, r3, 4			/* r3<- 4-r3 */
	slwi	r20, r20, 2			/* r20<- CCCC << 2 = vBase */
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
4:	addi	r7, r20, 12			/* base + 3 << 2 */
	lwzx	r6, rFP, r7			/* r6<- vBase[3] */
3:	addi	r7, r20, 8			/* base + 2 << 2 */
	lwzx	r4, rFP, r7			/* r5<- vBase[2] */
2:	addi	r7, r20, 4			/* base + 1 << 2 */
	lwzx	r4, rFP, r7			/* r4<- vBase[1] */
1:	addi	r7, r20, 0			/* base + 0 << 2 */
	lwzx	r3, rFP, r7			/* r3<- vBase[0] */

	lis	r8, gDvmInlineOpsTable@ha	/* point to Inline OpsTable */
	addi	r8, r8, gDvmInlineOpsTable@l
	slwi	r9, r19, 4			/* convert * 16 */
	lwzx	r0, r8, r9			/* load func */
	addi	r7, rGLUE, offGlue_retval  	/* r7<- &glue->retval */
	mtctr	r0
	bctr					/* exec */

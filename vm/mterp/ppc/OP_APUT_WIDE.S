%verify "executed"
	/*
	 * Array put, 64 bits.  vBB[vCC] <- vAA.
	 */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */
	GET_VREG_S(r4, r6)			/* r4<- vCC (requested index) */
	GET_VREG_S(r3, r5)			/* r3<- vBB */

	cmpwi	r3, 0				/* null array object? */
	beq-	common_errNullObject		/* yes, bail */
	lwz	r6, offArrayObject_length(r3)	/* r6<- arrayObj->length */
	cmplw	r4, r6				/* compare unsigned index, length */
	bge-	common_errArrayIndex		/* index >= length, bail */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	slwi	r4, r4, 3			/* r4<- index*width */
	add     r3, r3, r4			/* r3<- arrayObj + index*width */
	lwzux	r5, r19, rFP			/* r5<- */
	lwz	r6, 4(r19)			/* vAA<- */
	stw	r5, offArrayObject_contents(r3) /* r5<- vBB[vCC] hi */
	stw	r6, offArrayObject_contents+4(r3)	/* lo */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

%default { "load":"lwz", "shift":"2", "exts":"" }
%verify "executed"
	/*
	 * Array get, 32 bits or less.  vAA <- vBB[vCC].
	 *
	 * for: aget, aget-object, aget-boolean, aget-byte, aget-char, aget-short
	 */
	/* op vAA, vBB, vCC */

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

	.if $shift > 0
	slwi	r4, r4, $shift			/* r4<- index*width */
	.endif
	add     r3, r3, r4			/* r3<- arrayObj + index*width */
	$load   r5, offArrayObject_contents(r3)	/* r5<- vBB[vCC] */
	.ifnb $exts
	$exts	r5, r5				/* extend sign if requested */
	.endif

	SET_VREG_S(r5, r19)			/* vAA<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

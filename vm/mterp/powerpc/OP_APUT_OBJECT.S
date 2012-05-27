%verify "executed"
	/*
	 * Array put object
	 *
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

	/* r3 = vBB, r4 = vCC, r19 = vAA << 2 */
	slwi	r4, r4, 2			/* r4<- index*width */
	add     r20, r3, r4			/* r20<- arrayObj + index*width */
	GET_VREG_S(r19, r19)			/* vAA<- r19 */

	cmpwi	r19, 0				/* storing null reference? */
	beq-	0f				/* yes, skip type checks */
	lwz	r4, offObject_clazz(r3)		/* r4<- arrayObj->clazz */
	lwz	r3, offObject_clazz(r19)	/* r3<- obj->clazz */
	bl	dvmCanPutArrayElement@plt	/* test object type vs. array type */
	cmpwi	r3, 0				/* okay? */
	beq-	common_errArrayStore		/* no */
0:
	stw	r19, offArrayObject_contents(r20) /* r19<- vBB[vCC] */

	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

%verify "executed"
	/* const-wide/32 vAA, #+BBBBbbbb */
	FETCH(r3, 1)				/* r3<- bbbb (low) */
	rlwinm	r7,rINST,26,6,29		/* r7<- AA << 2 */
	FETCH(r4, 2)				/* r4<- BBBB (low middle) */
	add     r7, rFP, r7			/* r7<- &fp[AA] */
	rotlwi	r4, r4, 16			/* r4<- BBBB0000 */
	or	r4, r4, r3			/* r4<- BBBBbbbb (low word) */
	srawi	r3, r4, 31			/* r3<- ssssssss */
	FETCH_ADVANCE_INST(3)			/* advance rPC, load rINST */
	stw	r3, 0(r7)			/* store high word */
	stw	r4, 4(r7)			/* store low word */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

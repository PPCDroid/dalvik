%verify "executed"
	/* const-wide vAA, #+HHHHhhhhBBBBbbbb */
	FETCH(r4, 2)				/* r4<- BBBB (low middle) */
	rlwinm	r7,rINST,26,6,29		/* r7<- AA << 2 */
	FETCH(r3, 1)				/* r3<- bbbb (low) */
	rotlwi	r4, r4, 16			/* r4<- BBBB0000 */
	FETCH(r6, 4)				/* r6<- HHHH (high) */
	add     r7, rFP, r7			/* r7<- &fp[AA] */
	FETCH(r5, 3)				/* r5<- hhhh (high middle) */
	rotlwi	r6, r6, 16			/* r6<- HHHH0000 */
	or	r3, r3, r4			/* r3<- BBBBbbbb (low word) */
	or	r4, r5, r6			/* r4<- HHHHhhhh (high word) */
	FETCH_ADVANCE_INST(5)			/* advance rPC, load rINST */
	stw	r4, 0(r7)			/* store high word */
	stw	r3, 4(r7)			/* store low word */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

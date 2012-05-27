%verify "executed"
	/* fill-array-data vAA, +BBBBBBBB */
	rlwinm	r6,rINST,26,6,29		/* r6<- AA << 2 */
	FETCH(r3, 1)				/* r3<- bbbb (lo) */
	FETCH(r4, 2)				/* r4<- BBBB (hi) */
	rotlwi	r4, r4, 16			/* rotate */
	or	r4, r3, r4			/* r4<- BBBBbbbb */
	GET_VREG_S(r3, r6)			/* r3<- vAA (array object) */
	slwi	r5, r4, 1			/* r5<- BBBBbbbb << 1 */
	add	r4, rPC, r5			/* r4<- PC + BBBBbbbb*2 (array data off.) */
	EXPORT_PC()
	bl	dvmInterpHandleFillArrayData@plt	/*fill the array with predefined data */
	cmpwi	r3, 0				/* exception? */
	beq-	common_exceptionThrown		/* has exception */
	FETCH_ADVANCE_INST(3)			/* advance rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

%default { "func":"dvmInterpHandlePackedSwitch" }
%verify executed
	/*
	 * Handle a packed-switch or sparse-switch instruction.  In both cases
	 * we decode it and hand it off to a helper function.
	 *
	 * We don't really expect backward branches in a switch statement, but
	 * they're perfectly legal, so we check for them here.
	 *
	 * for: packed-switch, sparse-switch
	 */
	/* op vAA, +BBBB */
	FETCH(r3, 1)				/* r3<- bbbb (lo) */
	FETCH(r4, 2)				/* r4<- BBBB (hi) */
	rlwinm	r6,rINST,26,6,29		/* r7<- AA << 2 */
	rotlwi	r4, r4, 16			/* rotate */
	or	r3, r3, r4			/* r3<- BBBBbbbb */
	slwi	r3, r3, 1			/* r3<- BBBBbbbb* 2 */
	GET_VREG_S(r4, r6)			/* r4<- vAA */
	add     r3, rPC, r3			/* r3<- PC + BBBBbbbb*2 */
	bl      $func				/* r3<- code-unit branch offset */
	slwi	r11, r3, 1			/* r11<- branch byte offset, check sign */
	cmpwi	r3, 0				/* compare sign */
	ble-	common_backwardBranch		/* backward branch, do periodic checks */
	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

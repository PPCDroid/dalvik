%verify "executed"
%verify "forward, backward, self"
	/*
	 * Unconditional branch, 32-bit offset.
	 *
	 * The branch distance is a signed code-unit offset, which we need to
	 * double to get a byte offset.
	 *
	 * Unlike most opcodes, this one is allowed to branch to itself, so
	 * our "backward branch" test must be "<=0" instead of "<0".
	 * explicitly.
	 */
	/* goto/32 +AAAAAAAA */
	FETCH(r3, 1)				/* r3<- aaaa (lo) */
	FETCH(r4, 2)				/* r4<- AAAA (hi) */
	rotlwi	r4, r4, 16			/* rotate */
	or	r3, r3, r4			/* r3<- AAAAaaaa */
	slwi.	r11, r3, 1			/* r11<- byte offset, check sign */
	ble-	common_backwardBranch		/* backward branch, do periodic checks */
	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

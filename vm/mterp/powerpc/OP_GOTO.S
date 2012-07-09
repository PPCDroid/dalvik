%verify "executed"
%verify "forward and backward"
	/*
	 * Unconditional branch, 8-bit offset.
	 *
	 * The branch distance is a signed code-unit offset, which we need to
	 * double to get a byte offset.
	 */
	/* goto +AA */
	slwi	r3, rINST, 16			/* r3<- AAxx0000 */
	srawi	r11, r3, 24			/* r11<- ssssssAA (sign-extended) */
	slwi.	r11, r11, 1			/* r11<- byte offset */
	ble+	common_backwardBranch		/* backward branch, do periodic checks */
	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST */

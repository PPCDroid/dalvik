%verify "executed"
%verify "forward and backward"
	/*
	* Unconditional branch, 16-bit offset.
	*
	* The branch distance is a signed code-unit offset, which we need to
	* double to get a byte offset.
	*/
	/* goto/16 +AAAA */
	FETCH_S(r3, 1)				/* r3<- ssssAAAA (sign-extended) */
	slwi.	r11, r3, 1			/* r11<- byte offset, check sign */
	blt-	common_backwardBranch		/* backward branch, do periodic checks */
	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

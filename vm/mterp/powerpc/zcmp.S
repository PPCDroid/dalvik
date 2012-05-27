%verify "branch taken"
%verify "branch not taken"
	/*
	* Generic one-operand compare-and-branch operation.  Provide a "revcmp"
	* fragment that specifies the *reverse* comparison to perform, e.g.
	* for "if-le" you would use "gt".
	*
	* for: if-eqz, if-nez, if-ltz, if-gez, if-gtz, if-lez
	*/
	/* if-cmp vAA, +BBBB */
	rlwinm	r3,rINST,26,6,29		/* r7<- AA << 2 */
	GET_VREG_S(r5, r3)			/* r5<- vA */
	li	r11, 4				/* r11<- BYTE branch dist for not-taken */
	cmpwi	r5, 0				/* compare (vA, 0) */
	b${revcmp}	1f			/* branch to 1 if comparison failed */
	FETCH_S(r11, 1)				/* r11<- branch offset, in code units */
	slwi.	r11, r11, 1			/* convert to bytes, check sign */
 	blt-	common_backwardBranch		/* yes, do periodic checks */
1:	FETCH_ADVANCE_INST_RB(r11)		/* update rPC, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & jump to next insn */

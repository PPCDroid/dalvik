%verify "executed"
	/* for: move/from16, move-object/from16 */
	/* op vAA, vBBBB */
	FETCH(r4, 1)				/* r4<- BBBB */
	rlwinm  r3,rINST,26,6,29		/* r3<- AA << 2 */
	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */
	GET_VREG(r5, r4)			/* r5<- fp[BBBB] */
	SET_VREG_S(r5, r3)			/* fp[AA]<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

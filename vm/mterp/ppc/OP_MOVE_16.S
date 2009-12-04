%verify "executed"
	/* for: move/16, move-object/16 */
	/* op vAAAA, vBBBB */
	FETCH(r4, 2)				/* r4<- BBBB */
	FETCH(r3, 1)				/* r3<- AAAA */
	FETCH_ADVANCE_INST(3)			/* advance rPC, load rINST */
	GET_VREG(r5, r4)			/* r5<- fp[BBBB] */
	SET_VREG(r5, r3)			/* fp[AAAA]<- r5 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

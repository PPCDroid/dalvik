%verify "executed"
	FETCH_ADVANCE_INST(1)			/* advance to next instr, load rINST */
	GET_INST_OPCODE_GOTO(r0)		/* r0<- opcode from rINST & exec */

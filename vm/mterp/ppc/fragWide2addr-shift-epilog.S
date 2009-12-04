%default {"result0":"r3", "result1":"r4", "shl":"0", "shr":"0", "ushr":"0" }
	stw	r3, 0(r7)			/* vA<- $result0 */
	stw	r4, 4(r7)			/* vA+1<- $result1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

%default {"result0":"r3", "result1":"r4", "shl":"0", "shr":"0", "ushr":"0" }
	stwux	r3, r7, rFP			/* vAA<- $result0, r7<- &fp[AA] */
	stw	r4, 4(r7)			/* vAA+1<- $result1 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

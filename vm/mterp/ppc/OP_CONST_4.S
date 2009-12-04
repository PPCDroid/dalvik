%verify "executed"
	/* const/4 vA, #+B */
	rlwinm  r4,rINST,16,0,15		/* r4<- Bxxx0000 */
	rlwinm  r3,rINST,26,26,29		/* r3<- A+ << 2 */
	srawi   r4,r4,28			/* r4<- sssssssB (sign-extended) */
	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */
	SET_VREG_S(r4, r3)			/* fp[A]<- r4 */
	GET_INST_OPCODE_GOTO(r0)		/* opcode from rINST & exec */

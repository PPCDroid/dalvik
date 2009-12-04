%default {"result0":"r3", "result1":"r4", "shl":"0", "shr":"0", "ushr":"0" }
	/*
	 * Generic 64-bit shift binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: shl-long, shr-long, ushr-long
	*/
	/* binopWide/2addr vA, vB */
	rlwinm  r7,rINST,26,26,29		/* r7<- (A+ & 15) << 2 */
	rlwinm  r6,rINST,22,10,29		/* r6<- B << 2 */

	lwzux	r3, r7, rFP			/* r3<- vA, r7<- &fp[A] */
	lwz	r4, 4(r7)			/* r4<- vA+1, r3/r4<- vA/vA+1 */
	GET_VREG_S(r5, r6)			/* r5<- vB */
	clrlwi	r5, r5, 26			/* r5<- r5 & 0x3f */

	FETCH_ADVANCE_INST(1)			/* advance rPC, load rINST */

%default {"result0":"r3", "result1":"r4", "shl":"0", "shr":"0", "ushr":"0" }
	/*
	 * Generic 64-bit shift binary operation.  Provide an "instr" line that
	 * specifies an instruction that performs "result = r3-r4 op r5-r6".
	 * This could be an ARM instruction or a function call.  (If the result
	 * comes back in a register other than r3, you can override "result".)
	 *
	 * for: shl-long, shr-long, ushr-long
	*/
	/* binopWide vAA, vBB, vCC */
	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r7,rINST,26,6,29		/* r7<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	GET_VREG_S(r5, r6)			/* r5<- vCC */
	clrlwi	r5, r5, 26			/* r5<- r5 & 0x3f */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

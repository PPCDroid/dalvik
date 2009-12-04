%verify "executed"
%verify "basic lt, gt, eq"
%verify "hi equal, lo <=>"
%verify "lo equal, hi <=>"
	/*
	 * Compare two 64-bit values.  Puts 0, 1, or -1 into the destination
	 * register based on the results of the comparison.
	 *
	 * We load the full values with LDM, but in practice many values could
	 * be resolved by only looking at the high word.  This could be made
	 * faster or slower by splitting the LDM into a pair of LDRs.
	 *
	 * If we just wanted to set condition flags, we could do this:
	 *  subs    ip, r0, r2
	 *  sbcs    ip, r1, r3
	 *  subeqs  ip, r0, r2
	 * Leaving { <0, 0, >0 } in ip.  However, we have to set it to a specific
	 * integer value, which we can do with 2 conditional mov/mvn instructions
	 * (set 1, set -1; if they're equal we already have 0 in ip), giving
	 * us a constant 5-cycle path plus a branch at the end to the
	 * instruction epilogue code.  The multi-compare approach below needs
	 * 2 or 3 cycles + branch if the high word doesn't match, 6 + branch
	 * in the worst case (the 64-bit values are equal).
	 */
	/* cmp-long vAA, vBB, vCC */

	FETCH(r3, 1)				/* r3<- CCBB */
	rlwinm	r19,rINST,26,6,29		/* r19<- AA << 2 */
	rlwinm	r6,r3,26,6,29			/* r6<- CC << 2 */
	rlwinm  r5,r3,2,22,29			/* r5<- BB ( = andi ,,255) << 2 */

	lwzux	r3, r5, rFP			/* r3<- vBB, r5<- &fp[BB] */
	lwz	r4, 4(r5)			/* r4<- vBB+1, r3/r4<- vBB/vBB+1 */
	lwzux	r5, r6, rFP			/* r5<- vCC, r6<- &fp[CC] */
	lwz	r6, 4(r6)			/* r6<- vCC+1, r5/r6<- vCC/vCC+1 */

	FETCH_ADVANCE_INST(2)			/* advance rPC, load rINST */

	/* perform branch-less r3 > r5 ? 1 : (r3 < r5 ? -1 : 0) */
	sub.	r0, r3, r5			/* r0<- r3 - r5 (update CR) */
	beq	0f				/* same check low order word */
	neg	r7, r0				/* r7<- -r0 */
	srawi	r4, r0, 31			/* r4<- (int)r0 >> 31 */
	srwi	r3, r7, 31			/* r3<- (unsigned int)-r0 */
	or	r3, r3, r4			/* r3<- r3 | r4 */
	b	1f				/* done */
	/* perform branch-less (unsigned) r4 > r6 ? 1 : (r4 < r6 ? -1 : 0) */
0:	subf	r5, r6, r4
	subfc	r8, r4, r6 
	subfe	r9, r6, r4 
	subfe	r3, r9, r5 
1:
	SET_VREG_S(r3, r19)			/* vAA<- r3 */
	GET_INST_OPCODE_GOTO(r0)		/* extract opcode from rINST & exec */

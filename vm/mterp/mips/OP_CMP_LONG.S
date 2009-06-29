%verify "executed"
%verify "basic lt, gt, eq"
%verify "hi equal, lo <=>"
%verify "lo equal, hi <=>"
    /*
     * Compare two 64-bit values.  Puts 0, 1, or -1 into the destination
     * register based on the results of the comparison.
     */
    /* cmp-long vAA, vBB, vCC */
    FETCH_B(a2, 1, 0)                   /* a2<- BB */
    srl     s4, rINST, 8                /* s4<- AA */
    FETCH_B(a3, 1, 1)                   /* a3<- CC */
    sll     a2, a2, 2
    addu    t5, a2, rFP                 /* t5<- &fp[BB] */
    sll     a3, a3, 2
    addu    t6, a3, rFP                 /* t6<- &fp[CC] */
    lw      a1, 4(t5)
    lw      a3, 4(t6)
    lw      a0, 0(t5)                   /* a0/a1<- vBB/vBB+1 */
    beq     a1, a3, .L${opcode}_hieq    /* high part equal */
    lw      a2, 0(t6)                   /* a2/a3<- vCC/vCC+1 */
    slt     t4, a1, a3			/* signed compare upper part */
    bgtz    t4, .L${opcode}_finish
    li      v0, -1			/* a1 < a3 */
    b       .L${opcode}_finish
    li      v0, 1			/* a1 > a3 */

.L${opcode}_hieq:
    /* High parts are equal, compare low parts */
    beq     a0, a2, .L${opcode}_finish
    move    v0, zero
    sltu    t4, a0, a2                  /* t4<- a0 - a2 */
    bgtz    t4, .L${opcode}_finish      /* unsigned compare on low part */
    li      v0, -1			/* a0 < a2 */
    b       .L${opcode}_finish
    li      v0, 1			/* a0 > a2 */

%break

.L${opcode}_finish:
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


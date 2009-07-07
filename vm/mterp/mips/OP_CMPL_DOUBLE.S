%verify "executed"
%verify "basic lt, gt, eq */
%verify "left arg NaN"
%verify "right arg NaN"
    /*
     * Compare two floating-point values.  Puts 0, 1, or -1 into the
     * destination register based on the results of the comparison.
     *
     * Provide a "naninst" instruction that puts 1 or -1 into r1 depending
     * on what value we'd like to return when one of the operands is NaN.
     *
     * See OP_CMPL_FLOAT for an explanation.
     *
     * For: cmpl-double, cmpg-double
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    andi    s4, a0, 255                 /* s4<- BB */
    srl     s5, a0, 8                   /* s5<- CC */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[BB] */
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[CC] */
    lw      a0, 0(s4)                   /* a0/a1<- vBB/vBB+1 */
    lw      a1, 4(s4)
    LA(t9, __eqdf2)
    lw      a2, 0(s5)                   /* a2/a3<- vCC/vCC+1 */
    jalr    t9
    lw      a3, 4(s5)
    beqz    v0, .L${opcode}_finish	/* Branch if equal */
    lw      a0, 0(s4)                   /* a0/a1<- vBB/vBB+1 */
    lw      a1, 4(s4)
    LA(t9, __ltdf2)
    lw      a2, 0(s5)                   /* a2/a3<- vCC/vCC+1 */
    jalr    t9
    lw      a3, 4(s5)
    bltz    v0, .L${opcode}_finish	/* Branch if less than */
    li      v0, -1
    lw      a0, 0(s4)                   /* a0/a1<- vBB/vBB+1 */
    lw      a1, 4(s4)
    LA(t9, __gtsf2)
    lw      a2, 0(s5)                   /* a2/a3<- vCC/vCC+1 */
    jalr    t9
    lw      a3, 4(s5)
    blez    v0, .L${opcode}_finish	/* Branch if NaN */
    li      v0, -1			/* NaN return */
    b       .L${opcode}_finish		/* Branch if greater */
    li      v0, 1			/* Greater than return */

%break

.L${opcode}_finish:
    srl     s4, rINST, 8                /* s4<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


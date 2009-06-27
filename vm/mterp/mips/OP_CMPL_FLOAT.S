%verify "executed"
%verify "basic lt, gt, eq */
%verify "left arg NaN"
%verify "right arg NaN"
    /*
     * Compare two floating-point values.  Puts 0, 1, or -1 into the
     * destination register based on the results of the comparison.
     *
     * The operation we're implementing is:
     *   if (x == y)
     *     return 0;
     *   else if (x < y)
     *     return -1;
     *   else if (x > y)
     *     return 1;
     *   else
     *     return {-1,1};  // one or both operands was NaN
     *
     * for: cmpl-float, cmpg-float
     * I think __eqsf2, gives me what I want, but isn't documented to do so.
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* r0<- CCBB */
    andi    t5, a0, 255                 /* t5<- BB */
    srl     t6, a0, 8                   /* t6<- CC */
    GET_VREG(s4, t5)                    /* s4<- vBB */
    GET_VREG(s5, t6)                    /* s5<- vCC */
    LA(t9, __eqsf2)
    move    a0, s4
    jalr    t9
    move    a1, s5
    beqz    v0, .L${opcode}_finish	/* Branch if equal */
    LA(t9, __ltsf2)
    move    a0, s4
    jalr    t9
    move    a1, s5
    bltz    v0, .L${opcode}_finish	/* Branch if less than */
    li      v0, -1
    LA(t9, __gtsf2)
    move    a0, s4
    jalr    t9
    move    a1, s5
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


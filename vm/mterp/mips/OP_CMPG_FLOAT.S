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
     */
    /* op vAA, vBB, vCC */
    FETCH_B(t5, 1, 0)                   /* t5<- BB */
    FETCH_B(t6, 1, 1)                   /* t6<- CC */
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

    slt     t5, v0, 0
    li      v0, -1			/* Value is less-than */
    li      v1, 1			/* Value is greater-than or NaN */
    movz    v0, v1, t5

.L${opcode}_finish:
    srl     s4, rINST, 8                /* s4<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


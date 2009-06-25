%verify "executed"
%verify "forward and backward"
    /*
     * Unconditional branch, 16-bit offset.
     *
     * The branch distance is a signed code-unit offset, which we need to
     * double to get a byte offset.
     */
    /* goto/16 +AAAA */
    FETCH_S(a0, 1)                     /* a0<- ssssAAAA (sign-extended) */
    sll     s4, a0, 1                  /* s4<- byte offset, check sign */
    bltz    s4, common_backwardBranch  /* backward branch, do periodic checks */
    nop
    FETCH_ADVANCE_INST_RB(s4)           /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


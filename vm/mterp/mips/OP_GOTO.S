%verify "executed"
%verify "forward and backward"
    /*
     * Unconditional branch, 8-bit offset.
     *
     * The branch distance is a signed code-unit offset, which we need to
     * double to get a byte offset.
     */
    /* goto +AA */
    sll     a0, rINST, 16              /* a0<- AAxx0000 */
    sra     s4, a0, 23                 /* s4<- ssssssAA. (sign-ext doubled) */
    bltz    s4, common_backwardBranch  /* backward branch, do periodic checks */
    nop
    FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */


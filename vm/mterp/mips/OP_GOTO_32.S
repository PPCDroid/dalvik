%verify "executed"
%verify "forward, backward, self"
    /*
     * Unconditional branch, 32-bit offset.
     *
     * The branch distance is a signed code-unit offset, which we need to
     * double to get a byte offset.
     *
     * Unlike most opcodes, this one is allowed to branch to itself, so
     * our "backward branch" test must be "<=0" instead of "<0".
     */
    /* goto/32 +AAAAAAAA */
    FETCH(a1, 2)                       /* a1<- AAAA (hi) */
    FETCH(a0, 1)                       /* a0<- aaaa (lo) */
    sll     a1, a1, 16
    or      a0, a0, a1                 /* a0<- AAAAaaaa, check sign */
    sll     s4, a0, 1                  /* s4<- byte offset */
    blez    s4,  common_backwardBranch /* backward branch, do periodic checks */
    FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */


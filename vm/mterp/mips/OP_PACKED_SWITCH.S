%default { "func":"dvmInterpHandlePackedSwitch" }
%verify executed
    /*
     * Handle a packed-switch or sparse-switch instruction.  In both cases
     * we decode it and hand it off to a helper function.
     *
     * We don't really expect backward branches in a switch statement, but
     * they're perfectly legal, so we check for them here.
     *
     * for: packed-switch, sparse-switch
     */
    /* op vAA, +BBBB */
    FETCH(a0, 1)                        /* a0<- bbbb (lo) */
    FETCH(a1, 2)                        /* a1<- BBBB (hi) */
    srl     a3, rINST, 8                /* a3<- AA */
    sll     a1, a1, 16
    or      a0, a0, a1                  /* a0<- BBBBbbbb */
    GET_VREG(a1, a3)                    /* a1<- vAA */
    sll     a0, a0, 1
    LA(t9,$func)
    jalr    t9                          /* a0<- code-unit branch offset */
    addu    a0, rPC, a0                 /* a0<- PC + BBBBbbbb*2 */
    sll     s4, v0, 1                  /* s4<- branch byte offset, check sign */
    blez    s4, common_backwardBranch  /* backward branch, do periodic checks */
    nop
    FETCH_ADVANCE_INST_RB(s4)           /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


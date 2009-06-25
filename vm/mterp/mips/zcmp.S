%verify "branch taken"
%verify "branch not taken"
    /*
     * Generic one-operand compare-and-branch operation.  Provide a "revcmp"
     * fragment that specifies the *reverse* comparison to perform, e.g.
     * for "if-le" you would use "gt".
     *
     * for: if-eqz, if-nez, if-ltz, if-gez, if-gtz, if-lez
     */
    /* if-cmp vAA, +BBBB */
    srl     a0, rINST, 8               /* a0<- AA */
    GET_VREG(a2, a0)                   /* a2<- vAA */
    li      s4, 4                      /* s4<- BYTE branch dist for not-taken */
    b${revcmp}  a2, 1f                 /* compare (vA, 0) */
    nop                                /* branch to 1 if comparison failed */
    FETCH_S(s4, 1)                     /* s4<- branch offset, in code units */
    sll     s4, s4, 1                  /* convert to bytes, check sign */
    bltz    s4, common_backwardBranch  /* backward branch, do periodic checks */
    nop
1:  FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */


%verify "executed"
%verify "branch taken"
%verify "branch not taken"
    /*
     * Generic two-operand compare-and-branch operation.  Provide a "revcmp"
     * fragment that specifies the *reverse* comparison to perform, e.g.
     * for "if-le" you would use "gt".
     *
     * For: if-eq, if-ne, if-lt, if-ge, if-gt, if-le
     */
    /* if-cmp vA, vB, +CCCC */
    srl     a0, rINST, 8               /* a0<- A+ */
    srl     a1, rINST, 12              /* a1<- B */
    andi    a0, a0, 15
    GET_VREG(a3, a1)                   /* a3<- vB */
    GET_VREG(a2, a0)                   /* a2<- vA */
    slt     t6, a3, a2                 /* compare vA <= vB, !(vB < vA) */
    bnez    t6, 1f                     /* we branch to 1 if not */
    li      s4, 4                      /* s4<- BYTE branch dist for not-taken */

    FETCH_S(s4, 1)                     /* s4<- branch offset, in code units */
    sll     s4, s4, 1                  /* convert to bytes, check sign */
    bltz    s4, common_backwardBranch  /* yes, do periodic checks */
    nop
1:  FETCH_ADVANCE_INST_RB(s4)          /* update rPC, load rINST */
    GET_INST_OPCODE(t7)                /* extract opcode from rINST */
    GOTO_OPCODE(t7)                    /* jump to next instruction */


%verify "executed"
    /* const/4 vA, #+B */
    sll     a1, rINST, 16               /* a1<- Bxxx0000 shift to get sign */
    srl     a0, rINST, 8                /* a0<- A+ */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    sra     a1, a1, 28                  /* a1<- sssssssB (sign-extended) */
    andi    a0, a0, 15
    GET_INST_OPCODE(t7)                 /* ip<- opcode from rINST */
    SET_VREG(a1, a0)                    /* fp[A]<- a1 */
    GOTO_OPCODE(t7)                     /* execute next instruction */


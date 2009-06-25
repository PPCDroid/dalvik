%verify "executed"
    /* const/high16 vAA, #+BBBB0000 */
    FETCH(a0, 1)                        /* a0<- 0000BBBB (zero-extended) */
    srl     a3, rINST, 8                /* a3<- AA */
    sll     a0, a0, 16                  /* a0<- BBBB0000 */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(a0, a3)                    /* vAA<- a0 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


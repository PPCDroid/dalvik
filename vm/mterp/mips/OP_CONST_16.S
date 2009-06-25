%verify "executed"
    /* const/16 vAA, #+BBBB */
    FETCH_S(a0, 1)                      /* a0<- ssssBBBB (sign-extended) */
    srl     a3, rINST, 8                /* a3<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(a0, a3)                    /* vAA<- a0 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


%verify "executed"
    /* for move, move-object, long-to-int */
    /* op vA, vB */
    srl     a1, rINST, 12               /* a1<- B from 15:12 */
    srl     a0, rINST, 8                /* a0<- A from 11:8 */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    GET_VREG(a2, a1)                    /* a2<- fp[B] */
    andi    a0, a0, 15
    GET_INST_OPCODE(t7)                 /* t7<- opcode from rINST */
    SET_VREG(a2, a0)                    /* fp[A]<- a2 */
    GOTO_OPCODE(t7)                     /* execute next instruction */


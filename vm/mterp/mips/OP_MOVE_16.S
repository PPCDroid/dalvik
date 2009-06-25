%verify "executed"
    /* for: move/16, move-object/16 */
    /* op vAAAA, vBBBB */
    FETCH(a1, 2)                        /* a1<- BBBB */
    FETCH(a0, 1)                        /* a0<- AAAA */
    FETCH_ADVANCE_INST(3)               /* advance rPC, load rINST */
    GET_VREG(a2, a1)                    /* a2<- fp[BBBB] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a2, a0)                    /* fp[AAAA]<- a2 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


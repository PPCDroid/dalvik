%verify "executed"
    /* for: move/from16, move-object/from16 */
    /* op vAA, vBBBB */
    FETCH(a1, 1)                        /* a1<- BBBB */
    srl     a0, rINST, 8                /* a0<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_VREG(a2, a1)                    /* a2<- fp[BBBB] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a2, a0)                    /* fp[AA]<- a2 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


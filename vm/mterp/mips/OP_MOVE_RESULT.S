%verify "executed"
    /* for: move-result, move-result-object */
    /* op vAA */
    srl     a2, rINST, 8                /* r2<- AA */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    lw      a0, offGlue_retval(rGLUE)   /* a0<- glue->retval.i */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a0, a2)                    /* fp[AA]<- a0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


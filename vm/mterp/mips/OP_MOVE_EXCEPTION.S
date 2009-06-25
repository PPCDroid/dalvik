%verify "executed"
    /* move-exception vAA */
    lw      a0, offGlue_self(rGLUE)     /* a0<- glue->self */
    srl     a2, rINST, 8                /* a2<- AA */
    lw      a3, offThread_exception(a0) /* a3<- dvmGetException bypass */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    SET_VREG(a3, a2)                    /* fp[AA]<- exception obj */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      zero, offThread_exception(a0)  /* dvmClearException bypass */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


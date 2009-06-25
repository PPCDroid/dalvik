%verify "executed"
    /* move-result-wide vAA */
    srl     a2, rINST, 8                /* a2<- AA */
    addiu   a3, rGLUE, offGlue_retval   /* a3<- &glue->retval */
    sll     a2, a2, 2
    addu    a2, rFP, a2                 /* a2<- &fp[AA] */
    lw      t4, 0(a3)                   /* a0/a1<- retval.j */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    lw      t5, 4(a3)
    sw      t4, 0(a2)                   /* fp[AA]<- a0/a1 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      t5, 4(a2)
    GOTO_OPCODE(t7)                     /* jump to next instruction */


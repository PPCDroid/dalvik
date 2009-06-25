    /* stub for ${opcode} */
    SAVE_PC_FP_TO_GLUE()            /* only need to export these two */
    move    gp, s8
    la      t9, dvmMterp_${opcode}  /* call */
    jalr    t9
    move    a0, rGLUE               /* glue is first arg to function */
    LOAD_PC_FP_FROM_GLUE()          /* retrieve updated values */
    FETCH_INST()                    /* load next instruction from rPC */
    GET_INST_OPCODE(t7)             /* ...trim down to just the opcode */
    GOTO_OPCODE(t7)                 /* ...and jump to the handler */

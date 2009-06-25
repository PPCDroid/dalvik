%verify "executed"
    FETCH_ADVANCE_INST(1)               /* advance to next instr, load rINST */
    GET_INST_OPCODE(t7)                 /* ip<- opcode from rINST */
    GOTO_OPCODE(t7)                     /* execute it */


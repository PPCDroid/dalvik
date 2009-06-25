%default {"preinstr":""}
    /*
     * Generic 32-bit unary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = op r0".
     * This could be an ARM instruction or a function call.
     *
     * for: neg-int, not-int, neg-float, int-to-float, float-to-int,
     *      int-to-byte, int-to-char, int-to-short
     */
    /* unop vA, vB */
    srl     a3, rINST, 12               /* a3<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a3)                    /* a0<- vB */
    andi    s4, s4, 15
    $preinstr                           /* optional op */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    $instr                              /* a0<- op, a0-a3 maybe changed */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */
    /* 9-10 instructions */

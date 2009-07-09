%default {"preinstr":""}
    /*
     * Generic 32bit-to-64bit unary operation.  Provide an "instr" line
     * that specifies an instruction that performs "v1 = op a0", where
     * "result" is a 64-bit quantity in v0/v1.
     *
     * For: int-to-long, int-to-double, float-to-long, float-to-double
     */
    /* unop vA, vB */
    srl     s4, rINST, 8                /* s4<- A+ */
    srl     s5, rINST, 12               /* a3<- B */
    andi    s4, s4, 15
    GET_VREG(a0, s5)                    /* a0<- vB */
    sll     s4, s4, 2
    $preinstr                           /* optional op */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    $instr                              /* v1<- op */
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vA/vA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /*  jump to next instruction */
    sw      v1, 4(s4)


%verify "executed"
    /*
     * Generic 32bit-to-64bit unary operation.  Provide an "instr" line
     * that specifies an instruction that performs "v1 = op a0", where
     * "result" is a 64-bit quantity in v0/v1.
     *
     * For: int-to-long, int-to-double, float-to-long, float-to-double
     */
    /* unop vA, vB */
    srl     s4, rINST, 8                /* r9<- A+ */
    srl     s5, rINST, 12               /* r3<- B */
    andi    s4, s4, 15
    GET_VREG(a0, s5)                    /* r0<- vB */
    LA(t9, __floatsidf)
    sll     s4, s4, 2
    jalr    t9
    addu    s4, rFP, s4                 /* r9<- &fp[A] */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vA/vA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /*  jump to next instruction */
    sw      v1, 4(s4)


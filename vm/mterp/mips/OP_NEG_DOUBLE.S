%verify "executed"
    /*
     * Generic 64-bit unary operation.
     *
     * For: neg-double
     */
    /* unop vA, vB */
    srl     s4, rINST, 8                /* r9<- A+ */
    srl     s5, rINST, 12               /* r3<- B */
    andi    s4, s4, 15
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[B] */
    sll     s4, s4, 2
    lw      a0, 0(s5)                   /* a0/a1<- vBB */
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a1, 4(s5)
    lui     t1, 0x8000
    move    v0, a0
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    xor     v1, a1, t1
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


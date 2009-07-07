%verify "executed"
    /* unop vA, vB */
    srl     a3, rINST, 12               /* a3<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    sll     a3, a3, 2
    addu    a3, rFP, a3                 /* a3<- &fp[B] */
    andi    s4, s4, 15
    LA(t9, __floatdisf)
    lw      a0, 0(a3)                   /* a0/a1<- vB/vB+1 */
    jalr    t9
    lw      a1, 4(a3)
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)                    /* vA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


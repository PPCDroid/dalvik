%verify "executed"
    /* move-wide vA, vB */
    srl     a2, rINST, 6                /* a2<- A(+) */
    srl     a3, rINST, 10               /* a3<- B */
    andi    a2, a2, 0x3c
    andi    a3, a3, 0x3c
    addu    a2, rFP, a2                 /* a2<- &fp[A] */
    addu    a3, rFP, a3                 /* a3<- &fp[B] */
    lw      t4, 0(a3)                   /* t4/t5<- fp[B] */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    lw      t5, 4(a3)
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      t4, 0(a2)                   /* fp[A]<- t4/t5 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      t5, 4(a2)


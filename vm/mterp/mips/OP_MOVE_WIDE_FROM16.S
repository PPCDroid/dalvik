%verify "executed"
    /* move-wide/from16 vAA, vBBBB */
    FETCH(a3, 1)                        /* r3<- BBBB */
    srl     a2, rINST, 6                /* a2<- AA */
    andi    a2, a2, 0x3fc		/* a2<-AA*4 */
    sll     a3, a3, 2
    addu    a2, rFP, a2                 /* a2<- &fp[AA] */
    addu    a3, rFP, a3                 /* r3<- &fp[BBBB] */
    lw      t4, 0(a3)                   /* t4/t5<- fp[BBBB] */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    lw      t5, 4(a3)
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      t4, 0(a2)                   /* fp[AA]<- t4/t5 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      t5, 4(a2)


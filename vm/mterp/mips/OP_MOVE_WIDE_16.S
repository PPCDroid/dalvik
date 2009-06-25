%verify "executed"
    /* move-wide/16 vAAAA, vBBBB */
    FETCH(a3, 2)                        /* r3<- BBBB */
    FETCH(a2, 1)                        /* r2<- AAAA */
    sll     a3, a3, 2
    sll     a2, a2, 2
    addu    a3, rFP, a3                 /* r3<- &fp[BBBB] */
    addu    a2, rFP, a2                 /* r2<- &fp[AAAA] */
    lw      t4, 0(a3)                   /* t4/t5<- fp[BBBB] */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    lw      t5, 4(a3)
    sw      t4, 0(a2)                   /* fp[AAAA]<- t4/t5 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      t5, 4(a2)
    GOTO_OPCODE(t7)                     /* jump to next instruction */


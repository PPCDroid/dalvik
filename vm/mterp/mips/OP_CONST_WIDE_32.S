%verify "executed"
    /* const-wide/32 vAA, #+BBBBbbbb */
    FETCH(a0, 1)                        /* a0<- 0000bbbb (low) */
    srl     a3, rINST, 8                /* a3<- AA */
    FETCH_S(a2, 2)                      /* a2<- ssssBBBB (high) */
    FETCH_ADVANCE_INST(3)               /* advance rPC, load rINST */
    sll     t5, a2, 16
    or      a0, a0, t5                  /* a0<- BBBBbbbb */
    sll     a3, a3, 2
    addu    a3, rFP, a3                 /* a3<- &fp[AA] */
    sra     a1, a2, 16                  /* a1<- ssssssss */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      a0, 0(a3)                   /* vAA<- a0/a1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, 4(a3)


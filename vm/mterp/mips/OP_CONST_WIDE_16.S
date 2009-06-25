%verify "executed"
    /* const-wide/16 vAA, #+BBBB */
    FETCH_S(a0, 1)                      /* a0<- ssssBBBB (sign-extended) */
    srl     a3, rINST, 8                /* a3<- AA */
    move    a1, a0
    sra     a1, a1, 31                  /* a1<- ssssssss */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    sll     a3, a3, 2
    addu    a3, rFP, a3                 /* a3<- &fp[AA] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      a0, 0(a3)                   /* vAA<- a0/a1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, 4(a3)


%verify "executed"
    /* const-wide/high16 vAA, #+BBBB000000000000 */
    FETCH(a1, 1)                        /* a1<- 0000BBBB (zero-extended) */
    srl     a3, rINST, 8                /* a3<- AA */
    sll     a1, a1, 16                  /* a1<- BBBB0000 */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    sll     a3, a3, 2
    addu    a3, rFP, a3                 /* a3<- &fp[AA] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      zero, 0(a3)                 /* vAA<- a0/a1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, 4(a3)


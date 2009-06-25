%verify "executed"
    /* const-wide vAA, #+HHHHhhhhBBBBbbbb */
    FETCH(a1, 2)                        /* a1<- BBBB (low middle) */
    FETCH(a0, 1)                        /* a0<- bbbb (low) */
    sll     a1, a1, 16
    FETCH(a3, 4)                        /* a3<- HHHH (high) */
    or      a0, a0, a1                  /* a0<- BBBBbbbb (low word) */
    FETCH(a2, 3)                        /* a2<- hhhh (high middle) */
    sll     a3, a3, 16
    srl     t6, rINST, 8                /* t6<- AA */
    or      a1, a2, a3                  /* a1<- HHHHhhhh (high word) */
    FETCH_ADVANCE_INST(5)               /* advance rPC, load rINST */
    sll     t6, t6, 2
    addu    t6, rFP, t6                 /* t6<- &fp[AA] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      a0, 0(t6)                   /* vAA<- a0/a1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, 4(t6)


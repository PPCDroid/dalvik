%verify "executed"
    /* fill-array-data vAA, +BBBBBBBB */
    FETCH(a0, 1)                        /* a0<- bbbb (lo) */
    FETCH(a1, 2)                        /* a1<- BBBB (hi) */
    srl     a3, rINST, 8                /* a3<- AA */
    sll     a1, a1, 16
    or      a1, a0, a1                  /* a1<- BBBBbbbb */
    GET_VREG(a0, a3)                    /* a0<- vAA (array object) */
    EXPORT_PC()
    sll     a1, a1, 1
    LA(t9, dvmInterpHandleFillArrayData)
    jalr    t9                      /* fill the array with predefined data */
    addu    a1, rPC, a1             /* a1<- PC + BBBBbbbb*2 (array data off.) */
    beqz     v0, common_exceptionThrown /* 0 means have exception */
    FETCH_ADVANCE_INST(3)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


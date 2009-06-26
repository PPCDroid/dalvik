%verify "executed"
    /*
     * Long integer shift.  This is different from the generic 32/64-bit
     * binary operations because vAA/vBB are 64-bit but vCC (the shift
     * distance) is 32-bit.  Also, Dalvik requires us to mask off the low
     * 6 bits of the shift distance.
     */
    /* shl-long vAA, vBB, vCC */
    FETCH(a0, 1)                       /* a0<- CCBB */
    srl     s4, rINST, 8               /* s4<- AA */
    andi    s5, a0, 255                /* s5<- BB */
    srl     s6, a0, 8                  /* s6<- CC */
    sll     s5, s5, 2
    add     s5, rFP, s5                 /* s5<- &fp[BB] */
    GET_VREG(t7, s6)                    /* t7<- vCC */
    lw      a0, 0(s5)                   /* a0/a1<- vBB/vBB+1 */
    lw      a1, 4(s5)
    andi    t0, t7, 63                  /* t0<- t7 & 0x3f */
    sll     s4, s4, 2
    add     s4, rFP, s4                 /* s4<- &fp[AA] */

    nor     t2, zero, t0
    srl     t9, a0, 1
    srlv    a2, t9, t2
    sllv    t6, a1, t0
    andi    t1, t7, 0x20
    sllv    v0, a0, t0
    or      v1, a2, t6
    movn    v1, v0, t1

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    movn    v0, zero, t1
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


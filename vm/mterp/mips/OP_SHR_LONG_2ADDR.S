%verify "executed"
    /*
     * Generic 64-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = r0-r1 op r2-r3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-long/2addr, sub-long/2addr, div-long/2addr, rem-long/2addr,
     *      and-long/2addr, or-long/2addr, xor-long/2addr, add-double/2addr,
     *      sub-double/2addr, mul-double/2addr, div-double/2addr,
     *      rem-double/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8               /* s4<- A+ */
    srl     s5, rINST, 12              /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(t7, s5)                    /* t7<- vB */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a0, 0(s4)                   /* a0/a1<- vAA/vAA+1 */
    lw      a1, 4(s4)

    andi    t1, t7, 63                  /* t0<- t7 & 0x3f */
    sll     t2, a1, 1
    nor     v0, zero, t1
    sllv    a2, t2, v0
    srlv    t6, a0, t1
    andi    t0, t7, 0x20
    srav    v1, a1, t1
    sra     t4, a1, 31
    or      v0, a2, t6
    movn    v0, v1, t0


    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    movn    v1, t4, t0
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


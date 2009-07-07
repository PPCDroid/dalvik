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
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[B] */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    lw      a3, 4(s5)                   /* a2/a3<- vBB/vBB+1, divisor */
    lw      a2, 0(s5)
    lw      a0, 0(s4)                   /* a0/a1<- vAA/vAA+1, dividend */
    or      t1, a2, a3
    beqz    t1, common_errDivideByZero
    lw      a1, 4(s4)
    beqz    a0, testneg_${opcode}
    lui     t4, 0x8000
divit_${opcode}:
    LA(t9, __divdi3)
    jalr    t9
    nop

store_${opcode}:
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vAA/vAA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      v1, 4(s4)


%break

testneg_${opcode}:
    bne     a1, t4, divit_${opcode}
    li      t5, -1
    bne     a2, t5, divit_${opcode}
    nop
    bne     a3, t5, divit_${opcode}
    move    v0, zero
    b       store_${opcode}
    lui     v1, 0x8000

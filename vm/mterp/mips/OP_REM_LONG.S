%verify "executed"
    /*
     * Generic 64-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0-a1 op a2-a3".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * for: add-long, sub-long, div-long, rem-long, and-long, or-long,
     *      xor-long, add-double, sub-double, mul-double, div-double,
     *      rem-double
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    s6, a0, 255                 /* s6<- BB */
    srl     s5, a0, 8                   /* s5<- CC */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[AA] */
    sll     s6, s6, 2
    addu    s6, rFP, s6                 /* s6<- &fp[BB] */
    sll     s5, s5, 2
    addu    s5, rFP, s5                 /* s5<- &fp[CC] */
    lw      a2, 0(s5)                   /* a2/a3<- vCC/vCC+1 */
    lw      a3, 4(s5)			/* divisor */
    lw      a0, 0(s6)                   /* a0/a1<- vBB/vBB+1, dividend */
    or      t1, a2, a3
    beqz    t1, common_errDivideByZero
    lw      a1, 4(s6)
    beqz    a0, testneg_${opcode}
    lui     t4, 0x8000
divit_${opcode}:
    LA(t9, __moddi3)
    jalr    t9
    nop

store_${opcode}:
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
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
    move    v1, zero

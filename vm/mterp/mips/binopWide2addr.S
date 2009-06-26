%default {"instr1":"", "result0":"v0", "result1":"v1", "chkzero":"0"}
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
    lw      a0, 0(s4)                   /* a0/a1<- vAA/vAA+1 */
    lw      a1, 4(s4)
    lw      a2, 0(s5)                   /* a2/a3<- vBB/vBB+1 */
    lw      a3, 4(s5)
    .if $chkzero
    or      t7, a2, a3                  /* second arg (a2-a3) is zero? */
    beqz    t7, common_errDivideByZero
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

    $instr1                             /* optional op */
    $instr2                             /* result<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      $result0, 0(s4)             /* vAA/vAA+1<- $result0/$result1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      $result1, 4(s4)


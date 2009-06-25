%default {"instr1":"", "result0":"v0", "result1":"v1", "chkzero":"0"}
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
    andi    s6, a0, 255                 /* t6<- BB */
    srl     s5, a0, 8                   /* t5<- CC */
    sll     s4, s4, 2
    addu    s4, rFP, s4                 /* s4<- &fp[AA] */
    sll     s6, s6, 2
    addu    s6, rFP, s6                 /* t6<- &fp[BB] */
    sll     s5, s5, 2
    addu    s6, rFP, s6                 /* t5<- &fp[CC] */
    lw      a0, 0(s6)                   /* a0/a1<- vBB/vBB+1 */
    lw      a1, 4(s6)
    lw      a2, 0(s5)                   /* a2/a3<- vCC/vCC+1 */
    lw      a3, 4(s5)
    .if $chkzero
    or      t7, a2, a3                  /* second arg (a2-a3) is zero? */
    beqz    t7, common_errDivideByZero
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    $instr1                             /* Probably several comma separated */
    $instr2                             /* result<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      $result0, 0(s4)             /* vAA/vAA+1<- $result0/$result1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      $result1, 4(s4)


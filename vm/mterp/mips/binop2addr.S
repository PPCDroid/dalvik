%default {"preinstr":"", "result":"v0", "chkzero":"0"}
    /*
     * Generic 32-bit "/2addr" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (r1).  Useful for integer division and modulus.
     *
     * For: add-int/2addr, sub-int/2addr, mul-int/2addr, div-int/2addr,
     *      rem-int/2addr, and-int/2addr, or-int/2addr, xor-int/2addr,
     *      shl-int/2addr, shr-int/2addr, ushr-int/2addr, add-float/2addr,
     *      sub-float/2addr, mul-float/2addr, div-float/2addr, rem-float/2addr
     */
    /* binop/2addr vA, vB */
    srl     s4, rINST, 8                /* s4<- A+ */
    srl     s5, rINST, 12               /* s5<- B */
    andi    s4, s4, 15
    GET_VREG(a0, s4)                    /* a0<- vA */
    GET_VREG(a1, s5)                    /* a1<- vB */
    .if $chkzero
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */

    $preinstr                           /* optional op */
    $instr                              /* $result<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG($result, s4)               /* vAA<- $result */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


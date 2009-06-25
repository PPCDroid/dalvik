%default {"result":"v0", "chkzero":"0"}
    /*
     * Generic 32-bit "lit16" binary operation.  Provide an "instr" line
     * that specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int/lit16, rsub-int, mul-int/lit16, div-int/lit16,
     *      rem-int/lit16, and-int/lit16, or-int/lit16, xor-int/lit16
     */
    /* binop/lit16 vA, vB, #+CCCC */
    FETCH_S(a1, 1)                      /* a1<- ssssCCCC (sign-extended) */
    srl     a2, rINST, 12               /* a2<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(a0, a2)                    /* a0<- vB */
    andi    s4, s4, 15
    .if $chkzero
    beqz    a1, common_errDivideByZero   /* is second operand zero? */
    .endif
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */

    $instr                              /* $result<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG($result, s4)               /* vAA<- $result */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


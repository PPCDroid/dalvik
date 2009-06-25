%default {"preinstr":"", "result":"v0", "chkzero":"0"}
    /*
     * Generic 32-bit binary operation.  Provide an "instr" line that
     * specifies an instruction that performs "result = a0 op a1".
     * This could be an instruction or a function call.
     *
     * If "chkzero" is set to 1, we perform a divide-by-zero check on
     * vCC (a1).  Useful for integer division and modulus.
     *
     * For: add-int, sub-int, mul-int, div-int, rem-int, and-int, or-int,
     *      xor-int, shl-int, shr-int, ushr-int, add-float, sub-float,
     *      mul-float, div-float, rem-float
     */
    /* binop vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    srl     a3, a0, 8                   /* a3<- CC */
    andi    a2, a0, 255                 /* a2<- BB */
    GET_VREG(a1, a3)                    /* a1<- vCC */
    GET_VREG(a0, a2)                    /* a0<- vBB */
    .if $chkzero
    beqz    a1, common_errDivideByZero  /* is second operand zero? */
    nop
    .endif

    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    $preinstr                           /* optional op */
    $instr                              /* $result<- op */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG($result, s4)               /* vAA<- $result */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


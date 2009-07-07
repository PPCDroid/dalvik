%verify "executed"
    /*
     * Generic 32bit-to-64bit unary operation.  Provide an "instr" line
     * that specifies an instruction that performs "v1 = op a0", where
     * "result" is a 64-bit quantity in v0/v1.
     *
     * For: int-to-long, int-to-double, float-to-long, float-to-double
     */
    /* unop vA, vB */
    srl     s4, rINST, 8                /* s4<- A+ */
    srl     a3, rINST, 12               /* a3<- B */
    GET_VREG(s5, a3)                    /* s5<- vB */
    LA(t9, __gesf2)
    lui     a1, 0x5f00                  /* (float)maxlong */
    jalr    t9                          /* is arg >= maxlong? */
    move    a0, s5
    lui     v1, 0x7fff
    ori     v1, v1, 0xffff
    bgez    v0, .L${opcode}_finish      /* Brach if yes */
    li      v0, -1			/* and return 0x7fffffff_ffffffff */

    LA(t9, __lesf2)
    lui     a1, 0xdf00                  /* (float)minlong */
    jalr    t9                          /* is arg <= minlong? */
    move    a0, s5
    lui     v1, 0x8000
    blez    v0, .L${opcode}_finish      /* Brach if yes */
    move    v0, zero 			/* and return 0x80000000_00000000 */

    LA(t9, __nesf2)
    move    a1, s5
    jalr    t9                          /* Test for NaN */
    move    a0, s5
    move    v1, zero
    bnez    v0, .L${opcode}_finish      /* Branch if yes */
    move    v0, zero  			/* and return 0 */

    /* OK, we can actually convert it now.
    */
    LA(t9, __fixsfdi)
    jalr    t9                          /* Convert float to double */
    move    a0, s5
    b       .L${opcode}_finish
    nop

%break

.L${opcode}_finish:
    andi    s4, s4, 15
    sll     s4, s4, 2
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vA/vA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /*  jump to next instruction */
    sw      v1, 4(s4)


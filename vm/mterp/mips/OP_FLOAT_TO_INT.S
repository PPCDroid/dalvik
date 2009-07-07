%verify "executed"

    /* unop vA, vB */
    srl     a3, rINST, 12               /* a3<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    GET_VREG(s5, a3)                    /* s5<- vB */
    andi    s4, s4, 15
    LA(t9, __gesf2)
    lui     a1, 0x4f00                  /* (float)maxint */
    jalr    t9                          /* is arg >= maxint? */
    move    a0, s5
    lui     v1, 0x7fff
    bgez    v0, .L${opcode}_finish      /* Brach if yes */
    ori     v1, v1, 0xffff		/* and return 0x7fffffff */

    LA(t9, __lesf2)
    lui     a1, 0xcf00                  /* (float)minint */
    jalr    t9                          /* is arg <= minint? */
    move    a0, s5
    blez    v0, .L${opcode}_finish      /* Branch if yes */
    lui     v1, 0x8000			/* and return 0x80000000 */

    LA(t9, __nesf2)
    move    a1, s5
    jalr    t9                          /* Test for NaN */
    move    a0, s5
    bnez    v0, .L${opcode}_finish      /* Branch if yes */
    move    v1, zero  			/* and return 0 */

    /* OK, we can actually convert it now.
    */
    LA(t9, __fixsfsi)
    jalr    t9                          /* Convert float to int */
    move    a0, s5
    b       .L${opcode}_finish
    move    v1, v0

%break

.L${opcode}_finish:
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v1, s4)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


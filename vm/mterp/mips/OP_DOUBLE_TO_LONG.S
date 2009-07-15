%verify "executed"

    /* unop vA, vB */
    srl     a3, rINST, 12               /* a3<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    sll     a3, a3, 2
    add     a3, rFP, a3                 /* r3<- &fp[B] */
    lw      s5, 0(a3)                   /* a0/a1<- vB/vB+1 */
    lw      s6, 4(a3)
    andi    s4, s4, 15
    LA(t9, __gedf2)
    move    a0, s5
    move    a1, s6
    lui     a3, 0x43e0
    jalr    t9                          /* is arg >= maxlong? */
    move    a2, zero
    lui     v1, 0x7fff
    ori     v1, v1, 0xffff
    bgez    v0, .L${opcode}_finish      /* Brach if yes */
    li      v0, -1			/* and return 0x7fffffff_ffffffff */

    move    a0, s5
    move    a1, s6
    LA(t9, __ledf2)
    lui     a3, 0xc3e0                  /* (double)minlong */
    jalr    t9                          /* is arg <= minlong? */
    move    a2, zero
    lui     v1, 0x8000
    blez    v0, .L${opcode}_finish      /* Brach if yes */
    move    v0, zero 			/* and return 0x80000000_00000000 */
    b       .L${opcode}_nan_and_done
    move    a0, s5

%break

.L${opcode}_nan_and_done:
    move    a1, s6
    LA(t9, __nedf2)
    move    a2, s5
    jalr    t9                          /* Test for NaN */
    move    a3, s6
    move    v1, zero
    bnez    v0, .L${opcode}_finish      /* Branch if yes */
    move    v0, zero  			/* and return 0 */

    /* OK, we can actually convert it now.
    */
    LA(t9, __fixdfdi)
    move    a1, s6
    jalr    t9                          /* Convert double to int */
    move    a0, s5

.L${opcode}_finish:
    sll     s4, s4, 2
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    addu    s4, rFP, s4                 /* s4<- &fp[A] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      v0, 0(s4)                   /* vA/vA+1<- v0/v1 */
    GOTO_OPCODE_SLOT(t7)                /*  jump to next instruction */
    sw      v1, 4(s4)


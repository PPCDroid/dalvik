%verify "executed"

    /* unop vA, vB */
    srl     a3, rINST, 12               /* a3<- B */
    srl     s4, rINST, 8                /* s4<- A+ */
    sll     a3, a3, 2
    add     a3, rFP, a3                 /* r3<- &fp[B] */
    lw      s5, 0(a3)                   /* a0/a1<- vB/vB+1 */
    lw      s6, 4(a3)
    andi    s4, s4, 15
    move    gp, s8
    la      t9, __gedf2
    move    a0, s5
    move    a1, s6
    la      t1, .L${opcode}_maxdint     /* (double)maxint */
    lw      a2, 0(t1)
    jalr    t9                          /* is arg >= maxint? */
    lw      a3, 4(t1)
    lui     v1, 0x7fff
    bgez    v0, .L${opcode}_finish      /* Brach if yes */
    ori     v1, v1, 0xffff		/* and return 0x7fffffff */

    move    a0, s5
    move    a1, s6
    LA(t9, __ledf2)
    lui     a3, 0xc1e0                  /* (double)minint */
    jalr    t9                          /* is arg <= minint? */
    move    a2, zero
    blez    v0, .L${opcode}_finish      /* Branch if yes */
    lui     v1, 0x8000			/* and return 0x80000000 */
    b       .L${opcode}_nan_and_done
    move    a0, s5

%break

.L${opcode}_nan_and_done:
    move    a1, s6
    LA(t9, __nesf2)
    move    a2, s5
    jalr    t9                          /* Test for NaN */
    move    a3, s6
    bnez    v0, .L${opcode}_finish      /* Branch if yes */
    move    v1, zero  			/* and return 0 */

    /* OK, we can actually convert it now.
    */
    LA(t9, __fixdfsi)
    move    a1, s6
    jalr    t9                          /* Convert double to int */
    move    a0, s5
    move    v1, v0

.L${opcode}_finish:
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v1, s4)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */

.L${opcode}_maxdint:
	.word	0xffc00000
	.word	0x41dfffff


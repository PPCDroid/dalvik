%verify "executed"
%verify "null object"
    /* For: iget-quick, iget-object-quick */
    /* op vA, vB, offset@CCCC */
    srl     a2, rINST, 12               /* a2<- B */
    GET_VREG(a3, a2)                    /* a3<- object we're operating on */
    FETCH(a1, 1)                        /* a1<- field byte offset */
    beqz    a3, common_errNullObject    /* object was null */
    srl     a2, rINST, 8                /* a2<- A(+) */
    addu    a3, a3, a1
    lw      a0, 0(a3)                   /* a0<- obj.field (always 32 bits) */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    andi    a2, a2, 15
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a0, a2)                    /* fp[A]<- a0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


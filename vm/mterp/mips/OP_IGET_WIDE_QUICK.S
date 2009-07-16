%verify "executed"
%verify "null object"
    /* iget-wide-quick vA, vB, offset@CCCC */
    srl     a2, rINST, 12               /* a2<- B */
    GET_VREG(a3, a2)                    /* a3<- object we're operating on */
    FETCH(a1, 1)                        /* a1<- field byte offset */
    beqz    a3, common_errNullObject    /* bail if object is null */
    srl     a2, rINST, 8                /* a2<- A(+) */
    addu    a3, a3, a1
    lw      a0, 0(a3)                /* a0/a1<- obj.field (64 bits, aligned) */
    lw      a1, 4(a3)
    andi    a2, a2, 15
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    sll     a2, a2, 2
    addu    a3, rFP, a2                 /* a3<- &fp[A] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      a0, 0(a3)                   /* fp[A]<- a0/a1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, 4(a3)


%verify "executed"
%verify "null object"
    /* iput-wide-quick vA, vB, offset@CCCC */
    srl     a0, rINST, 8                /* a0<- A(+) */
    srl     a1, rINST, 12               /* a1<- B */
    andi    a0, a0, 15
    GET_VREG(a2, a1)                    /* a2<- fp[B], the object pointer */
    sll     a0, a0, 2
    addu    a3, rFP, a0                 /* a3<- &fp[A] */
    beqz    a2, common_errNullObject    /* object was null */
    lw      a0, 0(a3)                   /* a0/a1<- fp[A] */
    FETCH(t6, 1)                        /* t6<- field byte offset */
    lw      a1, 4(a3)
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    addu    a2, a2, t6
    sw      a0, 0(a2)                 /* obj.field (64 bits, aligned)<- a0/a1 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a1, 4(a2)


%verify "executed"
%verify "null object"
    /* For: iput-quick, iput-object-quick */
    /* op vA, vB, offset@CCCC */
    srl     a2, rINST, 12               /* a2<- B */
    GET_VREG(a3, a2)                    /* a3<- fp[B], the object pointer */
    FETCH(a1, 1)                        /* a1<- field byte offset */
    beqz    a3, common_errNullObject    /* object was null */
    srl     a2, rINST, 8                /* a2<- A(+) */
    andi    a2, a2, 15
    GET_VREG(a0, a2)                    /* a0<- fp[A] */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    addu   a3, a3, a1
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw     a0, 0(a3)                    /* obj.field (always 32 bits)<- a0 */


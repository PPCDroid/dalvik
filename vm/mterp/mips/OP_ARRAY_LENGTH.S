%verify "executed"
    /*
     * Return the length of an array.
     */
    srl     a1, rINST, 12               /* a1<- B */
    srl     a2, rINST, 8                /* a2<- A+ */
    GET_VREG(a0, a1)                    /* a0<- vB (object ref) */
    andi    a2, a2, 15                  /* a2<- A */
    beqz    a0, common_errNullObject    /* if object is null, fail */
    FETCH_ADVANCE_INST(1)               /* advance rPC, load rINST */
    lw      a3, offArrayObject_length(a0)    /* a3<- array length */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a3, a2)                    /* vB<- length */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


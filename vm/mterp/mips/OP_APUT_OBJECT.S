%verify "executed"
    /*
     * Store an object into an array.  vBB[vCC] <- vAA.
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a1, a2)                    /* a1<- vBB (array object) */
    GET_VREG(a0, a3)                    /* a0<- vCC (requested index) */
    beqz    a1, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a1)    /* a3<- arrayObj->length */
    sll     t6, a0, 2
    addu    s5, a1, t6                  /* s5<- arrayObj + index*width */
    subu    t5, a0, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    GET_VREG(s4, s4)			/* s4<- vAA */

    beqz    s4, .L${opcode}_skip_check /* if null reference, skip type checks */
    lw      a1, offObject_clazz(a1)    /* r1<- arrayObj->clazz */
    LA(t9, dvmCanPutArrayElement)
    jalr    t9                          /* test object type vs. array type */
    lw      a0, offObject_clazz(s4)     /* a0<- obj->clazz */
    beqz    v0, common_errArrayStore    /* branch on error return */
.L${opcode}_skip_check:
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      s4, offArrayObject_contents(s5) /* vBB[vCC]<- vAA */


%default { "load":"lw", "shift":"2" }
%verify "executed"
    /*
     * Array get, 32 bits or less.  vAA <- vBB[vCC].
     *
     * for: aget, aget-object, aget-boolean, aget-byte, aget-char, aget-short
     */
    /* op vAA, vBB, vCC */
    FETCH(a0, 1)                        /* a0<- CCBB */
    srl     s4, rINST, 8                /* s4<- AA */
    andi    a2, a0, 255                 /* a2<- BB */
    srl     a3, a0, 8                   /* a3<- CC */
    GET_VREG(a0, a2)                    /* a0<- vBB (array object) */
    GET_VREG(a1, a3)                    /* a1<- vCC (requested index) */
    beqz    a0, common_errNullObject    /* if null array object, bail */
    lw      a3, offArrayObject_length(a0)    /* a3<- arrayObj->length */
    sll     t6, a1, $shift
    addu    a0, a0, t6                  /* a0<- arrayObj + index*width */
    subu    t5, a1, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    $load   a2, offArrayObject_contents(a0)  /* a2<- vBB[vCC] */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a2, s4)                    /* vAA<- a2 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


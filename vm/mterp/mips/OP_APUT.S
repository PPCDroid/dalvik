%default { "store":"sw", "shift":"2" }
%verify "executed"
    /*
     * Array put, 32 bits or less.  vBB[vCC] <- vAA.
     *
     * for: aput, aput-boolean, aput-byte, aput-char, aput-short
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
    bltz    a1, common_errArrayIndex    /* index < zero, bail */
    addu    a0, a0, t6                  /* a0<- arrayObj + index*width */
    subu    t5, a1, a3                  /* compare unsigned index, length */
    bgez    t5, common_errArrayIndex    /* index >= length, bail */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_VREG(a2, s4)                    /* a2<- vAA */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    $store   a2, offArrayObject_contents(a0)  /* vBB[vCC]<- a2 */


%default { "load":"lw" }
%verify "executed"
%verify "null object"
%verify "field already resolved"
%verify "field not yet resolved"
%verify "field cannot be resolved"
    /*
     * General 32-bit instance field get.
     *
     * for: iget, iget-object, iget-boolean, iget-byte, iget-char, iget-short
     */
    /* op vA, vB, field@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref CCCC */
    lw      a2, offDvmDex_pResFields(a3) /* a2<- pDvmDex->pResFields */
    GET_VREG(s4, a0)                    /* s4<- fp[B], the object pointer */
    sll     t6, a1, 2
    addu    t6, a2, t6
    lw      v0, 0(t6)                   /* a0<- resolved InstField ptr */
    bnez    v0, .L${opcode}_finish      /* if not null, already resolved */
    lw      a2, offGlue_method(rGLUE)   /* a2<- current method */
    EXPORT_PC()                         /* resolve() could throw */
    LA(t9, dvmResolveInstField)
    jalr    t9                          /* v0<- resolved InstField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    bnez    v0, .L${opcode}_finish      /* if not null, finish up */
    nop
    b       common_exceptionThrown      /* Bail on null pointer */
    nop

%break

.L${opcode}_finish:
    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    beqz    s4, common_errNullObject        /* bail if object was null */
    addu    t5, s4, a3
    $load   a0, 0(t5)                   /* a0<- obj.field (8/16/32 bits) */
    srl     a2, rINST, 8                /* a2<- A+ */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    andi    a2, a2, 15                  /* a2<- A */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a0, a2)                    /* fp[A]<- a0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


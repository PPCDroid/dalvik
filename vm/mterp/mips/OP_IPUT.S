%default { "store":"sw" }
%verify "executed"
%verify "null object"
%verify "field already resolved"
%verify "field not yet resolved"
%verify "field cannot be resolved"
    /*
     * General 32-bit instance field put.
     *
     * for: iput, iput-object, iput-boolean, iput-byte, iput-char, iput-short
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

    /*
     * Currently:
     *  v0 holds resolved field
     *  s4 holds object
     */
.L${opcode}_finish:
    srl     a1, rINST, 8                /* aa<- A+ */
    lw      a3, offInstField_byteOffset(v0) /* a3<- byte offset of field */
    andi    a1, a1, 15                  /* a1<- A */
    beqz    s4, common_errNullObject    /* bail if object was null */
    GET_VREG(a0, a1)                    /* a0<- fp[A] */
    addu    t5, s4, a3
    $store  a0, 0(t5)                   /* a0<- obj.field (8/16/32 bits) */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */

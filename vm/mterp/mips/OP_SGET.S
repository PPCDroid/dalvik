%verify "executed"
%verify "field already resolved"
%verify "field not yet resolved"
%verify "field cannot be resolved"
    /*
     * General 32-bit SGET handler.
     *
     * for: sget, sget-object, sget-boolean, sget-byte, sget-char, sget-short
     */
    /* op vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    bnez    v0, .L${opcode}_finish      /* if not null, finish */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */
    nop

.L${opcode}_finish:           /* field ptr in v0 */
    lw      a1, offStaticField_value(v0) /* a1<- field value */
    srl     t5, rINST, 8                /* t5<- AA */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(a1, t5)                    /* fp[AA]<- a1 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


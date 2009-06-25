%verify "executed"
%verify "field already resolved"
%verify "field not yet resolved"
%verify "field cannot be resolved"
    /*
     * 64-bit SGET handler.
     */
    /* sget-wide vAA, field@BBBB */
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

.L${opcode}_finish:
    srl     a1, rINST, 8                /* a1<- AA */
    lw      a2, offStaticField_value(v0) /* a2/a3<- field value (aligned) */
    lw      a3, offStaticField_value+4(v0)
    sll     a1, a1, 2
    addu    a1, rFP, a1                 /* a1<- &fp[AA] */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    sw      a2, 0(a1)                   /* vAA/vAA+1<- a2/a3 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a3, 4(a1)
%break

    /*
     * Continuation if the field has not yet been resolved.
     *  r1: BBBB field ref
     */
.L${opcode}_resolve:


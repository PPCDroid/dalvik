%verify "executed"
%verify "field already resolved"
%verify "field not yet resolved"
%verify "field cannot be resolved"
    /*
     * 64-bit SPUT handler.
     */
    /* sput-wide vAA, field@BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- DvmDex */
    FETCH(a1, 1)                        /* a1<- field ref BBBB */
    lw      a2, offDvmDex_pResFields(a2) /* a2<- dvmDex->pResFields */
    srl     s4, rINST, 8                /* s4<- AA */
    sll     t6, a1, 2
    addu    t6, t6, a2
    lw      v0, 0(t6)                   /* v0<- resolved StaticField ptr */
    sll     s4, s4, 2
    bnez    v0, .L${opcode}_finish      /* if not null, finish */
    addu    s4, rFP, s4                 /* s4<- &fp[AA] */

    lw      a2, offGlue_method(rGLUE)    /* r2<- current method */
    EXPORT_PC()                       /* resolve() could throw, so export now */
    LA(t9,dvmResolveStaticField)
    jalr    t9                          /* v0<- resolved StaticField ptr */
    lw      a0, offMethod_clazz(a2)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null ret ptr, handle exception */

.L${opcode}_finish:        /* field ptr in v0, &fp[AA] in s4 */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    lw      a2, 0(s4)                   /* r2/r3<- vAA/vAA+1 */
    lw      a3, 4(s4)
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    sw      a2, offStaticField_value(v0) /* field<- vAA/vAA+1 */
    GOTO_OPCODE_SLOT(t7)                /* jump to next instruction */
    sw      a3, offStaticField_value+4(v0)


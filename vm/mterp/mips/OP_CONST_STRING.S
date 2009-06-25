%verify "executed"
%verify "String already resolved"
%verify "String not yet resolved"
%verify "String cannot be resolved"
    /* const/string vAA, String@BBBB */
    FETCH(a1, 1)                               /* a1<- BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)  /* a2<- glue->methodClassDex */
    srl     s4, rINST, 8                       /* s4<- AA */
    lw      a2, offDvmDex_pResStrings(a2)      /* a2<- dvmDex->pResStrings */
    sll     t6, a1, 2
    addu    a2, a2, t6
    lw      v0, 0(a2)                          /* v0<- pResStrings[BBBB] */
    bnez    v0, .L${opcode}_resolved           /* Resolved? */
    nop

    EXPORT_PC()
    lw      a0, offGlue_method(rGLUE)   /* a0<- glue->method */
    LA(t9, dvmResolveString)            /* v0<- String reference */
    jalr    t9				/* v0 = call(a0, a1) */
    lw      a0, offMethod_clazz(a0)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if failed, handle exception */
    /* Use of delay slot here in next macro is OK. Hopefully, likely path */

.L${opcode}_resolved:
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


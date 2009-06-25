%verify "executed"
%verify "String already resolved"
%verify "String not yet resolved"
%verify "String cannot be resolved"
    /* const/string vAA, String@BBBBBBBB */
    FETCH(a0, 1)                        /* a0<- bbbb (low) */
    FETCH(a1, 2)                        /* a1<- BBBB (high) */
    lw      a2, offGlue_methodClassDex(rGLUE)  /* r2<- glue->methodClassDex */
    srl     s4, rINST, 8                /* s4<- AA */
    lw      a2, offDvmDex_pResStrings(a2)   /* r2<- dvmDex->pResStrings */
    sll     a1, a1, 16
    or      a1, a0, a1                  /* a1<- BBBBbbbb */
    sll     t6, a1, 2
    addu    a2, a2, t6
    lw      v0, 0(a2)                   /* a0<- pResStrings[BBBBbbbb] */
    bnez    v0, .L${opcode}_resolved
    nop

    EXPORT_PC()
    lw      a0, offGlue_method(rGLUE)   /* a0<- glue->method */
    LA(t9, dvmResolveString)
    jalr    t9				/* v0 = call(a0, a1) */
    lw      a0, offMethod_clazz(a0)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if failed, handle exception */
    /* Use of delay slot here in next macro is OK. Hopefully, likely path */

.L${opcode}_resolved:
    FETCH_ADVANCE_INST(3)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


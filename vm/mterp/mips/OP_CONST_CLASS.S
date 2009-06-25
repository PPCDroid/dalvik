%verify "executed"
%verify "Class already resolved"
%verify "Class not yet resolved"
%verify "Class cannot be resolved"
    /* const/class vAA, Class@BBBB */
    FETCH(a1, 1)                               /* a1<- BBBB */
    lw      a2, offGlue_methodClassDex(rGLUE)  /* a2<- glue->methodClassDex */
    srl     s4, rINST, 8                       /* s4<- AA */
    lw      a2, offDvmDex_pResClasses(a2)      /* a2<- dvmDex->pResClasses */
    sll     t6, a1, 2
    addu    a2, a2, t6
    lw      v0, 0(a2)                          /* v0<- pResClasses[BBBB] */
    bnez    v0, .L${opcode}_resolved           /* Resolved? */
    nop

    EXPORT_PC()
    lw      a0, offGlue_method(rGLUE)   /* a0<- glue->method */
    li      a2, 1                       /* a2<- true */
    LA(t9, dvmResolveClass)             /* v0<- Class reference */
    jalr    t9				/* v0 = call(a0, a1, a2) */
    lw      a0, offMethod_clazz(a0)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if failed, handle exception */
    /* Use of delay slot here in next macro is OK. Hopefully, likely path */

.L${opcode}_resolved:
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, s4)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


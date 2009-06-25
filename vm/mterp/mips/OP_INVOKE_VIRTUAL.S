%default { "isrange":"0", "routine":"NoRange" }
%verify "executed"
%verify "unknown method"
%verify "null object"
    /*
     * Handle a virtual method call.
     *
     * for: invoke-virtual, invoke-virtual/range
     */
    /* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
    /* op vAA, {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- pDvmDex */
    FETCH(a1, 1)                        /* a1<- BBBB */
    lw      a3, offDvmDex_pResMethods(a3)    /* a3<- pDvmDex->pResMethods */
    FETCH(s5, 2)                        /* s5<- GFED or CCCC */
    sll     t6, a1, 2
    addu    t6, t6, a3
    lw      v0, 0(a3)                   /* v0<- resolved baseMethod */
    .if     (!$isrange)
    andi    s5, s5, 15                  /* s5<- D (or stays CCCC) */
    .endif
    bnez    v0, .L${opcode}_continue    /* if resolved, continue on */
    EXPORT_PC()                         /* must export for invoke */
    lw      a3, offGlue_method(rGLUE)   /* a3<- glue->method */
    li      a2, METHOD_VIRTUAL          /* resolver method type */
    LA(t9,dvmResolveMethod)
    jalr    t9                          /* v0<- call(clazz, ref, flags) */
    lw      a0, offMethod_clazz(a3)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null return, handle exception */

    /*
     * At this point:
     *  v0 = resolved base method
     *  s5 = C or CCCC (index of first arg, which is the "this" ptr)
     */
.L${opcode}_continue:
    GET_VREG(a1, s5)                        /* a1<- "this" ptr */
    lhu     a2, offMethod_methodIndex(v0)   /* a2<- baseMethod->methodIndex */
    beqz    a1, common_errNullObject        /* null "this", throw exception */
    nop
    lw      a3, offObject_clazz(a1)         /* a1<- thisPtr->clazz */
    lw      a3, offClassObject_vtable(a3)   /* a3<- thisPtr->clazz->vtable */
    sll     t5, a2, 2
    addu    t5, t5, a3
    b       common_invokeMethod${routine}    /* continue on */
    lw      a0, 0(t5)                        /* a0<- vtable[methodIndex] */


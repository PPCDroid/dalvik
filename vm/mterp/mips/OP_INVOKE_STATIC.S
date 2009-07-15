%default { "routine":"NoRange" }
%verify "executed"
%verify "unknown method"
    /*
     * Handle a static method call.
     *
     * for: invoke-static, invoke-static/range
     */
    /* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
    /* op {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- pDvmDex */
    FETCH(a1, 1)                        /* a1<- BBBB
    lw      a3, offDvmDex_pResMethods(a3)    /* a3<- pDvmDex->pResMethods */
    sll     t6, a1, 2
    addu    t6, t6, a3
    lw      a0, 0(t6)                   /* a0<- resolved methodToCall */
    EXPORT_PC()                         /* must export for invoke */
    bnez    a0, common_invokeMethod${routine} /* resolved, continue on */
    lw      a3, offGlue_method(rGLUE)   /* a3<- glue->method */
    lw      a0, offMethod_clazz(a3)     /* a0<- method->clazz */
    LA(t9,dvmResolveMethod)
    jalr    t9                          /* a0<- call(clazz, ref, flags) */
    li      a2, METHOD_STATIC           /* resolver method type */
    bnez    v0, common_invokeMethod${routine} /* if resolved, continue */
    move    a0, v0
    b       common_exceptionThrown      /* otherwise, handle exception */
    nop


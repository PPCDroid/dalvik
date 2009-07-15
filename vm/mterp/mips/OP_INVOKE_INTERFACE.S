%default { "isrange":"0", "routine":"NoRange" }
%verify "executed"
%verify "unknown method"
%verify "null object"
    /*
     * Handle an interface method call.
     *
     * for: invoke-interface, invoke-interface/range
     */
    /* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
    /* op {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
    FETCH(a2, 2)                        /* a2<- FEDC or CCCC */
    FETCH(a1, 1)                        /* a1<- BBBB */
    .if     (!$isrange)
    andi    a2, a2, 15                  /* a2<- C (or stays CCCC) */
    .endif
    EXPORT_PC()                         /* must export for invoke */
    GET_VREG(a0, a2)                    /* a0<- first arg ("this") */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- methodClassDex */
    beqz    a0, common_errNullObject    /* if null obj, fail */
    lw      a2, offGlue_method(rGLUE)   /* a2<- method */
    LA(t9,dvmFindInterfaceMethodInCache)
    jalr    t9                          /* v0<- call(class, ref, method, dex) */
    lw      a0, offObject_clazz(a0)     /* a0<- thisPtr->clazz */
    bnez    v0, common_invokeMethod${routine} /* jump to common handler  */
    move    a0, v0
    b       common_exceptionThrown      /* if null, handle exception */
    nop


%default { "isrange":"0", "routine":"NoRange" }
%verify "executed"
%verify "unknown method"
    /*
     * Handle a direct method call.
     *
     * (We could defer the "is 'this' pointer null" test to the common
     * method invocation code, and use a flag to indicate that static
     * calls don't count.  If we do this as part of copying the arguments
     * out we could avoiding loading the first arg twice.)
     *
     * for: invoke-direct, invoke-direct/range
     */
    /* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
    /* op {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- pDvmDex */
    FETCH(a1, 1)                        /* a1<- BBBB */
    lw      a3, offDvmDex_pResMethods(a3)    /* a3<- pDvmDex->pResMethods */
    FETCH(s4, 2)                        /* s4<- GFED or CCCC */
    sll     t6, a1, 2
    addu    t6, t6, a3
    lw      v0, 0(t6)                   /* v0<- resolved methodToCall */
    .if     (!$isrange)
    andi    s4, s4, 15                  /* s4<- D (or stays CCCC) */
    .endif
    EXPORT_PC()                         /* must export for invoke */
    GET_VREG(a2, s4)                    /* a2<- "this" ptr */
    bnez   v0, .L${opcode}_finish       /* resolved, just finish */

    	/* resolve */
    lw      a3, offGlue_method(rGLUE)   /* a3<- glue->method */
    lw      a0, offMethod_clazz(a3)     /* a0<- method->clazz */
    LA(t9,dvmResolveMethod)
    jalr    t9 				/* v0<- call(clazz, ref, flags) */
    li      a2, METHOD_DIRECT           /* resolver method type */
    beqz    v0, common_exceptionThrown  /* didn't resolve, handle exception */
    GET_VREG(a2, s4)                    /* a2<- "this" ptr (reload) */

.L${opcode}_finish:
    bnez    a2, common_invokeMethod${routine} /* null "this"? no, continue on */
    move    a0, v0
    b       common_errNullObject        /* yes, throw exception */
    nop



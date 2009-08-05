%default { "isrange":"0", "routine":"NoRange" }
%verify "executed"
%verify "unknown method"
    /*
     * Handle a "super" method call.
     *
     * for: invoke-super, invoke-super/range
     */
    /* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
    /* op vAA, {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
    FETCH(s4, 2)                        /* s4<- GFED or CCCC */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- pDvmDex */
    .if     (!$isrange)
    andi    s4, s4, 15                  /* s4<- D (or stays CCCC) */
    .endif
    FETCH(a1, 1)                        /* a1<- BBBB */
    lw      a3, offDvmDex_pResMethods(a3)    /* a3<- pDvmDex->pResMethods */
    GET_VREG(a2, s4)                    /* a2<- "this" ptr */
    sll     t6, a1, 2
    addu    t6, t6, a3
    lw      v0, 0(t6)                   /* v0<- resolved baseMethod */
    lw      a0, offGlue_method(rGLUE)   /* a0<- current method */
    beqz    a2, common_errNullObject    /* null "this", throw exception */
    EXPORT_PC()                         /* must export for invoke */
    bnez    v0, .L${opcode}_continue        /* resolved, continue on */
    lw      a0, offMethod_clazz(a0)     /* a0<- method->clazz */
    	/* do resolve now */
    LA(t9, dvmResolveMethod)
    jalr    t9				/* v0<- call(clazz, ref, flags) */
    li      a2, METHOD_VIRTUAL          /* resolver method type */
    bnez    v0, .L${opcode}_continue    /* rval null?  no, continue */
    nop
    b       common_exceptionThrown      /* yes, handle exception */
    nop

%break

    /*
     * At this point:
     *  v0 = resolved base method
     *  a0 = method->clazz
     */
.L${opcode}_continue:
    lw      a1, offClassObject_super(a0)     /* a1<- method->clazz->super */
    lhu     a2, offMethod_methodIndex(v0)    /* a2<- baseMethod->methodIndex */
    lw      a3, offClassObject_vtableCount(a1)   /* a3<- super->vtableCount */
    EXPORT_PC()                         /* must export for invoke */
    subu    t6, a3, a2                  /* compare (methodIndex, vtableCount) */
    bltz    t6, .L${opcode}_nsm         /* method not present in superclass */
    lw      a1, offClassObject_vtable(a1)    /* a1<- ...clazz->super->vtable */
    sll     t6, a2, 2
    addu    t6, t6, a1
    bal     common_invokeMethod${routine} /* continue on */
    lw      a0, 0(t6)                   /* a0<- vtable[methodIndex] */

    /*
     * Throw a NoSuchMethodError with the method name as the message.
     *  v0 = resolved base method
     */
.L${opcode}_nsm:
    b       common_errNoSuchMethod
    lw      a1, offMethod_name(v0)      /* a1<- method name */


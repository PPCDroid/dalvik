%default { "isrange":"0", "routine":"NoRange" }
%verify "executed"
%verify "unknown method"
    /*
     * Handle an optimized "super" method call.
     *
     * for: [opt] invoke-super-quick, invoke-super-quick/range
     */
    /* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
    /* op vAA, {vCCCC..v(CCCC+AA-1)}, meth@BBBB */
    FETCH(s5, 2)                       /* s5<- GFED or CCCC */
    lw      a2, offGlue_method(rGLUE)  /* a2<- current method */
    .if     (!$isrange)
    andi    s5, s5, 15                 /* s5<- D (or stays CCCC) */
    .endif
    FETCH(a1, 1)                        /* a1<- BBBB */
    lw      a2, offMethod_clazz(a2)     /* a2<- method->clazz */
    EXPORT_PC()                         /* must export for invoke */
    lw      a2, offClassObject_super(a2) /* a2<- method->clazz->super */
    GET_VREG(a3, s5)                    /* a3<- "this" */
    lw      a2, offClassObject_vtable(a2)  /* a2<- ...clazz->super->vtable */
    sll     t6, a1, 2
    beqz    a3, common_errNullObject    /* "this" is null, throw exception */
    addu    t6, t6, a2
    b       common_invokeMethod${routine} /* continue on */
    lw      a0, 0(t6)                   /* a0<- super->vtable[BBBB] */


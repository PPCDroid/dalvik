%verify "executed"
%verify "null object"
%verify "class cast exception thrown, with correct class name"
%verify "class cast exception not thrown on same class"
%verify "class cast exception not thrown on subclass"
%verify "class not resolved"
%verify "class already resolved"
    /*
     * Check to see if a cast from one class to another is allowed.
     */
    /* check-cast vAA, class@BBBB */
    srl     a3, rINST, 8                /* a3<- AA */
    FETCH(a2, 1)                        /* a2<- BBBB */
    GET_VREG(s4, a3)                    /* a9<- object */
    lw      a0, offGlue_methodClassDex(rGLUE)    /* a0<- pDvmDex */
    beqz    s4, .L${opcode}_okay            /* null obj, cast always succeeds */
    lw      a0, offDvmDex_pResClasses(a0)   /* a0<- pDvmDex->pResClasses */
    sll     t6, a2, 2
    addu    t6, t6, a0
    lw      a1, 0(t6)                   /* a1<- resolved class */
    beqz    a1,  .L${opcode}_resolve    /* not resolved, do it now */
    lw      a0, offObject_clazz(s4)     /* a0<- obj->clazz */

.L${opcode}_resolved:
                          /* same class (trivial success)? */
    bne     a0, a1, .L${opcode}_fullcheck       /* no, do full check */
    nop

.L${opcode}_okay:
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */
%break

    /*
     * Trivial test failed, need to perform full check.  This is common.
     *  a0 holds obj->clazz
     *  a1 holds class resolved from BBBB
     *  s4 holds object
     */
.L${opcode}_fullcheck:
    LA(t9,dvmInstanceofNonTrivial)          /* v0<- boolean result */
    jalr    t9
    nop
    bnez    v0, .L${opcode}_okay            /* non-zero (true), success */
    nop

    /* A cast has failed.  We need to throw a ClassCastException with the
     * class of the object that failed to be cast.
     */
    EXPORT_PC()                         /* about to throw */
    lw      a3, offObject_clazz(s4)     /* a3<- obj->clazz */
    move    gp, s8
    la      a0, .strClassCastException
    la      t9, dvmThrowExceptionWithClassMessage
    jalr    t9
    lw      a1, offClassObject_descriptor(a3) /* r1<- obj->clazz->descriptor */
    b       common_exceptionThrown
    nop

    /*
     * Resolution required.  This is the least-likely path.
     *
     *  a2 holds BBBB
     *  s4 holds object
     */
.L${opcode}_resolve:
    EXPORT_PC()                         /* resolve() could throw */
    lw      a3, offGlue_method(rGLUE)   /* a3<- glue->method */
    move    a1, a2                      /* a1<- BBBB */
    LA(t9,dvmResolveClass)              /* v0<- resolved ClassObject ptr */
    move    a2, zero                    /* a2<- false */
    jalr    t9
    lw      a0, offMethod_clazz(a3)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* yes, handle exception */
    lw      a0, offObject_clazz(s4)     /* a0<- obj->clazz */
    b       .L${opcode}_resolved        /* pick up where we left off */
    move    a1, v0                      /* a1<- class resolved from BBBB */



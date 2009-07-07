%verify "executed"
%verify "class not resolved"
%verify "class cannot be resolved"
%verify "class not initialized"
%verify "class fails to initialize"
%verify "class already resolved/initialized"
%verify "class is abstract or interface"
%verify "allocation fails"
    /*
     * Create a new instance of a class.
     */
    /* new-instance vAA, class@BBBB */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- pDvmDex */
    FETCH(a1, 1)                        /* a1<- BBBB */
    lw      a3, offDvmDex_pResClasses(a3)    /* a3<- pDvmDex->pResClasses */
    sll     t4, a1, 2
    addu    a3, a3, t4
    lw      v0, 0(a3)                   /* v0<- resolved class */
    EXPORT_PC()                         /* req'd for init, resolve, alloc */
    beqz    v0, .L${opcode}_resolve     /* resolved? no, resolve it now */
    nop

.L${opcode}_resolved:   /* v0=class */
    lbu     a1, offClassObject_status(v0)  /* a1<- ClassStatus enum */
    li      t4, CLASS_INITIALIZED          /* has class been initialized? */
    bne     a1, t4, .L${opcode}_needinit   /* no, init class now */
    nop
.L${opcode}_initialized: /* v0=class */
    lw      a3, offClassObject_accessFlags(v0)   /* a3<- clazz->accessFlags */
    andi    t4, a3, (ACC_INTERFACE|ACC_ABSTRACT) /* abstract or interface? */
    beqz    t4, .L${opcode}_finish      /* concrete class, continue */
    li      a1, ALLOC_DONT_TRACK        /* flags for alloc call */
    b       .L${opcode}_abstract        /* fail */
    nop

%break

.L${opcode}_finish: /* v0=class */
    LA(t9,dvmAllocObject)		/* call(clazz, flags) */
    jalr    t9                          /* v0<- new object */
    move    a0, v0
    srl     a3, rINST, 8                /* a3<- AA */
    beqz    v0, common_exceptionThrown  /* failed? yes, handle the exception */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, a3)                    /* vAA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */

    /*
     * Class initialization required.
     *
     *  v0 holds class object
     */
.L${opcode}_needinit:
    LA(t9,dvmInitClass)
    move    a0, v0
    jalr    t9                          /* initialize class */
    move    s4, v0                      /* save v0 (class) */
    bnez    v0, .L${opcode}_initialized /* success, continue */
    move    v0, s4                      /* restore v0 */
    b       common_exceptionThrown      /* failed, deal with init exception */
    nop

    /*
     * Resolution required.  This is the least-likely path.
     *
     *  a1 holds BBBB
     */
.L${opcode}_resolve:
    lw      a3, offGlue_method(rGLUE)   /* a3<- glue->method */
    move    a2, zero                    /* a2<- false */
    LA(t9,dvmResolveClass)
    jalr    t9                          /* v0<- resolved ClassObject ptr */
    lw      a0, offMethod_clazz(a3)     /* a0<- method->clazz */
    bnez    v0, .L${opcode}_resolved    /* null? no, continue */
    nop
    b       common_exceptionThrown      /* yes, handle exception */
    nop

    /*
     * We can't instantiate an abstract class or interface, so throw an
     * InstantiationError with the class descriptor as the message.
     *
     *  v0 holds class object
     */
.L${opcode}_abstract:
    move    gp, s8
    la      a0, .strInstantiationError
    la      t9, dvmThrowExceptionWithClassMessage
    jalr    t9
    lw      a1, offClassObject_descriptor(v0)
    b       common_exceptionThrown
    nop


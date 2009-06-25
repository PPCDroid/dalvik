%verify "executed"
%verify "null object"
%verify "class cast exception thrown, with correct class name"
%verify "class cast exception not thrown on same class"
%verify "class cast exception not thrown on subclass"
%verify "class not resolved"
%verify "class already resolved"
    /*
     * Check to see if an object reference is an instance of a class.
     *
     * Most common situation is a non-null object, being compared against
     * an already-resolved class.
     */
    /* instance-of vA, vB, class@CCCC */
    srl     a3, rINST, 12              /* a3<- B */
    srl     s4, rINST, 8               /* s4<- A+ */
    GET_VREG(a0, a3)                   /* a0<- vB (object) */
    andi    s4, s4, 15                 /* s4<- A */
    beqz    a0, .L${opcode}_store      /* null obj, not an instance, store a0 */
    lw      a2, offGlue_methodClassDex(rGLUE)    /* a2<- pDvmDex */

    FETCH(a3, 1)                        /* a3<- CCCC */
    lw      a2, offDvmDex_pResClasses(a2)    /* a2<- pDvmDex->pResClasses */
    sll     t6, a3, 2
    addu    t6, t6, a2
    lw      a1, 0(t6)                   /* a1<- resolved class */
    beqz    a1, .L${opcode}_resolve     /* not resolved, do it now */
    lw      a0, offObject_clazz(a0)     /* a0<- obj->clazz */

.L${opcode}_resolved: /* a0=obj->clazz, a1=resolved class */
                                          /* same class (trivial success)? */
    beq     a0, a1, .L${opcode}_trivial   /* yes, trivial finish */
    nop
    b       .L${opcode}_fullcheck       /* no, do full check */
    nop
%break

    /*
     * Trivial test failed, need to perform full check.  This is common.
     *  a0 holds obj->clazz
     *  a1 holds class resolved from CCCC
     *  s4 holds A
     */
.L${opcode}_fullcheck:
    LA(t9,dvmInstanceofNonTrivial)      /* v0<- boolean result */
    jalr    t9
    nop
    move    a0, v0
    /* fall through to ${opcode}_store */

    /*
     * a0 holds boolean result
     * s4 holds A
     */
.L${opcode}_store:
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(a0, s4)                    /* vA<- a0 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */

    /*
     * Trivial test succeeded, save and bail.
     *  s4 holds A
     */
.L${opcode}_trivial:
    li      a0, 1                       /* indicate success */
    /* could b ${opcode}_store, but copying is faster and cheaper */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    SET_VREG(a0, s4)                    /* vA<- a0 */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */

    /*
     * Resolution required.  This is the least-likely path.
     *
     *  a3 holds CCCC
     *  s4 holds A
     */
.L${opcode}_resolve:
    EXPORT_PC()                         /* resolve() could throw */
    lw      a0, offGlue_method(rGLUE)   /* a0<- glue->method */
    move    a1, a3                      /* a1<- CCCC */
    li      a2, 1                       /* a2<- true */
    LA(t9,dvmResolveClass)              /* a0<- resolved ClassObject ptr */
    jalr    t9
    lw      a0, offMethod_clazz(a0)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* yes, handle exception */
    move    a1, v0                      /* a1<- class resolved from CCCC */
    srl     a3, rINST, 12               /* a3<- B */
    GET_VREG(a0, a3)                    /* a0<- vB (object) */
    b       .L${opcode}_resolved        /* pick up where we left off */
    lw      a0, offObject_clazz(a0)     /* a0<- obj->clazz */


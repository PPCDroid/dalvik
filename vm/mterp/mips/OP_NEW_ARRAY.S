%verify "executed"
%verify "negative array length"
%verify "allocation fails"
    /*
     * Allocate an array of objects, specified with the array class
     * and a count.
     *
     * The verifier guarantees that this is an array class, so we don't
     * check for it here.
     */
    /* new-array vA, vB, class@CCCC */
    srl     a0, rINST, 12               /* a0<- B */
    FETCH(a2, 1)                        /* a2<- CCCC */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- pDvmDex */
    GET_VREG(a1, a0)                    /* a1<- vB (array length) */
    lw      a3, offDvmDex_pResClasses(a3)    /* a3<- pDvmDex->pResClasses */
    sll     t4, a2, 2
    addu    t4, t4, a3
    bltz    a1, common_errNegativeArraySize /* negative length, bail */
    lw      a0, 0(t4)                  /* a0<- resolved class */
    EXPORT_PC()                        /* req'd for resolve, alloc */
    beqz    a0, .L${opcode}_resolve    /* if not resolved, do it */

    /*
     * Finish allocation.
     *
     *  a0 holds class
     *  a1 holds array length
     */
.L${opcode}_finish:
    LA(t9,dvmAllocArrayByClass)
    jalr    t9                          /* v0<- call(clazz, length, flags) */
    li      a2, ALLOC_DONT_TRACK        /* don't track in local refs table */
    beqz    v0, common_exceptionThrown  /* yes, handle the exception */
    srl     a2, rINST, 8                /* a2<- A+ */
    FETCH_ADVANCE_INST(2)               /* advance rPC, load rINST */
    andi    a2, a2, 15                  /* a2<- A */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(v0, a2)                    /* vA<- v0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */

%break


    /*
     * Resolve class.  (This is an uncommon case.)
     *
     *  a1 holds array length
     *  a2 holds class ref CCCC
     */
.L${opcode}_resolve:
    lw      a3, offGlue_method(rGLUE)   /* a3<- glue->method */
    move    s4, a1                      /* s4<- length (save) */
    move    a1, a2                      /* a1<- CCCC */
    move    a2, zero                    /* a2<- false */
    LA(t9,dvmResolveClass)
    jalr    t9                          /* v0<- call(clazz, ref) */
    lw      a0, offMethod_clazz(a3)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* yes, handle exception */
    move    a1, s4                      /* a1<- length (restore) */
    b       .L${opcode}_finish
    move    a0, v0


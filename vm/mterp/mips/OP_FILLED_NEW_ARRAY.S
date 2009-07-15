%default { "isrange":"0" }
%verify "executed"
%verify "unimplemented array type"
    /*
     * Create a new array with elements filled from registers.
     *
     * for: filled-new-array, filled-new-array/range
     */
    /* op vB, {vD, vE, vF, vG, vA}, class@CCCC */
    /* op {vCCCC..v(CCCC+AA-1)}, type@BBBB */
    lw      a3, offGlue_methodClassDex(rGLUE)    /* a3<- pDvmDex */
    FETCH(a1, 1)                        /* a1<- BBBB */
    lw      a3, offDvmDex_pResClasses(a3)    /* a3<- pDvmDex->pResClasses */
    EXPORT_PC()                         /* need for resolve and alloc */
    sll     t4, a1, 2
    addu    t4, t4, a3
    lw      v0, 0(a3)                   /* v0<- resolved class */
    srl     s4, rINST, 8                /* s4<- AA or BA */
    bnez    v0, .L${opcode}_continue    /* if resolved, continue on */
    lw      a3, offGlue_method(rGLUE)   /* a3<- glue->method */
    move    a2, zero                    /* a2<- false */
    LA(t9,dvmResolveClass)
    jalr    t9                          /* v0<- call(clazz, ref) */
    lw      a0, offMethod_clazz(a3)     /* a0<- method->clazz */
    beqz    v0, common_exceptionThrown  /* if null, handle exception */
    nop
    b       .L${opcode}_continue
    nop
%break

    /*
     * On entry:
     *  v0 holds array class
     *  s4 holds AA or BA
     */
.L${opcode}_continue:
    lw      a3, offClassObject_descriptor(v0) /* a3<- arrayClass->descriptor */
    li      a2, ALLOC_DONT_TRACK        /* a2<- alloc flags */
    lbu     a3, 1(a3)                   /* a3<- descriptor[1] */
    .if     $isrange
    move    a1, s4                      /* a1<- AA (length) */
    .else
    srl     a1, s4, 4                   /* a1<- B (length) */
    .endif
    move    s5, a1                      /* save length in s5 */
    subu    t4, a3, 'I'                 /* array of ints? */
    beqz    t4, .L${opcode}_impl
    subu    t4, a3, 'L'                 /* array of objects? */
    beqz    t4, .L${opcode}_impl
    subu    t4, a3, '['                 /* array of arrays? */
    bnez    t4, .L${opcode}_notimpl     /* no, not handled yet */
.L${opcode}_impl:
    LA(t9,dvmAllocArrayByClass)
    jalr    t9                          /* v0<- call(arClass, length, flags) */
    move    a0, v0
    beqz    v0, common_exceptionThrown  /* alloc failed, handle exception */

    FETCH(a1, 2)                        /* a1<- FEDC or CCCC */
    sw      v0, offGlue_retval(rGLUE)   /* retval.l <- new array */
    addu    a0, v0, offArrayObject_contents /* a0<- newArray->contents */
    subu    s5, s5, 1                   /* length--, check for neg */
    FETCH_ADVANCE_INST(3)               /* advance to next instr, load rINST */
    bltz    s5, 2f                      /* length was zero, bail */

    /* copy values from registers into the array
     * a0=array, a1=CCCC/FEDC, s5=length (from AA or B), s4=AA/BA
     */
    .if     $isrange
    sll     t4, a1, 2
    add     a2, rFP, t4                 /* a2<- &fp[CCCC] */
1:  lw      a3, 0(a2)                   /* a3<- *a2 */
    subu    s5, s5, 1                   /* count-- */
    sw      a3, 0(a0)                   /* *contents = vX */
    addi    a2, a2, 4                   /* a2++ */
    bgez    s5, 1b
    addi    a0, a0, 4			/* contents++ */
    /* continue at 2 */
    .else
    subu    t4, s5, 4                   /* length was initially 5? */
    andi    a2, s4, 15                  /* a2<- A */
    bnez    t4, 1f                      /* <= 4 args, branch */
    GET_VREG(a3, a2)                    /* a3<- vA */
    subu    s5, s5, 1                   /* count-- */
    sw      a3, 16(a0)                  /* contents[4] = vA */
1:  andi    a2, a1, 15                  /* a2<- F/E/D/C */
    GET_VREG(a3, a2)                    /* a3<- vF/vE/vD/vC */
    srl     a1, a1, 4                   /* a1<- next reg in low 4 */
    subu    s5, s5, 1                   /* count-- */
    sw      a3, 0(a0)                   /* *contents = vX */
    bgez    s5,1b
    addi    a0, a0, 4			/* contents++ */
    /* continue at 2 */
    .endif

2:
    GET_INST_OPCODE(t7)                 /* t7<- opcode from rINST */
    GOTO_OPCODE(t7)                     /* execute it */

    /*
     * Throw an exception indicating that we have not implemented this
     * mode of filled-new-array.
     */
.L${opcode}_notimpl:
    move    gp, s8
    la      a0, .strInternalError
    la      a1, .strFilledNewArrayNotImpl
    la      t9, dvmThrowException
    jalr    t9
    nop
    b       common_exceptionThrown
    nop


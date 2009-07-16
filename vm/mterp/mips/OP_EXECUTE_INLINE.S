%verify "executed"
%verify "exception handled"
    /*
     * Execute a "native inline" instruction.
     *
     * We need to call:
     *  dvmPerformInlineOp4Std(arg0, arg1, arg2, arg3, &retval)
     *
     * The first four args are in a0-a3, but the last one must be pushed
     * onto the stack.
     */
    /* [opt] execute-inline vAA, {vC, vD, vE, vF}, inline@BBBB */
    FETCH(s4, 1)                        /* r10<- BBBB */
    addiu    a1, rGLUE, offGlue_retval  /* r1<- &glue->retval */
    EXPORT_PC()                         /* can throw */
    addiu   sp, sp, -8                  /* make room for arg(s) + align */
    sw      a1, 16(sp)                  /* push &glue->retval */
    FETCH(s5, 2)                        /* r9<- FEDC */
    bal     .L${opcode}_continue        /* make call; will return after */
    srl     a0, rINST, 12               /* r0<- B */
    addiu   sp, sp, 8                   /* pop stack */
    beqz    v0, common_exceptionThrown  /* returned false, handle exception */
    FETCH_ADVANCE_INST(3)               /* advance rPC, load rINST */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */
%break

    /*
     * Extract args, call function.
     *  a0 = #of args (0-4)
     *  s4 = call index
     *  lr = return addr, above  [DO NOT bl out of here w/o preserving LR]
     *
     * I debated with the cost of testing and branching versus just always
     * loading all registers.  Since I thought error checking for >4 and
     * branching around all of the loads if arg==0 was all good, I just
     * left the cost of the other three test/branch there as well.  It would
     * also be nice if we could error check the call index, but this isn't
     * even done in the portable version, assumes Dexopt always does the
     * right thing.  -- Dan
     */
.L${opcode}_continue:
#if 1
    beqz    a0, 0f
    subu    t5, a0, 1
    beqz    t5, 1f
    subu    t5, a0, 2
    beqz    t5, 2f
    subu    t5, a0, 3
    beqz    t5, 3f
    subu    t5, a0, 4
    bgtz    t5, common_abort
#else
    /* This is cute, too, but doesn't save any instructions and makes the
     * fewer arg path longer.
     */
    subu    t5, a0, 4
    bgtz    t5, common_abort
    li      t6, 4
    subu    t6, t6, a0
    sll     t6, t6, 4
    LA(t5, 4f)
    addu    t5, t5, t6
    jr      t5
    nop
#endif

4:  andi    t7, s5, 0xf000             /* isolate F */
    srl     t7, t7, 10
    addu    t7, t7, rFP
    lw      a3, 0(t7)                  /* a3<- vF (shift right 12, left 2) */
3:  andi    t7, s5, 0x0f00             /* isolate E */
    srl     t7, t7, 6
    addu    t7, t7, rFP
    lw      a2, 0(t7)                  /* a2<- vE */
2:  andi    t7, s5, 0x00f0             /* isolate D */
    srl     t7, t7, 2
    addu    t7, t7, rFP
    lw      a1, 0(t7)                  /* a1<- vD */
1:  andi    t7, s5, 0x000f             /* isolate C */
    sll     t7, t7, 2
    addu    t7, t7, rFP
    lw      a0, 0(t7)                  /* a0<- vC */
0:
    LA(t7, gDvmInlineOpsTable)         /* table of InlineOperation */
    sll     s4, s4, 4                  /* sizeof=16, "func" is first entry */
    addu    t7, t7, s4
    lw      t9, 0(t7)
    jr      t9
    nop /* (not reached) */



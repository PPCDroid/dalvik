%verify "executed"
%verify "exception for null object"
    /*
     * Synchronize on an object.
     */
    /* monitor-enter vAA */
    srl     a2, rINST, 8              /* a2<- AA */
    GET_VREG(a1, a2)                  /* a1<- vAA (object) */
    lw      a0, offGlue_self(rGLUE)   /* a0<- glue->self */
#ifdef WITH_MONITOR_TRACKING
    EXPORT_PC()                       /* export PC so we can grab stack trace */
#endif
    beqz    a1, common_errNullObject  /* null object, throw an exception */
    LA(t9,dvmLockObject)              /* call(self, obj) */
    FETCH_ADVANCE_INST(1)             /* advance rPC, load rINST */
    jalr    t9
    nop
#ifdef WITH_DEADLOCK_PREDICTION /* implies WITH_MONITOR_TRACKING */
    lw      a0, offGlue_self(rGLUE)     /* a0<- glue->self */
    lw      a1, offThread_exception(a0) /* check for exception */
    bnez    a1, common_exceptionThrown  /* exception raised, bail out */
    nop
#endif
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


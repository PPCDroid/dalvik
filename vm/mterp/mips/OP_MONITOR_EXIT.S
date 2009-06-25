%verify "executed"
%verify "exception for null object (impossible in javac)"
%verify "dvmUnlockObject fails"
    /*
     * Unlock an object.
     *
     * Exceptions that occur when unlocking a monitor need to appear as
     * if they happened at the following instruction.  See the Dalvik
     * instruction spec.
     */
    /* monitor-exit vAA */
    srl     a2, rINST, 8                /* a2<- AA */
    EXPORT_PC()                         /* before fetch: export the PC */
    GET_VREG(a1, a2)                    /* a1<- vAA (object) */
    beqz    a1, common_errNullObject    /* error if null object */
    LA(t9,dvmUnlockObject)
    jalr    t9                          /* v0<- success for unlock(self, obj) */
    lw      a0, offGlue_self(rGLUE)     /* a0<- glue->self */
    FETCH_ADVANCE_INST(1)            /* before throw: advance rPC, load rINST */
    beqz    v0, common_exceptionThrown  /* if failed, exception is pending */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


%verify "executed"
%verify "exception for null object"
    /*
     * Throw an exception object in the current thread.
     */
    /* throw vAA */
    srl     a2, rINST, 8                /* a2<- AA */
    GET_VREG(a1, a2)                    /* a1<- vAA (exception object) */
    lw      a0, offGlue_self(rGLUE)     /* a0<- glue->self */
    beqz    a1, common_errNullObject    /* yes, throw an NPE instead */
    nop

    /* bypass dvmSetException, just store it */
    b       common_exceptionThrown
    sw      a1, offThread_exception(a0)  /* thread->exception<- obj */


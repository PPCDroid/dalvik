%verify "executed"
    /*
     * Return a 32-bit value.  Copies the return value into the "glue"
     * structure, then jumps to the return handler.
     *
     * for: return, return-object
     */
    /* op vAA */
    srl     a2, rINST, 8                /* r2<- AA */
    GET_VREG(a0, a2)                    /* a0<- vAA */
    b       common_returnFromMethod
    sw      a0, offGlue_retval(rGLUE)   /* retval.i <- vAA */


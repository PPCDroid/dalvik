%verify "executed"
    /*
     * Return a 64-bit value.  Copies the return value into the "glue"
     * structure, then jumps to the return handler.
     */
    /* return-wide vAA */
    srl     a2, rINST, 6               /* a2<- AA */
    andi    a2, a2, 0x3fc	       /* a2<- AA*4 */
    add     a2, rFP, a2                /* a2<- &fp[AA] */
    add     a3, rGLUE, offGlue_retval  /* a3<- &glue->retval */
    lw      a0, 0(a2)                  /* a0/a1 <- vAA/vAA+1 */
    lw      a1, 4(a2)
    sw      a0, 0(a3)                  /* retval<- a0/a1 */
    b       common_returnFromMethod
    sw      a1, 4(a3)


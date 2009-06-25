%verify "executed"
    /* const vAA, #+BBBBbbbb */
    /* I wanted to use LWL/LWR here to eliminate the shift and or, but
     * they don't even come close to correct on LE.  They could be used for BE.
     */
    srl     a3, rINST, 8                /* a3<- AA */
    FETCH(a1, 2)                        /* a1<- BBBB (high) */
    FETCH(a0, 1)                        /* a0<- bbbb (low) */
    sll     a1, a1, 16			/* a1<- BBBBxxxx */
    FETCH_ADVANCE_INST(3)               /* advance rPC, load rINST */
    or      a0, a0, a1                  /* a0<- BBBBbbbb */
    GET_INST_OPCODE(t7)                 /* extract opcode from rINST */
    SET_VREG(a0, a3)                    /* vAA<- a0 */
    GOTO_OPCODE(t7)                     /* jump to next instruction */


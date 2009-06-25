%verify "executed"
%verify "negative value is sign-extended"
/* include "mips/OP_IGET.S" { "load":"lb", } */
%include "mips/OP_IGET.S" { "load":"lw", }

%verify "executed"
%verify "negative value is sign-extended"
/* include "mips/OP_IGET.S" { "load":"lh" } */
%include "mips/OP_IGET.S" { "load":"lw" }

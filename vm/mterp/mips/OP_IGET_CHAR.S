%verify "executed"
%verify "large values are not sign-extended"
/* include "mips/OP_IGET.S" { "load":"lhu", } */
%include "mips/OP_IGET.S" { "load":"lw" }

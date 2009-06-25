%verify "executed"
/* include "mips/OP_IGET.S" { "load":"lbu" } */
%include "mips/OP_IGET.S" { "load":"lw" }

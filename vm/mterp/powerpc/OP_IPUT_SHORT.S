%verify "executed"
%include "powerpc/OP_IPUT.S" { "store":"stwx", "mask":"extsh	r3, r3" }

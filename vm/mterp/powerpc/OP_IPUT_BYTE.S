%verify "executed"
%include "powerpc/OP_IPUT.S" { "store":"stwx", "mask":"extsb	r3, r3" }

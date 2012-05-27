%verify "executed"
%include "powerpc/OP_IPUT.S" { "store":"stwx", "mask":"clrlwi	r3, r3, 16" }

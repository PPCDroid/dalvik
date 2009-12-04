%verify "executed"
%include "ppc/OP_IGET.S" { "load":"lwzx", "mask":"clrlwi	r3, r3, 24" }

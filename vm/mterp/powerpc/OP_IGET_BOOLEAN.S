%verify "executed"
%include "powerpc/OP_IGET.S" { "load":"lwzx", "mask":"clrlwi	r3, r3, 24" }

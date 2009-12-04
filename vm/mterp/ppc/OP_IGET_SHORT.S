%verify "executed"
%verify "negative value is sign-extended"
%include "ppc/OP_IGET.S" { "load":"lwzx", "mask":"clrlwi	r3, r3, 16" }

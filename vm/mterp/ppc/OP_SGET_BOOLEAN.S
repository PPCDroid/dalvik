%verify "executed"
%include "ppc/OP_SGET.S" { "mask":"clrlwi	r3, r3, 24" }

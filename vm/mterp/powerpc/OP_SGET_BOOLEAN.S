%verify "executed"
%include "powerpc/OP_SGET.S" { "mask":"clrlwi	r3, r3, 24" }

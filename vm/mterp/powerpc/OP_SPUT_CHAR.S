%verify "executed"
%include "powerpc/OP_SPUT.S" { "mask":"clrlwi	r4, r4, 16" }

%verify "executed"
%verify "negative value is sign-extended"
%include "powerpc/OP_IGET.S" { "load":"lwzx", "mask":"extsh	r3, r3" }

%verify "executed"
%include "mips/binop2addr.S" {"preinstr":"div    zero, a0, a1", "instr":"mfhi    v0","chkzero":"1"}

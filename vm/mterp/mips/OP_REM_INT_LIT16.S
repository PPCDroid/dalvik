%verify "executed"
%include "mips/binopLit16.S" {"preinstr":"div    zero, a0, a1", "instr":"mfhi    v0","chkzero":"1"}

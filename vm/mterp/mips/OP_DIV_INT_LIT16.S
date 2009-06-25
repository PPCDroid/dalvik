%verify "executed"
%include "mips/binopLit16.S" {"preinstr":"div    zero, a0, a1", "instr":"mflo    v0","chkzero":"1"}

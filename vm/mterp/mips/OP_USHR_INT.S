%verify "executed"
%include "mips/binop.S" {"preinstr":"andi    a1, a1, 31", "instr":"srlv     v0, a0, a1"}

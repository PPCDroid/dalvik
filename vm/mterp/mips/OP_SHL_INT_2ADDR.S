%verify "executed"
%include "mips/binop2addr.S" {"preinstr":"andi    a1, a1, 31", "instr":"sllv     v0, a0, a1"}

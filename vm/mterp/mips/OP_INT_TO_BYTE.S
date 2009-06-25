%verify "executed"
%include "mips/unop.S" {"preinstr":"sll     v0, a0, 24", "instr":"sra     v0, v0, 24"}

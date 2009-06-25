%verify "executed"
%include "mips/unop.S" {"preinstr":"sll     v0, a0, 16", "instr":"srl     v0, v0, 16"}

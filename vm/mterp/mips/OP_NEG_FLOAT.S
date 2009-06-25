%verify "executed"
%include "mips/unop.S" {"preinstr":"lui    v1, 0x8000", "instr":"xor     v0, a0, v1"}

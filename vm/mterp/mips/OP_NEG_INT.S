%verify "executed"
%include "mips/unop.S" {"instr":"subu    v0, zero, a0"}

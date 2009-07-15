%verify "executed"
%include "mips/binop.S" {"preinstr":"LA(t9, fmodf)", "instr":"jalr  t9; nop"}

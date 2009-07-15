%verify "executed"
%include "mips/binop.S" {"preinstr":"LA(t9, __divsf3)", "instr":"jalr  t9; nop"}

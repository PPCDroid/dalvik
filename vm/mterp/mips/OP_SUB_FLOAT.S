%verify "executed"
%include "mips/binop.S" {"preinstr":"LA(t9, __subsf3)", "instr":"jalr  t9; nop"}

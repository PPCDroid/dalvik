%verify "executed"
%include "mips/binop2addr.S" {"preinstr":"LA(t9, __subsf3)", "instr":"jalr   t9; nop"}

%verify "executed"
%include "mips/binop2addr.S" {"preinstr":"LA(t9, fmodf)", "instr":"jalr   t9; nop"}

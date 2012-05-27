%verify "executed"
%include "powerpc/binop-double.S" {"instr":"fdiv	f1, f1, f2" }

%verify "executed"
%include "powerpc/binop-double.S" {"instr":"fadd	f1, f1, f2" }

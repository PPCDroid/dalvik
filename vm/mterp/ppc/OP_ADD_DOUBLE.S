%verify "executed"
%include "ppc/binop-double.S" {"instr":"fadd	f1, f1, f2" }

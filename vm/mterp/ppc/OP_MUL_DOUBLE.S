%verify "executed"
%include "ppc/binop-double.S" {"instr":"fmul	f1, f1, f2" }

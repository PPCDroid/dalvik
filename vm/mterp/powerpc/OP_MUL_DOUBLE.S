%verify "executed"
%include "powerpc/binop-double.S" {"instr":"fmul	f1, f1, f2" }

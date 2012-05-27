%verify "executed"
%include "powerpc/binop2addr-double.S" {"instr":"fmul	f1, f1, f2"}

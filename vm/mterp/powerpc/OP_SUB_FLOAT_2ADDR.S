%verify "executed"
%include "powerpc/binop2addr-float.S" {"instr":"fsubs	f1, f1, f2"}

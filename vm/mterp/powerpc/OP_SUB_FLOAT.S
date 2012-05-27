%verify "executed"
%include "powerpc/binop-float.S" {"instr":"fsubs	f1, f1, f2"}

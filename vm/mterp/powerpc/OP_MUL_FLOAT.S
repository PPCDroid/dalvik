%verify "executed"
%include "powerpc/binop-float.S" {"instr":"fmuls	f1, f1, f2"}

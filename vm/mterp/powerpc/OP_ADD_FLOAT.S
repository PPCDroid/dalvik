%verify "executed"
%include "powerpc/binop-float.S" {"instr":"fadds	f1, f1, f2"}

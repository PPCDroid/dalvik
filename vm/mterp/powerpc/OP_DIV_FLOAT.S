%verify "executed"
%include "powerpc/binop-float.S" {"instr":"fdivs	f1, f1, f2"}

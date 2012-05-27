%verify "executed"
%include "powerpc/binop2addr-float.S" {"instr":"fdivs	f1, f1, f2"}

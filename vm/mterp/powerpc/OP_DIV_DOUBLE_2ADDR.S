%verify "executed"
%include "powerpc/binop2addr-double.S" {"instr":"fdiv	f1, f1, f2"}

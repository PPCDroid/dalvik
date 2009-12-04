%verify "executed"
%include "ppc/binop2addr-double.S" {"instr":"fdiv	f1, f1, f2"}

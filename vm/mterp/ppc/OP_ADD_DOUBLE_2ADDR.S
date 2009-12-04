%verify "executed"
%include "ppc/binop2addr-double.S" {"instr":"fadd	f1, f1, f2"}

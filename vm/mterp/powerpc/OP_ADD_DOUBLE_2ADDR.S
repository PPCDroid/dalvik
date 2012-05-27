%verify "executed"
%include "powerpc/binop2addr-double.S" {"instr":"fadd	f1, f1, f2"}

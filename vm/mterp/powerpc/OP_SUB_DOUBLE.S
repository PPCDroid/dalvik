%verify "executed"
%include "powerpc/binop-double.S" {"instr":"fsub	f1, f1, f2" }

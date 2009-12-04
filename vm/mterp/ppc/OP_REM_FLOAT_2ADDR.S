%verify "executed"
%include "ppc/binop2addr-float.S" {"instr":"bl fmodf@plt"}

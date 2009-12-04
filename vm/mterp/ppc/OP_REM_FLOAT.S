%verify "executed"
%include "ppc/binop-float.S" {"instr":"bl fmodf@plt"}

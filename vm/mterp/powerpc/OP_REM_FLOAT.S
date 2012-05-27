%verify "executed"
%include "powerpc/binop-float.S" {"instr":"bl fmodf@plt"}

%verify "executed"
%include "powerpc/binop2addr-float.S" {"instr":"bl fmodf@plt"}

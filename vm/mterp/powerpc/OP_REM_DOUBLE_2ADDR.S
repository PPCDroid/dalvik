%verify "executed"
%include "powerpc/binop2addr-double.S" {"instr":"bl fmod@plt"}

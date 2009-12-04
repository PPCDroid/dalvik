%verify "executed"
%include "ppc/binop2addr-double.S" {"instr":"bl fmod@plt"}

%verify "executed"
%include "powerpc/binop-double.S" {"instr":"bl	fmod@plt"}

%verify "executed"
%include "powerpc/binop.S" {"preinstr":"andi.	r4, r4, 31", "instr":"sraw	r3, r3, r4"}

%verify "executed"
%include "powerpc/binop2addr.S" {"preinstr":"andi.	r4, r4, 31", "instr":"slw	r3, r3, r4"}

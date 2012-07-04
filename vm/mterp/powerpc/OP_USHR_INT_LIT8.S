%verify "executed"
%include "powerpc/binopLit8.S" {"preinstr":"andi.	r4, r4, 31", "instr":"srw	r3, r3, r4"}

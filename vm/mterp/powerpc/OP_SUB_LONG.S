%verify "executed"
%include "powerpc/binopWide.S" {"preinstr":"subfc	r4, r6, r4", "instr":"subfe	r3, r5, r3"}

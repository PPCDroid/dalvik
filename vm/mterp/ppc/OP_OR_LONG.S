%verify "executed"
%include "ppc/binopWide.S" {"preinstr":"or	r4, r4, r6", "instr":"or	r3, r3, r5"}

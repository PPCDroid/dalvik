%verify "executed"
%include "powerpc/binopWide2addr.S" {"preinstr":"and	r4, r4, r6", "instr":"and	r3, r3, r5"}

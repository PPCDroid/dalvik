%verify "executed"
%include "powerpc/binopWide2addr.S" {"preinstr":"addc	r4, r4, r6", "instr":"adde	r3, r3, r5"}

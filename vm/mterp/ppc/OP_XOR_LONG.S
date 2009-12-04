%verify "executed"
%include "ppc/binopWide.S" {"preinstr":"xor	r4, r4, r6", "instr":"xor	r3, r3, r5"}

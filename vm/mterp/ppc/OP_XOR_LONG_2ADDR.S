%verify "executed"
%include "ppc/binopWide2addr.S" {"preinstr":"xor	r4, r4, r6", "instr":"xor	r3, r5, r3"}

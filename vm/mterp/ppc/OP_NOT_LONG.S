%verify "executed"
%include "ppc/unopWide.S" {"preinstr":"not	r3, r3", "instr":"not	r4, r4"}

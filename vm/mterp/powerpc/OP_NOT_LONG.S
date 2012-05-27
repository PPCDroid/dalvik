%verify "executed"
%include "powerpc/unopWide.S" {"preinstr":"not	r3, r3", "instr":"not	r4, r4"}

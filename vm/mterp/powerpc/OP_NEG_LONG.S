%verify "executed"
%include "powerpc/unopWide.S" {"preinstr":"subfic	r4,r4,0", "instr":"subfze	r3,r3"}

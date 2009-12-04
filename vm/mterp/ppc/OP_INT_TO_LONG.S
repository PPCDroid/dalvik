%verify "executed"
%include "ppc/unopWider.S" {"preinstr":"mr r4, r3", "instr":"srawi r3, r3, 31"}

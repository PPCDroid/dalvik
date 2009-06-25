%verify "executed"
%include "mips/unopWide.S" {"preinstr":"nor     v0, zero, a0", "instr":"nor     v1, zero, a1"}

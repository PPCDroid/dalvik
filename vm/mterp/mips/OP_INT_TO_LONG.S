%verify "executed"
%include "mips/unopWider.S" {"preinstr":"move   v0, a0", "instr":"sra     v1, a0, 31"}

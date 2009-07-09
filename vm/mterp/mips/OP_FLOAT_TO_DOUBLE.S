%verify "executed"
%include "mips/unopWider.S" {"preinstr":"LA(t9, __extendsfdf2)", "instr":"jalr      t9"}

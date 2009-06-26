%verify "executed"
%include "mips/binopWide2addr.S" {"instr1":"subu    v0, a0, a2; sltu t7,a0,v0", "instr2":"subu     t6, a1, a3; subu v1,t6,t7"}

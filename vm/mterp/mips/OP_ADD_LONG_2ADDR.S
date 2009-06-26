%verify "executed"
%include "mips/binopWide2addr.S" {"instr1":"addu    v0, a0, a2; sltu t7,v0,a0", "instr2":"addu     t6, a1, a3; addu v1,t6,t7"}

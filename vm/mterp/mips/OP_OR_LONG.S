%verify "executed"
%include "mips/binopWide.S" {"instr1":"or     v0, a0, a2", "instr2":"or      v1, a1, a3"}

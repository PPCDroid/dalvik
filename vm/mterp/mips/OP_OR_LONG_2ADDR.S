%verify "executed"
%include "mips/binopWide2addr.S" {"instr1":"or     v0, a0, a2", "instr2":"or      v0, a1, a3"}

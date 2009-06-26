%verify "executed"
%include "mips/binopWide.S" {"instr1":"and     v0, a0, a2", "instr2":"and      v1, a1, a3"}

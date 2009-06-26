%verify "executed"
%include "mips/binopWide.S" {"instr1":"xor     v0, a0, a2", "instr2":"xor      v0, a1, a3"}

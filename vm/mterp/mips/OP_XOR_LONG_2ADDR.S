%verify "executed"
%include "mips/binopWide2addr.S" {"instr1":"xor     v0, a0, a2", "instr2":"xor      v1, a1, a3"}

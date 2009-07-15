%verify "executed"
%include "mips/binopWide.S" {"instr1":"LA(t9, fmod)", "instr2":"jalr   t9; nop"}

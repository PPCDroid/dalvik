%verify "executed"
%include "mips/binopWide.S" {"instr1":"LA(t9, __subdf3)", "instr2":"jalr   t9; nop"}

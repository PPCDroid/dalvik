%verify "executed"
%include "mips/binopWide2addr.S" {"instr1":"LA(t9, __adddf3)", "instr2":"jalr   t9; nop"}

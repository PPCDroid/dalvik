%verify "executed"
%include "powerpc/binopWide2addr.S" {"instr":"bl __divdi3@plt", "chkzero":"1"}

%verify "executed"
%include "powerpc/binopWide.S" {"instr":"bl __divdi3@plt", "chkzero":"1"}

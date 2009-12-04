%verify "executed"
%include "ppc/binopWide.S" {"instr":"bl __divdi3@plt", "chkzero":"1"}

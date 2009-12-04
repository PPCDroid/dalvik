%verify "executed"
%include "ppc/binopWide.S" {"instr":"bl __moddi3@plt", "chkzero":"1"}

%verify "executed"
%include "powerpc/binopWide.S" {"instr":"bl __moddi3@plt", "chkzero":"1"}

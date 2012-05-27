%verify "executed"
%include "powerpc/binopWide2addr.S" {"instr":"bl __moddi3@plt", "chkzero":"1"}

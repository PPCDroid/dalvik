%verify "executed"
%include "ppc/binopWide2addr.S" {"instr":"bl __moddi3@plt", "chkzero":"1"}

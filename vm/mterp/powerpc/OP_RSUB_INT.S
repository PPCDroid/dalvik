%verify "executed"
/* this op is "rsub-int", but can be thought of as "rsub-int/lit16" */
%include "powerpc/binopLit16.S" {"instr":"sub     r3, r4, r3"}

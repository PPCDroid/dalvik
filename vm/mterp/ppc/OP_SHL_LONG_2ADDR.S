%verify "executed"
%include "ppc/fragWide2addr-shift-prolog.S" { }
%include "ppc/fragWide-shift.S" { "shl":"1" }
%include "ppc/fragWide2addr-shift-epilog.S" { }

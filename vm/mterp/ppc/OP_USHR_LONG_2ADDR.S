%verify "executed"
%include "ppc/fragWide2addr-shift-prolog.S" { }
%include "ppc/fragWide-shift.S" { "ushr":"1" }
%include "ppc/fragWide2addr-shift-epilog.S" { }

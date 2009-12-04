%verify "executed"
%include "ppc/fragWide-shift-prolog.S" { }
%include "ppc/fragWide-shift.S" { "ushr":"1" }
%include "ppc/fragWide-shift-epilog.S" { }

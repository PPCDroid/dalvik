%verify "executed"
%include "powerpc/fragWide-shift-prolog.S" { }
%include "powerpc/fragWide-shift.S" { "ushr":"1" }
%include "powerpc/fragWide-shift-epilog.S" { }

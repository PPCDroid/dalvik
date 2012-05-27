%verify "executed"
%include "powerpc/fragWide-shift-prolog.S" { }
%include "powerpc/fragWide-shift.S" { "shr":"1" }
%include "powerpc/fragWide-shift-epilog.S" { }

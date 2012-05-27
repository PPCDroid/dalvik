%verify "executed"
%include "powerpc/fragWide-shift-prolog.S" { }
%include "powerpc/fragWide-shift.S" { "shl":"1" }
%include "powerpc/fragWide-shift-epilog.S" { }

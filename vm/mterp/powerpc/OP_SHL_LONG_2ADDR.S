%verify "executed"
%include "powerpc/fragWide2addr-shift-prolog.S" { }
%include "powerpc/fragWide-shift.S" { "shl":"1" }
%include "powerpc/fragWide2addr-shift-epilog.S" { }

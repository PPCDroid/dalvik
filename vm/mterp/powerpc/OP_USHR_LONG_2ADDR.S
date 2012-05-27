%verify "executed"
%include "powerpc/fragWide2addr-shift-prolog.S" { }
%include "powerpc/fragWide-shift.S" { "ushr":"1" }
%include "powerpc/fragWide2addr-shift-epilog.S" { }

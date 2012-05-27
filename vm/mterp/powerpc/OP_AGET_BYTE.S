%verify "executed"
%include "powerpc/OP_AGET.S" { "load":"lbz", "shift":"0", "exts":"extsb"  }

%verify "executed"
%include "ppc/OP_AGET.S" { "load":"lbz", "shift":"0", "exts":"extsb"  }

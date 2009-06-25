%verify "executed"
/* The ARM opcodes use an "asl" instructions, but there is no such thing.
 * The gcc/gas just silently turns this into an "lsl", so we really just
 * want to strip the uppper 16 bits of the word.
 */
%include "mips/unop.S" {"preinstr":"sll     v0, a0, 16", "instr":"srl     v0, v0, 16"}

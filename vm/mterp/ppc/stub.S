	/* stub for ${opcode} */
	SAVE_PC_FP_TO_GLUE()		/* only need to export these two */
	mr	r3, rGLUE		/* glue is first arg to function */
	bl	dvmMterp_${opcode}@plt	/* call */
	LOAD_PC_FP_FROM_GLUE()		/* retrieve updated values */
#ifdef KEEP_RES_FIELDS_IN_REGS
	lwz	rResStr, offGlue_methodClassDex(rGLUE)
	lwz	rResFld, offDvmDex_pResFields(rResStr)
	lwz	rResCls, offDvmDex_pResClasses(rResStr)
	lwz	rResStr, offDvmDex_pResStrings(rResStr)
#endif
	FETCH_INST()			/* load next instruction from rPC */
	GET_INST_OPCODE_GOTO(r0)	/* ...trim down to just the opcode */

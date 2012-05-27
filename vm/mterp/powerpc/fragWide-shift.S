%default {"result0":"r3", "result1":"r4", "shl":"0", "shr":"0", "ushr":"0" }

	addic.	r0,r5,-32
	blt-	0f

	.if $shl
	slw	r3,r4,r0
	li	r4,0
	b	1f
0:	rlwinm	r6,r4,31,1,31
	subfic	r9,r5,31
	srw	r0,r6,r9
	slw	r3,r3,r5
	or	r3,r0,r3
	slw	r4,r4,r5
	.endif

	.if $ushr
	srw	r4,r3,r0
	li	r3,0
	b	1f
0:	rlwinm	r6,r3,1,0,30
	subfic	r9,r5,31
	slw	r0,r6,r9
	srw	r4,r4,r5
	or	r4,r0,r4
	srw	r3,r3,r5
	.endif

	.if $shr
	sraw	r4,r3,r0
	srawi	r3,r3,31
	b	1f
0:	rlwinm	r6,r3,1,0,30
	subfic	r9,r5,31
	slw	r0,r6,r9
	srw	r4,r4,r5
	or	r4,r0,r4
	sraw	r3,r3,r5
	.endif
1:

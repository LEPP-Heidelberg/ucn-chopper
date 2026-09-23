	.section	.text
	.global		__MicoEFB_ASHLHI3
	.type		__MicoEFB_ASHLHI3, @function
__MicoEFB_ASHLHI3:
	testi	r2,0xff
	bz		.L2
.L1:
	clrc
	rolc	r0,r0
	rolc	r1,r1
	addi	r2,-1
	bnz		.L1
.L2:
	ret
	.size		__MicoEFB_ASHLHI3, .-__MicoEFB_ASHLHI3

	// 
	.section	.text
	.global		__MicoEFB_GT
	.type		__MicoEFB_GT, @function
__MicoEFB_GT:
	cmp		r1, r3
	bc		.L5
	bnz		.L6
	cmp		r0, r2
	bc		.L5
	bnz		.L6
.L5:
	movi	r0, 0
	b		.L7
.L6:
	movi	r0, 1
.L7:
	ret
	.size		__MicoEFB_GT, .-__MicoEFB_GT


	//
	.section	.text
	.global		__MicoEFB_LO
	.type		__MicoEFB_LO, @function
__MicoEFB_LO:
	ret
	.size		__MicoEFB_LO, .-__MicoEFB_LO


	//
	.section	.text
	.global		__MicoEFB_HI
	.type		__MicoEFB_HI, @function
__MicoEFB_HI:
	mov		r0, r1
	ret
	.size		__MicoEFB_HI, .-__MicoEFB_HI


	//
	.section	.text
	.global		__MicoEFB_HIGHER
	.type		__MicoEFB_HIGHER, @function
__MicoEFB_HIGHER:
	mov		r0, r2
	ret
	.size		__MicoEFB_HIGHER, .-__MicoEFB_HIGHER


	//
	.section	.text
	.global		__MicoEFB_HIGHEST
	.type		__MicoEFB_HIGHEST, @function
__MicoEFB_HIGHEST:
	mov		r0, r3
	ret
	.size		__MicoEFB_HIGHEST, .-__MicoEFB_HIGHEST
	
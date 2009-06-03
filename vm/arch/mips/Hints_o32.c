/*
 * Copyright (C) 2008 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
/*
 * Target-specific optimization and run-time hints for MIPS O32 ABI
 */


#include "Dalvik.h"
#include "libdex/DexClass.h"

#include <stdlib.h>
#include <stddef.h>
#include <sys/stat.h>


/*
 * The class loader will associate with each method a 32-bit info word
 * (jniArgInfo) to support JNI calls.  The high order 4 bits of this word
 * are the same for all targets, while the lower 28 are used for hints to
 * allow accelerated JNI bridge transfers.
 *
 * jniArgInfo (32-bit int) layout:
 *
 *    SRRRHHHH HHHHHHHH HHHHHHHH HHHHHHHH
 *
 *    S - if set, ignore the hints and do things the hard way (scan signature)
 *    R - return-type enumeration
 *    H - target-specific hints (see below for details)
 *
 * This function produces mips-specific hints - specifically a description
 * of padding required to keep all 64-bit parameters properly aligned.
 *
 * MIPS JNI hint format
 *
 *       FFFF FFFFFFFF FFFFFFFF FFZLLLLM
 *       FFFF FFFFFFFF FFFFFFFF FFZLLLL0
 *       0000 00000000 LLLLLLL LLLLLLLL1
 *
 *   M - If not set, then there are up to 24 arguments with possible padding
 *       If set, the the lower 16-bits indicate the stack size required.
 *   L - number of double-words of storage required on the stack (0-28 words)
 *   Z - always 0.  Mainly due to first arg always aligned, not worth the
 *   	 complexity of trying to pack flags.  dvmPlatformInvoke assembler
 *   	 relies on this to eliminate a masking operation.
 *   F - pad flag -- if set, write a pad word to the stack before copying
 *       the next 32 bits
 *
 *   I aligned the hint this way because it's much easier to test/mask
 *   least significant 16-bits in the assembler instructions.
 *
 * We always pass back a valid hint, unless it's an internal DEX failure
 * that the stack size is too big.  If the M flag is set, the method invoke
 * still needs to scan the signature, but at least we have already
 * computed the stack size required.
 */
#define CONSOUT(DS) write(consfd, DS, strlen(DS))
u4 dvmPlatformInvokeHints(const DexProto* proto)
{
    const char* sig = dexProtoGetShorty(proto);
    u4 padFlags, jniHints;
    char sigByte;
    u4 stackOffset, padMask;
int consfd;
char dbgbuf[32];

    stackOffset = 0;
    padFlags = 0;
    padMask = 0x00000020;

    /* Skip past the return type */
    sig++;

    while (true) {
        sigByte = *(sig++);

        if (sigByte == '\0')
            break;

        if (sigByte == 'D' || sigByte == 'J') {
            if ((stackOffset & 1) != 0) {
                padFlags |= padMask;
                stackOffset++;
            }
            stackOffset++;
            padMask <<= 1;
        }
        stackOffset++;
        padMask <<= 1;
    }

    jniHints = 0;

    /* Add the four arguments in registers, plus one for rounding up.
    */
    stackOffset += 5;

    if (stackOffset > DALVIK_JNI_COUNT_SHIFT) {

        /* too big for "fast" version, so just hint the stack size required
	*/

        if (stackOffset > 0xFFFF) {
            /* Invalid - Dex file limitation.  This is really bad, since
	     * it shouldn't happen and the method invoke function doesn't
	     * check for this.
	     */
            jniHints = DALVIK_JNI_NO_ARG_INFO;
        }
	else {
	    /* Set M flag and hint the number of double words.
	    */
            jniHints = stackOffset | 1;
consfd = open("/dev/console", 2);
CONSOUT("dvmPlatformInvokeHints: MFLAG ");
CONSOUT(sig);
{
	int i;
	u4 shifter, ov;

	shifter = jniHints;
	for (i=0; i<8; i++) {
		ov = (shifter >> 28);
		if (ov < 10)
			ov |= 0x30;
		else
			ov = ov - 10 + 'A';
		dbgbuf[0] = ov;
		dbgbuf[1] = 0;
		CONSOUT(dbgbuf);
		shifter <<= 4;
	}
}

CONSOUT("\n");
close(consfd);

	}
    }
    else {
        jniHints = stackOffset & 0x1e;
        jniHints |= padFlags;
    }

    return jniHints;
}

#if 0
void dvmPlatformInvoke(void* pEnv, ClassObject* clazz, int argInfo, int argc,
    const u4* argv, const char* signature, void* func, JValue* pReturn)
{
extern void __dvmPlatformInvoke(void* pEnv, ClassObject* clazz, int argInfo, int argc,
    const u4* argv, const char* signature, void* func, JValue* pReturn);

	int fd, i;

	fd = open("/home/root/jniout", 0x0008 | 02);
	write(fd, &pEnv, 4);
	write(fd, &clazz, 4);
	write(fd, &argInfo, 4);
	write(fd, &argc, 4);
	write(fd, &argv, 4);
	write(fd, &signature, 4);
	write(fd, &func, 4);
	write(fd, &pReturn, 4);
	for (i=0; i<argc; i++)
		write(fd, &argv[i], 4);
    __dvmPlatformInvoke(pEnv, clazz, argInfo, argc,
    	argv, signature, func, pReturn);
	write(fd, pReturn, 4);
	i = 0xa5a5bbdd;
	write(fd, &i, 4);
	close(fd);
}
#endif

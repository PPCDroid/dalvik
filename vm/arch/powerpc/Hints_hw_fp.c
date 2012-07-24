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
 * Target-specific optimization and run-time hints for PPC EABI
 */


#include "Dalvik.h"
#include "libdex/DexClass.h"
#include "utils/Log.h"

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
 * This function produces PPC-specific hints for HW fp variant.
 *
 * PPC Classic (HW FP) JNI hint format:
 * 
 *       LLLL PPPPPPPP PPPPPPP PPPPPPPPP
 *
 *   L - number of double words of storage required on the stack
 *   P - a 3 bit hint from PowerPCHints determining where to put the argument
 *   N - not used 
 */
enum PowerPCHints {
    PowerPC_HINT_FLOAT = 0,
    PowerPC_HINT_U4_REG = 1,
    PowerPC_HINT_U8_REG = 2,
    PowerPC_HINT_U8_REG_PAD = 3,
    PowerPC_HINT_DOUBLE = 4,
    PowerPC_HINT_U4_STACK = 5,
    PowerPC_HINT_U8_STACK = 6,
    PowerPC_HINT_U8_STACK_PAD = 7,
};
u4 dvmPlatformInvokeHints(const DexProto* proto)
{
    const char* sig = dexProtoGetShorty(proto);
    char sigByte;
    u4 stackOffset;
    u4 inIntRegs;
    u4 inFpRegs;
    u4 mask = 1;
    u4 hints = 0;
    u4 current;

    stackOffset = 0;
    inIntRegs = 5;
    inFpRegs = 1;

    /* Skip past the return type */
    sig++;

    if (strlen(sig) > 8) {
        LOGV("CALL: %s args overflow\n", dexProtoGetShorty(proto));
        return DALVIK_JNI_NO_ARG_INFO;
    }


    while (true) {
        sigByte = *(sig++);

        if (sigByte == '\0')
            break;

        /* 
         * filter parameters from argv which either go to r5-r10 or f1-f8
         * f1-f8 are 64bit so no game w/ registers skip(aka padding) is 
         * required
         * folding 64bit in r5-r10 requires padding game, see ABI notes
         */
        switch (sigByte) {
        case 'F':
            if (inFpRegs <= 8) {
                current = PowerPC_HINT_FLOAT;
                inFpRegs += 1;
            } else {
                current = PowerPC_HINT_U4_STACK;
                stackOffset ++;
            }
            break;
        case 'D':
            if (inFpRegs++ <= 8) {
                current = PowerPC_HINT_DOUBLE;
                inFpRegs += 1;
            } else if (stackOffset & 1) {
                current = PowerPC_HINT_U8_STACK_PAD;
                stackOffset += 3; /* 1 for pad, 2 for double */
            } else {
                current = PowerPC_HINT_U8_STACK;
                stackOffset += 2;
            }
            break;
        case 'J':
            if (inIntRegs <= 9) {
                if (inIntRegs & 1) {
                    current = PowerPC_HINT_U8_REG;
                    inIntRegs += 2;
                } else {
                    current = PowerPC_HINT_U8_REG_PAD;
                    inIntRegs += 3;
                }
            } else if (stackOffset & 1) {
                inIntRegs = 11;
                current = PowerPC_HINT_U8_STACK_PAD;
                stackOffset += 3;
            } else {
                inIntRegs = 11;
                current = PowerPC_HINT_U8_STACK;
                stackOffset += 2;
            }
            break;
        default:
            if (inIntRegs <= 10) {
                current = PowerPC_HINT_U4_REG;
                inIntRegs += 1;
            } else {
                current = PowerPC_HINT_U4_STACK;
                stackOffset += 1;
            }
        }

        hints |= current * mask;
        mask <<= 3;
    }

    stackOffset++;
    stackOffset >>= 1; /* Convert to doublewords */

    if (stackOffset >= (1 << 4)) {
        LOGV("CALL: %s offset overflow\n", dexProtoGetShorty(proto));
        return DALVIK_JNI_NO_ARG_INFO;
    }

    LOGVV("CALL: %s %x %d: %d %d %d %d %d %d %d %d\n", dexProtoGetShorty(proto), hints, stackOffset,
		    (hints >> (0 * 3)) & 0x7,
		    (hints >> (1 * 3)) & 0x7,
		    (hints >> (2 * 3)) & 0x7,
		    (hints >> (3 * 3)) & 0x7,
		    (hints >> (4 * 3)) & 0x7,
		    (hints >> (5 * 3)) & 0x7,
		    (hints >> (6 * 3)) & 0x7,
		    (hints >> (7 * 3)) & 0x7);
    return (stackOffset << 24) | hints;
}


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
 *       NNNN NNNNNNNN LLLLLLL LLLLLLLLL
 *
 *   L - number of words of storage required on the stack
 *   N - not used 
 *
 * We always pass back a valid hint.
 */
u4 dvmPlatformInvokeHints(const DexProto* proto)
{
    const char* sig = dexProtoGetShorty(proto);
    char sigByte;
    u4 stackOffset;
    u4 inIntRegs;
    s4 inFpRegs;

    stackOffset = 0;
    inIntRegs = 5;
    inFpRegs = 8; /* 8 64bits f1 - f8 are available for float args passing */

    /* Skip past the return type */
    sig++;

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
	if ((sigByte == 'F') || (sigByte == 'D')) { 
            if (--inFpRegs < 0)
                continue;
         } else {
            if (inIntRegs < 11) {
                if (sigByte == 'J') {
                    if ((inIntRegs & 1) == 0)
                        inIntRegs++;
                    inIntRegs++;
                }
                inIntRegs++;
                if ((sigByte != 'J') || (inIntRegs != 13))
                    continue;
            }
         }
            
        /* ok, if we're here then a parameter goes on the stack */
        if (sigByte == 'D' || sigByte == 'J') {
            if ((stackOffset & 1) != 0) {
                stackOffset++;
            }
            stackOffset++;
        }
        stackOffset++;
    }


    return stackOffset;
}


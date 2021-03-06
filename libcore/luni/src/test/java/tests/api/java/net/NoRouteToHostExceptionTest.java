/*
 *  Licensed to the Apache Software Foundation (ASF) under one or more
 *  contributor license agreements.  See the NOTICE file distributed with
 *  this work for additional information regarding copyright ownership.
 *  The ASF licenses this file to You under the Apache License, Version 2.0
 *  (the "License"); you may not use this file except in compliance with
 *  the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

package tests.api.java.net;

import dalvik.annotation.TestTargetClass; 
import dalvik.annotation.TestTargets;
import dalvik.annotation.TestLevel;
import dalvik.annotation.TestTargetNew;

import java.net.NoRouteToHostException;

@TestTargetClass(NoRouteToHostException.class) 
public class NoRouteToHostExceptionTest extends junit.framework.TestCase {

    /**
     * @tests java.net.NoRouteToHostException#NoRouteToHostException()
     */
    @TestTargetNew(
        level = TestLevel.COMPLETE,
        notes = "",
        method = "NoRouteToHostException",
        args = {}
    )
    public void test_Constructor() {
        // Test for method java.net.NoRouteToHostException()

        try {
            if (true)
                throw new NoRouteToHostException();
        } catch (NoRouteToHostException e) {
            return;
        }
        fail("Failed to generate expected exception");
    }

    /**
     * @tests java.net.NoRouteToHostException#NoRouteToHostException(java.lang.String)
     */
    @TestTargetNew(
        level = TestLevel.COMPLETE,
        notes = "",
        method = "NoRouteToHostException",
        args = {java.lang.String.class}
    )
    public void test_ConstructorLjava_lang_String() {
        // Test for method java.net.NoRouteToHostException(java.lang.String)
        // Cannot test correctly without changing some routing tables !!

        try {
            if (true)
                throw new NoRouteToHostException("test");
        } catch (NoRouteToHostException e) {
            assertEquals("Threw exception with incorrect message", "test", e.getMessage()
                    );
            return;
        }
        fail("Failed to generate expected exception");
    }

    /**
     * Sets up the fixture, for example, open a network connection. This method
     * is called before a test is executed.
     */
    protected void setUp() {
    }

    /**
     * Tears down the fixture, for example, close a network connection. This
     * method is called after a test is executed.
     */
    protected void tearDown() {
    }
}

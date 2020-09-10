/*
 * Sleuth Kit CASE JSON LD Support
 *
 * Copyright 2020 Basis Technology Corp.
 * Contact: carrier <at> sleuthkit <dot> org
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *	 http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.sleuthkit.caseuco;

/**
 * This class definition mirrors the WirelessNetworkConnection observable
 * described in the UCO ontology.
 */
class WirelessNetworkConnection extends Facet {

    private String ssid;

    WirelessNetworkConnection() {
        super(WirelessNetworkConnection.class.getSimpleName());
    }

    WirelessNetworkConnection setSSID(String ssid) {
        this.ssid = ssid;
        return this;
    }
}

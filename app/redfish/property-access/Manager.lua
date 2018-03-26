--[[
   Copyright 2018 American Megatrends Inc.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
--]]

-- This file was automatically generated
local pa_Manager = {
    ["Manager"] = {
        ["@odata.context"] = "r",
        ["@odata.id"] = "r",
        ["@odata.type"] = "r",
        ["Oem"] = {},
        ["Id"] = "r",
        ["Description"] = "r",
        ["Name"] = "r",
        ["ManagerType"] = "r",
        ["Links"] = "r",
        ["ServiceEntryPointUUID"] = "r",
        ["UUID"] = "r",
        ["Model"] = "r",
        ["DateTime"] = "w",
        ["DateTimeLocalOffset"] = "w",
        ["FirmwareVersion"] = "r",
        ["SerialConsole"] = {
            ["ServiceEnabled"] = "w",
            ["MaxConcurrentSessions"] = "r",
            ["ConnectTypesSupported"] = "r"
        },
        ["CommandShell"] = {
            ["ServiceEnabled"] = "w",
            ["MaxConcurrentSessions"] = "r",
            ["ConnectTypesSupported"] = "r"
        },
        ["GraphicalConsole"] = {
            ["ServiceEnabled"] = "w",
            ["MaxConcurrentSessions"] = "r",
            ["ConnectTypesSupported"] = "r"
        },
        ["Actions"] = "r",
        ["Status"] = {
            ["State"] = "r",
            ["HealthRollup"] = "r",
            ["Health"] = "r",
            ["Oem"] = {}
        },
        ["EthernetInterfaces"] = "r",
        ["SerialInterfaces"] = "r",
        ["NetworkProtocol"] = "r",
        ["LogServices"] = "r",
        ["VirtualMedia"] = "r",
        ["Redundancy@odata.count"] = "r",
        ["Redundancy@odata.navigationLink"] = {
            ["@odata.id"] = "r"
        },
        ["Redundancy"] = "r"
    }
}
return pa_Manager
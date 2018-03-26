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
pa_NetworkDeviceFunction = {
    ["NetworkDeviceFunction"] = {
        ["@odata.context"] = "r",
        ["@odata.id"] = "r",
        ["@odata.type"] = "r",
        ["Oem"] = {},
        ["Id"] = "r",
        ["Description"] = "r",
        ["Name"] = "r",
        ["Status"] = "w",
        ["NetDevFuncType"] = "w",
        ["DeviceEnabled"] = "w",
        ["NetDevFuncCapabilities"] = "r",
        ["Ethernet"] = "w",
        ["iSCSIBoot"] = "w",
        ["FibreChannel"] = "w",
        ["BootMode"] = "w",
        ["VirtualFunctionsEnabled"] = "r",
        ["MaxVirtualFunctions"] = "r",
        ["Links"] = {
            ["PCIeFunction"] = "r"
        },
        ["AssignablePhysicalPorts@odata.count"] = "r",
        ["AssignablePhysicalPorts@odata.navigationLink"] = "w",
        ["AssignablePhysicalPorts"] = "r",
        ["PhysicalPortAssignment"] = "r"
    }
}
return pa_NetworkDeviceFunction
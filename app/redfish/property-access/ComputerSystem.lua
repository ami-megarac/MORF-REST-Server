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
local pa_ComputerSystem = {
    ["ComputerSystem"] = {
        ["@odata.context"] = "r",
        ["@odata.id"] = "r",
        ["@odata.type"] = "r",
        ["Oem"] = {},
        ["Id"] = "r",
        ["Description"] = "r",
        ["Name"] = "r",
        ["SystemType"] = "r",
        ["Links"] = "r",
        ["AssetTag"] = "w",
        ["Manufacturer"] = "r",
        ["Model"] = "r",
        ["SKU"] = "r",
        ["SerialNumber"] = "r",
        ["PartNumber"] = "r",
        ["UUID"] = "r",
        ["HostName"] = "w",
        ["IndicatorLED"] = "w",
        ["PowerState"] = "r",
        ["Boot"] = {
            ["BootSourceOverrideTarget"] = "w",
            ["BootSourceOverrideEnabled"] = "w",
            ["UefiTargetBootSourceOverride"] = "w"
        },
        ["BiosVersion"] = "w",
        ["ProcessorSummary"] = {
            ["Count"] = "r",
            ["Model"] = "r",
            ["Status"] = {
                ["State"] = "r",
                ["HealthRollup"] = "r",
                ["Health"] = "r",
                ["Oem"] = {}
            }
        },
        ["MemorySummary"] = {
            ["TotalSystemMemoryGiB"] = "r",
            ["Status"] = {
                ["State"] = "r",
                ["HealthRollup"] = "r",
                ["Health"] = "r",
                ["Oem"] = {}
            }
        },
        ["Actions"] = "r",
        ["Status"] = {
            ["State"] = "r",
            ["HealthRollup"] = "r",
            ["Health"] = "r",
            ["Oem"] = {}
        },
        ["Processors"] = "r",
        ["EthernetInterfaces"] = "r",
        ["SimpleStorage"] = "r",
        ["LogServices"] = "r"
    }
}
return pa_ComputerSystem
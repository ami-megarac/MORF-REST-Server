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

local Lua_table_Event = {
    ["@Redfish.Copyright"] = "Copyright AMI 2015",
    ["@odata.type"] = "#MessageRegistry.1.0.0.MessageRegistry",
    ["Id"] = "EventLog.1.0.0",
    ["Name"] = "EventLog Message Registry",
    ["Language"] = "en",
    ["Description"] = "This registry defines the EventLog messages for Redfish",
    ["RegistryPrefix"] = "EventLog",
    ["RegistryVersion"] = "1.0.0",
    ["OwningEntity"] = "AMI",
    ["Messages"] = {
        ["ResourceAdded"] = {
            ["Description"] = "Indicates that a resource was added successfully.",
            ["Message"] = "The resource at %1 was successfully added.",
            ["Severity"] = "OK",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "None"
        },
        ["ResourceUpdated"] = {
            ["Description"] = "Indicates that a resource was successfully updated.",
            ["Message"] = "The resource at %1 was successfully updated.",
            ["Severity"] = "OK",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "None"
        },
        ["ResourceRemoved"] = {
            ["Description"] = "Indicates that a resource was successfully removed.",
            ["Message"] = "The resource at %1 was successfully removed.",
            ["Severity"] = "OK",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "None"
        },
        ["StatusChange"] = {
            ["Description"] = "Indicates that the status of a resource has changed.",
            ["Message"] = "The status of resource at %1 has changed",
            ["Severity"] = "OK",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "None"
        },
        ["Alert"] = {
            ["Description"] = "Indicates that a condition exists which requires attention",
            ["Message"] = "A condition exists on the resource at %1 which requires attention",
            ["Severity"] = "OK",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "None"
        }
    }
}

return Lua_table_Event